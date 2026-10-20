import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

enum SonarUpdatePhase { idle, downloading, ready, installing, failed }

class SonarUpdateState {
  const SonarUpdateState(this.phase, {this.version = '', this.progress = 0, this.file, this.page = '', this.error = ''});

  final SonarUpdatePhase phase;
  final String version;
  final double progress;
  final File? file;
  final String page;
  final String error;
}

/// Обновления Sonar сами: новая версия ищется в релизах GitHub при запуске и раз в
/// 6 часов, скачивается в фоне и ставится. На Windows и Linux без вопросов, на
/// Android система попросит одно касание «Установить», на macOS откроется образ.
class SonarUpdater extends Notifier<SonarUpdateState> {
  Timer? _timer;
  bool _autoInstallTried = false;

  @override
  SonarUpdateState build() {
    if (Platform.isIOS) return const SonarUpdateState(SonarUpdatePhase.idle);
    _timer = Timer.periodic(const Duration(hours: 6), (_) => check());
    ref.onDispose(() => _timer?.cancel());
    Future<void>.delayed(const Duration(seconds: 4), check);
    // Скачанное обновление ставим, как только VPN выключен: связь не рвётся посреди дела
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

  Future<void> check() async {
    if (state.phase == SonarUpdatePhase.downloading || state.phase == SonarUpdatePhase.installing) return;
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), validateStatus: (_) => true));
    try {
      final current = Version.parse((await PackageInfo.fromPlatform()).version);
      final r = await dio.get<dynamic>(
        'https://api.github.com/repos/${Sonar.repo}/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      if (r.statusCode != 200 || r.data is! Map) return;
      final release = (r.data as Map).cast<String, dynamic>();
      final tag = (release['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
      final latest = Version.parse(tag.split('+').first);
      if (latest <= current) return;

      final page = release['html_url'] as String? ?? 'https://github.com/${Sonar.repo}/releases/latest';
      final assets = (release['assets'] as List? ?? const []).cast<Map<dynamic, dynamic>>();
      final asset = assets.where((a) => a['name'] == _assetName).firstOrNull;
      if (asset == null) {
        state = SonarUpdateState(SonarUpdatePhase.failed, version: tag, page: page, error: 'нет файла для этой системы');
        return;
      }

      final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}sonar-update');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$tag-${asset['name']}');
      final size = asset['size'] as int? ?? 0;
      if (!(await file.exists() && await file.length() == size)) {
        state = SonarUpdateState(SonarUpdatePhase.downloading, version: tag, page: page);
        final part = File('${file.path}.part');
        await dio.download(
          asset['browser_download_url'] as String,
          part.path,
          options: Options(receiveTimeout: const Duration(minutes: 10)),
          onReceiveProgress: (got, total) {
            if (total > 0) state = SonarUpdateState(SonarUpdatePhase.downloading, version: tag, page: page, progress: got / total);
          },
        );
        if (size > 0 && await part.length() != size) throw Exception('файл скачался не целиком');
        await part.rename(file.path);
      }
      state = SonarUpdateState(SonarUpdatePhase.ready, version: tag, file: file, page: page);
      if (ref.read(connectionNotifierProvider).valueOrNull is! Connected) await _autoInstall();
    } catch (e) {
      if (state.phase == SonarUpdatePhase.downloading) {
        state = SonarUpdateState(SonarUpdatePhase.failed, version: state.version, page: state.page, error: '$e');
      }
    } finally {
      dio.close();
    }
  }

  /// Без вопросов ставим только на Windows и Linux, и только один раз за запуск.
  Future<void> _autoInstall() async {
    if (_autoInstallTried) return;
    _autoInstallTried = true;
    if (Platform.isWindows || (Platform.isLinux && Platform.environment['APPIMAGE'] != null)) {
      await install();
    }
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
      // Сначала аккуратно выключаем туннель, чтобы установщик мог заменить файлы ядра
      final connection = ref.read(connectionNotifierProvider.notifier);
      if (ref.read(connectionNotifierProvider).valueOrNull is Connected) await connection.toggleConnection();

      if (Platform.isWindows) {
        final exe = Platform.resolvedExecutable;
        final script = File('${file.parent.path}\\sonar-update.cmd');
        await script.writeAsString([
          '@echo off',
          'ping -n 3 127.0.0.1 >nul',
          '"${file.path}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS',
          'start "" "$exe"',
          'del "%~f0"',
        ].join('\r\n'));
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
        final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
        if (result.type != ResultType.done) throw Exception(result.message);
        state = SonarUpdateState(SonarUpdatePhase.ready, version: version, file: file, page: state.page);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
        state = SonarUpdateState(SonarUpdatePhase.ready, version: version, file: file, page: state.page);
      }
    } catch (e) {
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
      SonarUpdatePhase.failed => ('Обновление ${u.version} не скачалось', 'Скачать вручную'),
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
          Expanded(child: Text(text, style: const TextStyle(color: Color(Sonar.mist), fontSize: 14))),
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
