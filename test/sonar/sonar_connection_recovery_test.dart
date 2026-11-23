import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/sonar/sonar_channel_guard.dart';
import 'package:hiddify/sonar/sonar_connection_recovery.dart';
import 'package:hiddify/sonar/sonar_key.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile extends ActiveProfile {
  @override
  Stream<ProfileEntity?> build() =>
      Stream.value(ProfileEntity.local(id: 'sonar', active: true, name: 'Sonar', lastUpdate: DateTime(2026)));
}

class _Key extends SonarKeyNotifier {
  _Key(this.result);
  final Future<bool> result;
  int requests = 0;
  @override
  Future<bool> ensure() {
    requests++;
    return result;
  }
}

class _Core extends ConnectionNotifier {
  int starts = 0;
  int stops = 0;
  @override
  Stream<ConnectionStatus> build() => Stream.value(const Disconnected());
  @override
  Future<bool> connectAutomatically() async {
    starts++;
    state = const AsyncData(Connecting());
    return true;
  }

  @override
  Future<void> abortConnection() async {
    stops++;
    state = const AsyncData(Disconnected());
  }
}

class _Guard extends SonarChannelGuard {
  @override
  SonarChannelState build() => const SonarChannelState();
}

ProviderContainer _open(SharedPreferences prefs, _Core core, _Key key, String boot) => ProviderContainer(
  overrides: [
    sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
    activeProfileProvider.overrideWith(_Profile.new),
    connectionNotifierProvider.overrideWith(() => core),
    sonarKeyProvider.overrideWith(() => key),
    sonarChannelGuardProvider.overrideWith(_Guard.new),
    sonarWindowsBootProvider.overrideWith((ref) => Future.value(boot)),
  ],
);

void main() {
  for (final wanted in [true, false]) {
    testWidgets('explicit update relaunch respects wanted=$wanted with startup disabled', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sonar_auto_connect': false,
        'sonar_connection_wanted': wanted,
        'sonar_connect_after_restart': true,
        'sonar_windows_boot': 'same',
      });
      final prefs = await SharedPreferences.getInstance();
      final core = _Core();
      final container = _open(prefs, core, _Key(Future.value(true)), 'same');
      container.read(sonarConnectionRecoveryProvider);
      await tester.pump();
      expect(core.starts, wanted ? 1 : 0);
      expect(prefs.getBool('sonar_connect_after_restart'), isNot(isTrue));
      container.dispose();
      await tester.pump();
    });
  }
  testWidgets('new Windows boot starts with a key and manual stop survives reopening this boot', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sonar_auto_connect': true,
      'sonar_connection_wanted': false,
      'sonar_windows_boot': 'old',
    });
    final prefs = await SharedPreferences.getInstance();
    final core = _Core();
    final key = _Key(Future.value(true));
    final container = _open(prefs, core, key, 'new');
    container.read(sonarConnectionRecoveryProvider);
    await tester.pump();
    expect(key.requests, 1);
    expect(core.starts, 1);
    await container.read(sonarConnectionRecoveryProvider.notifier).stop();
    await tester.pump();
    expect(core.stops, 1);
    expect(prefs.getBool('sonar_connection_wanted'), isFalse);
    container.dispose();
    final reopenedCore = _Core();
    final reopened = _open(prefs, reopenedCore, _Key(Future.value(true)), 'new');
    reopened.read(sonarConnectionRecoveryProvider);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(reopenedCore.starts, 0);
    expect(reopened.read(sonarConnectionRecoveryProvider).wanted, isFalse);
    reopened.dispose();
    await tester.pump();
  });

  testWidgets('manual stop while startup issues a key cannot connect when key arrives', (tester) async {
    SharedPreferences.setMockInitialValues({'sonar_auto_connect': true});
    final prefs = await SharedPreferences.getInstance();
    final core = _Core();
    final pending = Completer<bool>();
    final key = _Key(pending.future);
    final container = _open(prefs, core, key, 'new');
    container.read(sonarConnectionRecoveryProvider);
    await tester.pump();
    expect(key.requests, 1);
    await container.read(sonarConnectionRecoveryProvider.notifier).stop();
    pending.complete(true);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(core.starts, 0);
    expect(prefs.getBool('sonar_connection_wanted'), isFalse);
    container.dispose();
    await tester.pump();
  });
}
