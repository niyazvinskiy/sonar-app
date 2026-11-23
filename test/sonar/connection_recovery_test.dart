import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/sonar/connection_recovery.dart';

void main() {
  test('startup intent while an update is paused cannot allow a late native start', () {
    fakeAsync((time) {
      var stops = 0;
      final recovery = ConnectionRecovery(
        prepare: () async => true,
        connect: () async {},
        disconnect: () async {
          stops++;
        },
        saveWanted: (_) async {},
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.pause());
      unawaited(recovery.start());
      time.flushMicrotasks();
      recovery.update(RecoveryConnection.connecting);
      time.flushMicrotasks();
      expect(stops, 1);
      expect(recovery.wanted, isTrue);
      expect(recovery.paused, isTrue);
      recovery.dispose();
    });
  });

  test('startup respects manual stop this boot, restores next boot, and respects opt-out', () {
    expect(shouldStartSonarRecovery(autoConnect: true, wanted: null, previousBoot: null, currentBoot: 'boot1'), isTrue);
    expect(
      shouldStartSonarRecovery(autoConnect: true, wanted: false, previousBoot: 'boot1', currentBoot: 'boot1'),
      isFalse,
    );
    expect(
      shouldStartSonarRecovery(autoConnect: true, wanted: false, previousBoot: 'boot1', currentBoot: 'boot2'),
      isTrue,
    );
    expect(
      shouldStartSonarRecovery(autoConnect: false, wanted: true, previousBoot: 'boot1', currentBoot: 'boot2'),
      isFalse,
    );
    expect(
      shouldStartSonarRecovery(autoConnect: true, wanted: false, previousBoot: 'boot1', currentBoot: null),
      isFalse,
    );
  });

  test('update pause cancels pending work without clearing persisted intent', () {
    fakeAsync((time) {
      final key = Completer<bool>();
      final saved = <bool>[];
      var connections = 0;
      final recovery = ConnectionRecovery(
        prepare: () => key.future,
        connect: () async {
          connections++;
        },
        disconnect: () async {},
        saveWanted: (value) async {
          saved.add(value);
        },
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.start());
      time.flushMicrotasks();
      unawaited(recovery.pause());
      time.flushMicrotasks();
      key.complete(true);
      time.flushMicrotasks();
      time.elapse(const Duration(minutes: 5));
      expect(connections, 0);
      expect(saved, [true]);
      expect(recovery.wanted, isTrue);
      recovery.resume();
      time.flushMicrotasks();
      expect(connections, 1);
      recovery.dispose();
    });
  });

  test('offline preparation retries with bounded backoff until stopped', () {
    fakeAsync((time) {
      var preparations = 0;
      final saved = <bool>[];
      final recovery = ConnectionRecovery(
        prepare: () async {
          preparations++;
          return false;
        },
        connect: () async => fail('must prepare before connecting'),
        disconnect: () async {},
        saveWanted: (value) async {
          saved.add(value);
        },
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.start());
      time.flushMicrotasks();
      expect(preparations, 1);
      for (final (seconds, count) in [(2, 1), (4, 2), (8, 3), (16, 4), (30, 5), (30, 6)]) {
        time.elapse(Duration(seconds: seconds - 1));
        expect(preparations, count);
        time.elapse(const Duration(seconds: 1));
        expect(preparations, count + 1);
      }
      expect(preparations, 7);
      unawaited(recovery.stop());
      time.flushMicrotasks();
      time.elapse(const Duration(hours: 1));
      expect(preparations, 7);
      expect(saved, [true, false]);
      expect(recovery.retryScheduled, isFalse);
      recovery.dispose();
    });
  });

  test('manual stop cancels a key request still in progress', () {
    fakeAsync((time) {
      final key = Completer<bool>();
      var connections = 0;
      final recovery = ConnectionRecovery(
        prepare: () => key.future,
        connect: () async {
          connections++;
        },
        disconnect: () async {},
        saveWanted: (_) async {},
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.start());
      time.flushMicrotasks();
      unawaited(recovery.stop());
      time.flushMicrotasks();
      key.complete(true);
      time.flushMicrotasks();
      time.elapse(const Duration(minutes: 5));
      expect(connections, 0);
      expect(recovery.wanted, isFalse);
      recovery.dispose();
    });
  });

  test('stop then restart waits for old preparation before starting a new attempt', () {
    fakeAsync((time) {
      final oldRequest = Completer<bool>();
      var preparations = 0;
      var connections = 0;
      final recovery = ConnectionRecovery(
        prepare: () {
          preparations++;
          return preparations == 1 ? oldRequest.future : Future.value(true);
        },
        connect: () async {
          connections++;
        },
        disconnect: () async {},
        saveWanted: (_) async {},
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.start());
      time.flushMicrotasks();
      unawaited(recovery.stop());
      unawaited(recovery.start());
      time.flushMicrotasks();
      expect(preparations, 1);
      oldRequest.complete(true);
      time.flushMicrotasks();
      time.elapse(Duration.zero);
      time.flushMicrotasks();
      expect(preparations, 2);
      expect(connections, 1);
      recovery.dispose();
    });
  });

  test('only one attempt runs while preparation or core connection is pending', () {
    fakeAsync((time) {
      final key = Completer<bool>();
      var preparations = 0;
      var connections = 0;
      late ConnectionRecovery recovery;
      recovery = ConnectionRecovery(
        prepare: () {
          preparations++;
          return key.future;
        },
        connect: () async {
          connections++;
          recovery.update(RecoveryConnection.connecting);
        },
        disconnect: () async {},
        saveWanted: (_) async {},
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.start());
      unawaited(recovery.start());
      time.flushMicrotasks();
      time.elapse(const Duration(minutes: 10));
      expect(preparations, 1);
      key.complete(true);
      time.flushMicrotasks();
      time.elapse(const Duration(minutes: 10));
      expect(connections, 1);
      recovery.update(RecoveryConnection.disconnected);
      time.elapse(const Duration(seconds: 2));
      expect(connections, 2);
      recovery.dispose();
    });
  });

  test('startup waits for core readiness and reconnects after a later drop', () {
    fakeAsync((time) {
      var connections = 0;
      late ConnectionRecovery recovery;
      recovery = ConnectionRecovery(
        prepare: () async => true,
        connect: () async {
          connections++;
          recovery.update(RecoveryConnection.connecting);
        },
        disconnect: () async {},
        saveWanted: (_) async {},
        onChanged: () {},
      );
      unawaited(recovery.start());
      time.flushMicrotasks();
      expect(connections, 0);
      recovery.update(RecoveryConnection.disconnected);
      time.flushMicrotasks();
      expect(connections, 1);
      recovery.update(RecoveryConnection.connected);
      time.elapse(const Duration(hours: 1));
      expect(connections, 1);
      recovery.update(RecoveryConnection.disconnected);
      time.elapse(const Duration(seconds: 2));
      expect(connections, 2);
      recovery.dispose();
    });
  });

  test('a late connection after stop is disconnected without restarting', () {
    fakeAsync((time) {
      var stops = 0;
      final recovery = ConnectionRecovery(
        prepare: () async => true,
        connect: () async {},
        disconnect: () async {
          stops++;
        },
        saveWanted: (_) async {},
        onChanged: () {},
      );
      recovery.update(RecoveryConnection.disconnected);
      unawaited(recovery.start());
      time.flushMicrotasks();
      unawaited(recovery.stop());
      time.flushMicrotasks();
      recovery.update(RecoveryConnection.connected);
      time.flushMicrotasks();
      expect(stops, greaterThanOrEqualTo(1));
      expect(recovery.wanted, isFalse);
      recovery.dispose();
    });
  });
}
