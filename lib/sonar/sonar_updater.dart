import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_windows.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

enum SonarUpdatePhase { idle, downloading, ready, installing, failed }

class SonarUpdateState {
  const SonarUpdateState(
    this.phase, {
    this.version = '',
    this.progress = 0,
    this.file,
    this.page = '',
    this.error = '',
  });

  final SonarUpdatePhase phase;
  final String version;
  final double progress;
  final File? file;
  final String page;
  final String error;
}

/// Обновления Sonar сами: новая версия ищется в релизах GitHub при запуске и раз в
/// 6 часов, скачивается в фоне и ставится.
///
/// Windows и Linux ставят без вопросов: при выключенном VPN сразу, при включённом,
/// когда человек отошёл от компьютера на 3 минуты, и не позже чем через 12 часов
/// после скачивания. Sonar перезапускается и подключается сам. Android делает то же
/// из службы VPN (SonarUpdate.kt), а здесь остаётся кнопка «Обновить». На macOS
/// откроется образ.
///
/// Загрузка не сдаётся с первого раза: три попытки с докачкой, потом через сам Sonar,
/// если GitHub напрямую не отвечает. Выпуск, к которому файл ещё не приложен, не
/// ошибка: через 15 минут проверка повторится.
class SonarUpdater extends Notifier<SonarUpdateState> {
  final _log = appLogger('SonarUpdater');
  Timer? _timer;
  Timer? _retry;
  Timer? _idleWatch;
  DateTime? _readyAt;
  bool _autoInstallTried = false;

  @override
  SonarUpdateState build() {
    if (Platform.isIOS) return const SonarUpdateState(SonarUpdatePhase.idle);
    _timer = Timer.periodic(const Duration(hours: 6), (_) => check());
    ref.onDispose(() {
      _timer?.cancel();
      _retry?.cancel();
      _idleWatch?.cancel();
    });
    Future<void>.delayed(const Duration(seconds: 4), check);
    // Скачанное обновление при выключенном VPN ставим сразу
    ref.listen(connectionNotifierProvider, (_, next) {
      if (next.valueOrNull is Disconnected && state.phase == SonarUpdatePhase.ready) _autoInstall();
    });
    return const SonarUpdateState(SonarUpdatePhase.idle);
  }

  static String? get _assetName {
    if (Platform.isWindows) return 'Sonar-Windows-Setup-x64.exe';
    if (Platform.isMacOS) return 'Sonar-MacOS.dmg';
    if (Platform.isLinux) return 'Sonar-Linux-x64.AppImage';
    if (Platform.isAndroid) {
      final v = Platform.version;
      if (v.contains('android_arm64')) return 'Sonar-Android-arm64.apk';
      if (v.contains('android_arm')) return 'Sonar-Android-arm7.apk';
      if (v.contains('android_x64')) return 'Sonar-Android-x86_64.apk';
      return 'Sonar-Android-universal.apk';
    }
    return null;
  }

  void _retryIn(Duration d) {
    _retry?.cancel();
    _retry = Timer(d, check);
  }

