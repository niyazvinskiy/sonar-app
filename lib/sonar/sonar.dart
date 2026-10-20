import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Всё, что отличает Sonar от Hiddify: адреса, имена и выдача личного ключа.
abstract class Sonar {
  /// Адрес выдачи ключей. Подставляется при сборке из секрета SONAR_API,
  /// в исходниках его нет.
  static const api = String.fromEnvironment('SONAR_API');
  static const repo = 'niyazvinskiy/sonar-app';
  static const site = 'https://sonar-vpn.vercel.app';

  /// Тот же сайт на GitHub Pages: открывается и там, где vercel.app закрыт
  static const mirror = 'https://niyazvinskiy.github.io/sonar-app/';
  static const profileName = 'Sonar';

  /// Где стоит сервер: показывается на главном экране в сети
  static const serverCity = 'Хельсинки';

  /// Цвета сайта и прототипа: ночная вода, туман, бумага.
  static const night0 = 0xFF070B16;
  static const night1 = 0xFF0E1630;
  static const night2 = 0xFF1E2D4A;
  static const mist = 0xFFDDE2E8;
  static const feather = 0xFFAEB6C2;
  static const paper = 0xFFF6F7F9;

  static String get platform => Platform.isWindows
      ? 'windows'
      : Platform.isMacOS
      ? 'macos'
      : Platform.isLinux
      ? 'linux'
      : Platform.isAndroid
      ? 'android'
      : Platform.isIOS
      ? 'ios'
      : 'device';
}

class SonarKey {
  const SonarKey({required this.name, required this.subscription});

  final String name;
  final String subscription;
}

class SonarKeyException implements Exception {
  const SonarKeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Идентификатор устройства: случайный, создаётся один раз. Сервер хранит только его
/// отпечаток и по нему возвращает тот же ключ после переустановки.
Future<String> sonarDeviceId(SharedPreferences prefs) async {
  const key = 'sonar_device_id';
  final saved = prefs.getString(key);
  if (saved != null && saved.length >= 16) return saved;
  final id = const Uuid().v4().replaceAll('-', '');
  await prefs.setString(key, id);
  return id;
}

/// Получает личный ключ: подписку со всеми каналами Sonar.
Future<SonarKey> sonarIssueKey(SharedPreferences prefs) async {
  if (Sonar.api.isEmpty) {
    throw const SonarKeyException('В этой сборке нет адреса сервера Sonar.');
  }
  final device = await sonarDeviceId(prefs);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      validateStatus: (_) => true,
    ),
  );
  try {
    for (var attempt = 1; ; attempt++) {
      try {
        final r = await dio.post<dynamic>(
          '${Sonar.api}/v1/register',
          data: {'device': device, 'platform': Sonar.platform},
        );
        final data = r.data is Map ? (r.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
        if (r.statusCode == 200 && data['subscription'] is String) {
          return SonarKey(name: data['name'] as String? ?? '', subscription: data['subscription'] as String);
        }
        throw SonarKeyException(data['message'] as String? ?? 'Сервер ответил ошибкой ${r.statusCode}.');
      } on DioException {
        // Связь с сервером рвётся на плохих сетях: две повторные попытки с паузой
        if (attempt >= 3) {
          throw const SonarKeyException('Нет связи с сервером Sonar. Проверьте интернет и попробуйте ещё раз.');
        }
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  } finally {
    dio.close();
  }
}
