import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/sonar/connection_recovery.dart';
import 'package:hiddify/sonar/sonar_channel_guard.dart';
import 'package:hiddify/sonar/sonar_key.dart';
import 'package:hiddify/sonar/sonar_windows.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SonarRecoveryState {
  const SonarRecoveryState({
    this.wanted = false,
    this.autoConnect = true,
    this.retryScheduled = false,
    this.failures = 0,
    this.paused = false,
  });
  final bool wanted;
  final bool autoConnect;
  final bool retryScheduled;
  final int failures;
  final bool paused;
}

class SonarConnectionRecovery extends Notifier<SonarRecoveryState> {
  static const wantedPreference = 'sonar_connection_wanted';
  static const autoConnectPreference = 'sonar_auto_connect';
  late ConnectionRecovery _recovery;
  late Future<void> _ready;
  bool _autoConnect = Platform.isWindows;
  bool _disposed = false;
  int _commands = 0;

  @override
  SonarRecoveryState build() {
    _recovery = ConnectionRecovery(
      prepare: () async {
        if (!await ref.read(sonarKeyProvider.notifier).ensure() || _disposed) return false;
        // A newly issued profile arrives through the database stream. If it is
        // not active yet, the normal backoff waits for it without toggling core.
        return await ref.read(activeProfileProvider.future) != null;
      },
      connect: () async {
        if (!await ref.read(connectionNotifierProvider.notifier).connectAutomatically()) {
          throw StateError('The native connection operation is still busy');
        }
      },
      disconnect: () => ref.read(connectionNotifierProvider.notifier).abortConnection(),
      saveWanted: (wanted) async {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setBool(wantedPreference, wanted);
      },
      onChanged: _emit,
    );
    ref.onDispose(() {
      _disposed = true;
      _recovery.dispose();
    });
    ref.listen(connectionNotifierProvider, (_, next) => _recovery.update(_connection(next)));
    ref.listen(sonarConnectOnHomeProvider, (_, next) {
      if (!next) return;
      ref.read(sonarConnectOnHomeProvider.notifier).state = false;
      unawaited(start());
    });
    // The guard also stays alive when the user opens settings or hides the UI.
    ref.listen(sonarChannelGuardProvider, (_, next) {});
    _ready = Future.microtask(_initialize);
    return SonarRecoveryState(autoConnect: _autoConnect);
  }

  Future<void> _initialize() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (_disposed) return;
    final relaunch = prefs.getBool(SonarWindows.connectAfterRestartKey) ?? false;
    if (relaunch) await prefs.remove(SonarWindows.connectAfterRestartKey);
    if (_disposed) return;
    _autoConnect = prefs.getBool(autoConnectPreference) ?? Platform.isWindows;
    final previousBoot = prefs.getString('sonar_windows_boot');
    final currentBoot = await ref.read(sonarWindowsBootProvider.future);
    if (_disposed) return;
    final restore = shouldStartSonarRecovery(
      autoConnect: _autoConnect,
      wanted: prefs.getBool(wantedPreference),
      previousBoot: previousBoot,
      currentBoot: currentBoot,
    );
    if (currentBoot != null) await prefs.setString('sonar_windows_boot', currentBoot);
    if (_disposed) return;
    _recovery.update(_connection(ref.read(connectionNotifierProvider)));
    final firstStart = ref.read(sonarConnectOnHomeProvider);
    if (firstStart) ref.read(sonarConnectOnHomeProvider.notifier).state = false;
    final resumeRelaunch = relaunch && prefs.getBool(wantedPreference) != false;
    if (_commands == 0 && (firstStart || restore || resumeRelaunch)) {
      await _recovery.start();
    }
    _emit();
  }

  static RecoveryConnection _connection(AsyncValue<ConnectionStatus> status) => switch (status) {
    AsyncError() => RecoveryConnection.disconnected,
    AsyncLoading() => RecoveryConnection.unavailable,
    AsyncData(value: Connected()) => RecoveryConnection.connected,
    AsyncData(value: Connecting()) => RecoveryConnection.connecting,
    AsyncData(value: Disconnecting()) => RecoveryConnection.disconnecting,
    _ => RecoveryConnection.disconnected,
  };

  void _emit() {
    if (_disposed) return;
    state = SonarRecoveryState(
      wanted: _recovery.wanted,
      autoConnect: _autoConnect,
      retryScheduled: _recovery.retryScheduled,
      failures: _recovery.failures,
      paused: _recovery.paused,
    );
  }

  Future<void> start() async {
    _commands++;
    if (!_disposed) await _recovery.start();
  }

  Future<void> stop() async {
    _commands++;
    if (!_disposed) await _recovery.stop();
  }

  Future<void> setAutoConnect(bool value) async {
    final command = ++_commands;
    await _ready;
    if (_disposed) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(autoConnectPreference, value);
    if (_disposed) return;
    _autoConnect = value;
    _emit();
    if (value && command == _commands) await _recovery.start();
  }

  Future<void> pauseForUpdate() async {
    if (!_disposed) await _recovery.pause();
    await _ready;
  }

  void resumeAfterUpdateFailure() {
    if (!_disposed) _recovery.resume();
  }
}

final sonarConnectionRecoveryProvider = NotifierProvider<SonarConnectionRecovery, SonarRecoveryState>(
  SonarConnectionRecovery.new,
);

final sonarWindowsBootProvider = FutureProvider<String?>((ref) => SonarWindows.bootIdentity());
