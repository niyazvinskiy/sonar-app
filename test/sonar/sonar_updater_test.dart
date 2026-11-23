import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Connection extends ConnectionNotifier {
  _Connection(this.connection);
  final ConnectionStatus connection;
  @override
  Stream<ConnectionStatus> build() => Stream.value(connection);
}

class _Updater extends SonarUpdater {
  void ready(File file) => state = SonarUpdateState(SonarUpdatePhase.ready, version: '2.0.0', file: file);
}

void main() {
  testWidgets('serializes checks before the version and release requests finish', (tester) async {
    var requests = 0;
    final blocked = Completer<Map<String, dynamic>>();
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'getAll');
      requests++;
      return blocked.future;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final container = ProviderContainer(
      overrides: [connectionNotifierProvider.overrideWith(() => _Connection(const Disconnected()))],
    );
    addTearDown(container.dispose);
    final updater = container.read(sonarUpdaterProvider.notifier);
    final first = updater.check();
    final second = updater.check();
    await tester.pump();
    expect(requests, 1, reason: 'a second click must not start a second release/download operation');
    blocked.completeError(PlatformException(code: 'test-stopped-before-network'));
    await Future.wait([first, second]);
    expect(container.read(sonarUpdaterProvider).phase, SonarUpdatePhase.failed);
    container.dispose();
  });

  for (final connection in [const Connecting(), const Disconnecting()]) {
    testWidgets('defers manual installation while VPN is ${connection.runtimeType}', (tester) async {
      final updater = _Updater();
      final container = ProviderContainer(
        overrides: [
          connectionNotifierProvider.overrideWith(() => _Connection(connection)),
          sonarUpdaterProvider.overrideWith(() => updater),
        ],
      );
      addTearDown(container.dispose);
      await container.read(connectionNotifierProvider.future);
      container.read(sonarUpdaterProvider);
      updater.ready(File('not-used-because-the-connection-is-busy.exe'));
      await updater.install();
      expect(container.read(sonarUpdaterProvider).phase, SonarUpdatePhase.ready);
      container.dispose();
    }, skip: !Platform.isWindows);
  }
}
