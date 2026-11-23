import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/sonar/sonar_connection_recovery.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режим VPN на Windows: весь трафик компьютера идёт через Sonar, в том числе игры,
/// голос в Discord и программы в терминале вроде Claude Code. Системный прокси, режим
/// по умолчанию, их не захватывает: через него идут только браузеры и программы,
/// которые сами спрашивают прокси.
///
/// Для VPN Windows требует права администратора. Спрашиваем их один раз: при
/// включении режима Sonar создаёт задачу планировщика «Sonar VPN» с наивысшими
/// правами и дальше запускается через неё без окна UAC.
abstract class SonarWindows {
  static const connectAfterRestartKey = 'sonar_connect_after_restart';
  static const _task = 'Sonar VPN-';
  static Future<String>? _sid;

  static Future<String> taskName() async {
    _sid ??= () async {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '[Security.Principal.WindowsIdentity]::GetCurrent().User.Value',
      ]).timeout(const Duration(seconds: 5));
      final value = '${result.stdout}'.trim();
      if (result.exitCode != 0 || !RegExp(r'^S-1-\d+(?:-\d+)+$').hasMatch(value)) {
        throw StateError('Windows не определила учётную запись для автозапуска');
      }
      return value;
    }();
    return '$_task${await _sid}';
  }

  static const _setupRequested = 'sonar_windows_automation_v2';
  static const _setupComplete = 'sonar_windows_automation_ready_v2';

  static bool get protectedInstallation {
    final root = Platform.environment['ProgramFiles'];
    if (root == null) return false;
    return Platform.resolvedExecutable.toLowerCase().startsWith('${root.toLowerCase()}\\');
  }

  /// A reboot starts a new automatic-connection session; an updater restart does not.
  static Future<String?> bootIdentity() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks',
      ]).timeout(const Duration(seconds: 5));
      final value = '${result.stdout}'.trim();
      return result.exitCode == 0 && RegExp(r'^\d+$').hasMatch(value) ? value : null;
    } catch (_) {
      return null;
    }
  }

  /// Check token membership; unlike `net session`, this works with Server service disabled.
  static Future<bool> isAdmin() async {
    if (!Platform.isWindows) return true;
    try {
      return (await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 }; exit 1',
          ])).exitCode ==
          0;
    } catch (_) {
      return false;
    }
  }

  /// Migrate existing installations once. Declining UAC never causes a restart loop.
  static Future<void> ensureAutomaticStartup(WidgetRef ref) async {
    if (!Platform.isWindows) return;
    if (!protectedInstallation) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (prefs.getBool(_setupComplete) ?? false) return;
    final admin = await isAdmin();
    if (!admin && (prefs.getBool(_setupRequested) ?? false)) return;
    await prefs.setBool(_setupRequested, true);
    await ref.read(ConfigOptions.serviceMode.notifier).update(ServiceMode.tun);
    if (!admin) return restartAsAdmin(ref);
    await setStartupEnabled(true);
    await prefs.setBool(_setupComplete, true);
  }

  static Future<bool> isStartupEnabled() async {
    if (!Platform.isWindows) return false;
    final task = await taskName();
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "\$t = Get-ScheduledTask -TaskName '$task' -ErrorAction SilentlyContinue; if (\$t -and \$t.Settings.Enabled -and (\$t.Triggers | Where-Object { \$_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' -and \$_.Enabled })) { exit 0 }; exit 1",
    ]);
    return result.exitCode == 0;
  }

  static Future<void> setStartupEnabled(bool enabled) async {
    if (!Platform.isWindows) return;
    if (!protectedInstallation) throw StateError('Установите Sonar в Program Files через установщик');
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      taskScript(Platform.resolvedExecutable.replaceAll("'", "''"), startup: enabled, run: false),
    ]);
    if (result.exitCode != 0) throw StateError('Windows не сохранила автозапуск: ${result.stderr}');
  }

  /// Есть ли задача, которая запускает Sonar с правами без вопросов.
  static Future<bool> hasTask() async {
    if (!Platform.isWindows) return false;
    try {
      final task = await taskName();
      return (await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "\$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value; \$t = Get-ScheduledTask -TaskName '$task' -ErrorAction SilentlyContinue; if (\$t -and \$t.Principal.UserId -eq \$sid) { exit 0 }; exit 1",
          ])).exitCode ==
          0;
    } catch (_) {
      return false;
    }
  }

  /// Включает или выключает режим VPN. Если для него нужны права, перезапускает Sonar
  /// с ними и возвращает true: тогда этот процесс закроется.
  static Future<bool> setVpn(WidgetRef ref, bool on) async {
    await ref.read(ConfigOptions.serviceMode.notifier).update(on ? ServiceMode.tun : ServiceMode.systemProxy);
    final connected = ref.read(connectionNotifierProvider).valueOrNull is Connected;
    if (on && !await isAdmin()) {
      await restartAsAdmin(ref);
      return true;
    }
    // Права есть: переподключаемся, чтобы новый режим вступил в силу
    if (connected) {
      final recovery = ref.read(sonarConnectionRecoveryProvider.notifier);
      await recovery.pauseForUpdate();
      recovery.resumeAfterUpdateFailure();
    }
    return false;
  }

  /// Перезапуск с правами администратора. Задача уже есть: без вопросов. Нет: один
  /// раз окно UAC, оно создаёт задачу и запускает Sonar. Откажут: Sonar откроется как был.
  static Future<void> restartAsAdmin(WidgetRef ref, {bool connectAfter = true}) async {
    if (Platform.isWindows && !protectedInstallation) {
      throw StateError('Для автоматического VPN установите Sonar через установщик в Program Files');
    }
    if (connectAfter) await markConnectAfterRestart(ref.read(sharedPreferencesProvider.future));
    final recovery = ref.read(sonarConnectionRecoveryProvider.notifier);
    await recovery.pauseForUpdate();
    // pauseForUpdate stops the tunnel without toggling it back on or losing intent.
    final exe = Platform.resolvedExecutable.replaceAll("'", "''");
    final String command;
    if (await hasTask()) {
      // пауза, чтобы этот процесс успел закрыться и отпустить «один экземпляр»
      command = "Start-Sleep -Milliseconds 900; schtasks /Run /TN '${await taskName()}' | Out-Null";
    } else {
      final register = taskScript(exe);
      // -EncodedCommand: строка в UTF-16LE и base64, без второго слоя кавычек
      final encoded = base64Encode(Uint16List.fromList(register.codeUnits).buffer.asUint8List());
      command =
          "Start-Sleep -Milliseconds 900; try { Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait "
          "-ArgumentList '-NoProfile','-EncodedCommand','$encoded' -ErrorAction Stop } "
          "catch { Start-Process -FilePath '$exe' }";
    }
    try {
      await Process.start('powershell.exe', [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-Command',
        command,
      ], mode: ProcessStartMode.detached);
    } catch (_) {
      recovery.resumeAfterUpdateFailure();
      rethrow;
    }
    exit(0);
  }

  /// Скрипт PowerShell, который создаёт задачу «Sonar VPN» и сразу запускает её.
  /// [exe] is PowerShell-escaped. The per-user logon trigger is optional; the
  /// elevated manual launcher remains available when startup is switched off.
  static String taskScript(String exe, {bool startup = true, bool run = true}) => [
    "\$ErrorActionPreference = 'Stop'",
    '\$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value',
    "\$task = '$_task' + \$sid",
    "\$a = New-ScheduledTaskAction -Execute '$exe' -WorkingDirectory '${exe.substring(0, exe.lastIndexOf('\\'))}'",
    '\$p = New-ScheduledTaskPrincipal -UserId \$sid -LogonType Interactive -RunLevel Highest',
    '\$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -MultipleInstances IgnoreNew -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)',
    if (startup) '\$t = New-ScheduledTaskTrigger -AtLogOn -User \$sid',
    "Register-ScheduledTask -TaskName \$task -Action \$a -Principal \$p -Settings \$s ${startup ? '-Trigger \$t ' : ''}-Force | Out-Null",
    if (run) 'Start-ScheduledTask -TaskName \$task',
  ].join('; ');

  /// Новый процесс Sonar (после обновления или перезапуска с правами) подключится сам.
  static Future<void> markConnectAfterRestart(Future<SharedPreferences> prefs) async =>
      (await prefs).setBool(connectAfterRestartKey, true);

  /// После перезапуска с правами Sonar подключается сам: флаг читается один раз.
  static Future<bool> takeConnectAfterRestart(WidgetRef ref) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final value = prefs.getBool(connectAfterRestartKey) ?? false;
    if (value) await prefs.remove(connectAfterRestartKey);
    return value;
  }
}
