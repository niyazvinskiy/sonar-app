import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
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
  static const _connectAfterRestart = 'sonar_connect_after_restart';
  static const _task = 'Sonar VPN';

  /// Запущен ли Sonar с правами администратора: `net session` без них отказывает.
  static Future<bool> isAdmin() async {
    if (!Platform.isWindows) return true;
    try {
      return (await Process.run('net', ['session'])).exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Есть ли задача, которая запускает Sonar с правами без вопросов.
  static Future<bool> hasTask() async {
    if (!Platform.isWindows) return false;
    try {
      return (await Process.run('schtasks', ['/Query', '/TN', _task])).exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Включает или выключает режим VPN. Если для него нужны права, перезапускает Sonar
  /// с ними и возвращает true: тогда этот процесс закроется.
  static Future<bool> setVpn(WidgetRef ref, bool on) async {
    await ref.read(ConfigOptions.serviceMode.notifier).update(on ? ServiceMode.tun : ServiceMode.systemProxy);
    final connection = ref.read(connectionNotifierProvider.notifier);
    final connected = ref.read(connectionNotifierProvider).valueOrNull is Connected;
    if (on && !await isAdmin()) {
      await restartAsAdmin(ref);
      return true;
    }
    // Права есть: переподключаемся, чтобы новый режим вступил в силу
    if (connected) {
      await connection.toggleConnection();
      await Future<void>.delayed(const Duration(seconds: 1));
      await connection.toggleConnection();
    }
    return false;
  }

  /// Перезапуск с правами администратора. Задача уже есть: без вопросов. Нет: один
  /// раз окно UAC, оно создаёт задачу и запускает Sonar. Откажут: Sonar откроется как был.
  static Future<void> restartAsAdmin(WidgetRef ref, {bool connectAfter = true}) async {
    if (connectAfter) await markConnectAfterRestart(ref.read(sharedPreferencesProvider.future));
    // Сначала отключаемся: иначе системный прокси останется указывать на закрытый Sonar
    if (ref.read(connectionNotifierProvider).valueOrNull is Connected) {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    final exe = Platform.resolvedExecutable.replaceAll("'", "''");
    final String command;
    if (await hasTask()) {
      // пауза, чтобы этот процесс успел закрыться и отпустить «один экземпляр»
      command = "Start-Sleep -Milliseconds 900; schtasks /Run /TN '$_task' | Out-Null";
    } else {
      final register = taskScript(exe);
      // -EncodedCommand: строка в UTF-16LE и base64, без второго слоя кавычек
      final encoded = base64Encode(Uint16List.fromList(register.codeUnits).buffer.asUint8List());
      command =
          "Start-Sleep -Milliseconds 900; try { Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait "
          "-ArgumentList '-NoProfile','-EncodedCommand','$encoded' -ErrorAction Stop } "
          "catch { Start-Process -FilePath '$exe' }";
    }
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-Command',
      command,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// Скрипт PowerShell, который создаёт задачу «Sonar VPN» и сразу запускает её.
  /// [exe] уже с удвоенными одинарными кавычками. Задача без расписания, только для
  /// запуска по требованию; срок работы без предела: по умолчанию планировщик
  /// остановил бы Sonar через 72 часа.
  static String taskScript(String exe) => [
    "\$a = New-ScheduledTaskAction -Execute '$exe'",
    "\$p = New-ScheduledTaskPrincipal -UserId (\$env:USERDOMAIN + '\\' + \$env:USERNAME) -LogonType Interactive -RunLevel Highest",
    '\$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -MultipleInstances IgnoreNew',
    "Register-ScheduledTask -TaskName '$_task' -Action \$a -Principal \$p -Settings \$s -Force | Out-Null",
    "Start-ScheduledTask -TaskName '$_task'",
  ].join('; ');

  /// Новый процесс Sonar (после обновления или перезапуска с правами) подключится сам.
  static Future<void> markConnectAfterRestart(Future<SharedPreferences> prefs) async =>
      (await prefs).setBool(_connectAfterRestart, true);

  /// После перезапуска с правами Sonar подключается сам: флаг читается один раз.
  static Future<bool> takeConnectAfterRestart(WidgetRef ref) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final value = prefs.getBool(_connectAfterRestart) ?? false;
    if (value) await prefs.remove(_connectAfterRestart);
    return value;
  }
}
