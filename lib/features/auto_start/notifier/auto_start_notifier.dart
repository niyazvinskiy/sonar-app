import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/sonar/sonar_windows.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_start_notifier.g.dart';

@Riverpod(keepAlive: true)
class AutoStartNotifier extends _$AutoStartNotifier with InfraLogger {
  Timer? _timer;

  @override
  Future<bool> build() async {
    if (!PlatformUtils.isDesktop) return false;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    launchAtStartup.setup(
      appName: appInfo.name,
      appPath: Platform.resolvedExecutable,
      packageName: "Hiddify.HiddifyNext",
    );
    final isEnabled = Platform.isWindows ? await SonarWindows.isStartupEnabled() : await launchAtStartup.isEnabled();
    loggy.info("auto start is [${isEnabled ? "Enabled" : "Disabled"}]");
    _startTimer();
    ref.onDispose(() => _timer?.cancel());
    return isEnabled;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) => updateStatus());
  }

  Future<bool> updateStatus() async {
    loggy.debug("update auto start status");
    final isEnabled = Platform.isWindows ? await SonarWindows.isStartupEnabled() : await launchAtStartup.isEnabled();
    state = AsyncValue.data(isEnabled);
    return isEnabled;
  }

  Future<void> enable() async {
    loggy.debug("enabling auto start");
    if (Platform.isWindows) {
      await SonarWindows.setStartupEnabled(true);
      // Remove the legacy unelevated registry launch to avoid two processes at login.
      await launchAtStartup.disable();
    } else {
      await launchAtStartup.enable();
    }
    state = const AsyncValue.data(true);
  }

  Future<void> disable() async {
    loggy.debug("disabling auto start");
    if (Platform.isWindows) await SonarWindows.setStartupEnabled(false);
    await launchAtStartup.disable();
    state = const AsyncValue.data(false);
  }
}