  Future<void> check() async {
    if (state.phase == SonarUpdatePhase.downloading || state.phase == SonarUpdatePhase.installing) return;
    if (state.phase == SonarUpdatePhase.ready) return _scheduleInstall();
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), validateStatus: (_) => true));
    try {
      final current = Version.parse((await PackageInfo.fromPlatform()).version);
      final r = await dio.get<dynamic>(
        'https://api.github.com/repos/${Sonar.repo}/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      if (r.statusCode != 200 || r.data is! Map) {
        _log.warning('releases/latest ответил ${r.statusCode}');
        return _retryIn(const Duration(hours: 1));
      }
      final release = (r.data as Map).cast<String, dynamic>();
      final tag = (release['tag_name'] as String? ?? '').replaceFirst(RegExp('^(sonar-)?v'), '');
      final latest = Version.parse(tag.split('+').first);
      await _cleanup(keep: latest > current ? tag : null);
      if (latest <= current) return;

      final page = release['html_url'] as String? ?? 'https://github.com/${Sonar.repo}/releases/latest';
      final assets = (release['assets'] as List? ?? const []).cast<Map<dynamic, dynamic>>();
      final asset = assets.where((a) => a['name'] == _assetName).firstOrNull;
      if (asset == null) {
        // файлы прикладываются к выпуску не мгновенно: это ещё не ошибка
        _log.info('в выпуске $tag пока нет $_assetName, проверю через 15 минут');
        return _retryIn(const Duration(minutes: 15));
      }

      final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}sonar-update');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$tag-${asset['name']}');
      final size = asset['size'] as int? ?? 0;
      if (!(await file.exists() && await file.length() == size)) {
        state = SonarUpdateState(SonarUpdatePhase.downloading, version: tag, page: page);
        await _download(asset['browser_download_url'] as String, file, size, tag, page);
      }
      state = SonarUpdateState(SonarUpdatePhase.ready, version: tag, file: file, page: page);
      _readyAt = DateTime.now();
      await _scheduleInstall();
    } catch (e) {
      _log.error('обновление не скачалось', e);
      state = SonarUpdateState(SonarUpdatePhase.failed, version: state.version, page: state.page, error: '$e');
      // плашка «не скачалось» не навсегда: через час попробуем снова
      _retryIn(const Duration(hours: 1));
    } finally {
      dio.close();
    }
  }

  /// Три попытки напрямую с докачкой с места обрыва, потом через сам Sonar.
  Future<void> _download(String url, File file, int size, String tag, String page) async {
    final part = File('${file.path}.part');
    Object? last;
    for (final viaSonar in [false, false, false, true]) {
      if (viaSonar && !_canProxy) break;
      // тишина дольше минуты: связь оборвалась, следующая попытка докачает
      final dio = Dio(
        BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(minutes: 1)),
      );
      if (viaSonar) {
        final port = ref.read(ConfigOptions.mixedPort);
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:$port',
        );
      }
      try {
        final have = await part.exists() ? await part.length() : 0;
        final resp = await dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {if (have > 0 && have < size) 'Range': 'bytes=$have-'},
          ),
        );
        final append = have > 0 && resp.statusCode == 206;
        final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
        var got = append ? have : 0;
        try {
          await for (final chunk in resp.data!.stream) {
            sink.add(chunk);
            got += chunk.length;
            if (size > 0) {
              state = SonarUpdateState(SonarUpdatePhase.downloading, version: tag, page: page, progress: got / size);
            }
          }
        } finally {
          await sink.close();
        }
        if (size > 0 && await part.length() != size) throw Exception('файл скачался не целиком');
        await part.rename(file.path);
        return;
      } catch (e) {
        last = e;
        _log.warning('загрузка ${viaSonar ? 'через Sonar' : 'напрямую'} не удалась: $e');
        await Future<void>.delayed(const Duration(seconds: 5));
      } finally {
        dio.close();
      }
    }
    throw last ?? Exception('файл не скачался');
  }

  /// Через локальный прокси Sonar можно качать, только пока он подключён на компьютере.
  bool get _canProxy =>
      !Platform.isAndroid && !Platform.isIOS && ref.read(connectionNotifierProvider).valueOrNull is Connected;

  /// Убирает скачанные раньше установщики: после обновления они только занимают место.
  static Future<void> _cleanup({String? keep}) async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}sonar-update');
      if (!dir.existsSync()) return;
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (keep != null && name.startsWith('$keep-')) continue;
        if (name.endsWith('.cmd')) continue;
        await f.delete();
      }
    } catch (_) {}
  }

  bool get _silentPlatform => Platform.isWindows || (Platform.isLinux && Platform.environment['APPIMAGE'] != null);

  /// Когда ставить скачанное: VPN выключен — сразу; включён — когда человек отошёл.
  Future<void> _scheduleInstall() async {
    if (!_silentPlatform) return;
    if (ref.read(connectionNotifierProvider).valueOrNull is! Connected) return _autoInstall();
    _idleWatch?.cancel();
    _idleWatch = Timer.periodic(const Duration(minutes: 1), (_) {
      final waited = _readyAt == null ? Duration.zero : DateTime.now().difference(_readyAt!);
      if (sonarIdle() >= const Duration(minutes: 3) || waited >= const Duration(hours: 12)) {
        _idleWatch?.cancel();
        unawaited(_autoInstall());
      }
    });
  }

  /// Без вопросов ставим только на Windows и Linux, и только один раз за запуск.
  Future<void> _autoInstall() async {
    if (_autoInstallTried || !_silentPlatform) return;
    _autoInstallTried = true;
    await install();
  }

  Future<void> install() async {
    final file = state.file;
    if (file == null) {
      if (state.page.isNotEmpty) await launchUrl(Uri.parse(state.page), mode: LaunchMode.externalApplication);
      return;
    }
    final version = state.version;
    state = SonarUpdateState(SonarUpdatePhase.installing, version: version, file: file, page: state.page);
    try {
      // Сначала аккуратно выключаем туннель, чтобы установщик мог заменить файлы ядра,
      // а новая версия подключится сама. На Android не надо: система сама перезапустит
      // приложение, а VPN включит BootReceiver
      if (!Platform.isAndroid && ref.read(connectionNotifierProvider).valueOrNull is Connected) {
        await SonarWindows.markConnectAfterRestart(ref.read(sharedPreferencesProvider.future));
        await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      if (Platform.isWindows) {
        final exe = Platform.resolvedExecutable;
        final script = File('${file.parent.path}\\sonar-update.cmd');
        await script.writeAsString(
          [
            '@echo off',
            'ping -n 3 127.0.0.1 >nul',
            '"${file.path}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS',
            'start "" "$exe"',
            'del "%~f0"',
          ].join('\r\n'),
        );
        await Process.start('cmd.exe', ['/c', script.path], mode: ProcessStartMode.detached);
        exit(0);
      } else if (Platform.isLinux) {
        final target = Platform.environment['APPIMAGE'];
        if (target == null) {
          await launchUrl(Uri.parse(state.page), mode: LaunchMode.externalApplication);
          return;
        }
        await file.copy('$target.new');
        await Process.run('chmod', ['+x', '$target.new']);
        await File('$target.new').rename(target);
        await Process.start(target, const [], mode: ProcessStartMode.detached);
        exit(0);
      } else if (Platform.isAndroid) {
        // Системный установщик: на Android 12+ без вопросов, иначе система спросит сама
        await const MethodChannel(
          'app.sonar/update',
        ).invokeMethod<bool>('install', {'path': file.path, 'version': version});
        state = SonarUpdateState(SonarUpdatePhase.ready, version: version, file: file, page: state.page);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
        state = SonarUpdateState(SonarUpdatePhase.ready, version: version, file: file, page: state.page);
      }
    } catch (e) {
      _log.error('обновление не поставилось', e);
      state = SonarUpdateState(SonarUpdatePhase.failed, version: version, file: file, page: state.page, error: '$e');
    }
  }
}

