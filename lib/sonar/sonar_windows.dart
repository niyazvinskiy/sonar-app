import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

/// Сколько человек не трогал мышь и клавиатуру. Вне Windows ноль: там обновление
/// при включённом VPN ждёт до 12 часов.
Duration sonarIdle() {
  if (!Platform.isWindows) return Duration.zero;
  final info = calloc<LASTINPUTINFO>()..ref.cbSize = sizeOf<LASTINPUTINFO>();
  try {
    if (GetLastInputInfo(info) == 0) return Duration.zero;
    return Duration(milliseconds: (GetTickCount() - info.ref.dwTime) & 0xFFFFFFFF);
  } finally {
    calloc.free(info);
  }
}

/// Режим VPN на Windows: весь трафик компьютера идёт через Sonar, в том числе игры
/// и голос в Discord. Системный прокси, режим по умолчанию, их не захватывает:
/// через него идут только браузеры и программы, которые сами спрашивают прокси.
/// Для VPN Windows требует права администратора, поэтому Sonar перезапускается с ними.
abstract class SonarWindows {
  static const _connectAfterRestart = 'sonar_connect_after_restart';

  /// Запущен ли Sonar с правами администратора: `net session` без них отказывает.
  static Future<bool> isAdmin() async {
    if (!Platform.isWindows) return true;
    try {
      return (await Process.run('net', ['session'])).exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Включает или выключает режим VPN. Если для него нужны права, перезапускает Sonar
  /// с запросом прав и возвращает true: тогда этот процесс закроется.
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

  /// Перезапуск с запросом прав администратора. Откажут в правах: Sonar откроется как был.
  static Future<void> restartAsAdmin(WidgetRef ref, {bool connectAfter = true}) async {
    if (connectAfter) await markConnectAfterRestart(ref.read(sharedPreferencesProvider.future));
    // Сначала отключаемся: иначе системный прокси останется указывать на закрытый Sonar
    if (ref.read(connectionNotifierProvider).valueOrNull is Connected) {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    final exe = Platform.resolvedExecutable.replaceAll("'", "''");
    // пауза, чтобы этот процесс успел закрыться и отпустить «один экземпляр»
    final command =
        "Start-Sleep -Milliseconds 900; try { Start-Process -FilePath '$exe' -Verb RunAs -ErrorAction Stop } "
        "catch { Start-Process -FilePath '$exe' }";
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-Command',
      command,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

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