final sonarUpdaterProvider = NotifierProvider<SonarUpdater, SonarUpdateState>(SonarUpdater.new);

/// Плашка над сферой: качается, готово, ставится или не вышло.
class SonarUpdateBanner extends ConsumerWidget {
  const SonarUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(sonarUpdaterProvider);
    final (text, action) = switch (u.phase) {
      SonarUpdatePhase.downloading => ('Скачиваю Sonar ${u.version}… ${(u.progress * 100).round()}%', null),
      SonarUpdatePhase.ready => (
        'Sonar ${u.version} готов',
        Platform.isAndroid ? 'Установить' : (Platform.isMacOS ? 'Открыть' : 'Обновить'),
      ),
      SonarUpdatePhase.installing => ('Обновляю Sonar до ${u.version}…', null),
      SonarUpdatePhase.failed => ('Sonar ${u.version} пока не скачался, попробую ещё', 'Вручную'),
      SonarUpdatePhase.idle => ('', null),
    };
    if (text.isEmpty) return const SizedBox(height: 12);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(Sonar.night2).withValues(alpha: .7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(Sonar.mist).withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(Sonar.mist), fontSize: 14)),
          ),
          if (action != null)
            TextButton(
              onPressed: u.phase == SonarUpdatePhase.failed
                  ? () => launchUrl(Uri.parse(u.page), mode: LaunchMode.externalApplication)
                  : () => ref.read(sonarUpdaterProvider.notifier).install(),
              child: Text(action),
            ),
          if (u.phase == SonarUpdatePhase.downloading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, value: u.progress > 0 ? u.progress : null),
              ),
            ),
        ],
      ),
    );
  }
}
