// Снимки экранов Sonar в PNG, чтобы смотреть интерфейс без запуска приложения.
// Только по запросу, в CI не идут (шрифты там рисуются иначе):
//   SONAR_SCREENS=1 flutter test --no-pub --update-goldens test/sonar/sonar_screens_test.dart
// Картинки появляются в test/sonar/screens/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/analytics/analytics_controller.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/core/model/environment.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/features/about/widget/about_page.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/features/settings/overview/sections/dns_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/general_page.dart';
import 'package:hiddify/features/settings/overview/sections/inbound_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/routing_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/tls_tricks_page.dart';
import 'package:hiddify/features/settings/overview/settings_page.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_channel_guard.dart';
import 'package:hiddify/sonar/sonar_channels.dart';
import 'package:hiddify/sonar/sonar_home_view.dart';
import 'package:hiddify/sonar/sonar_intro.dart';
import 'package:hiddify/sonar/sonar_settings.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _enabled = Platform.environment['SONAR_SCREENS'] == '1';

Future<void> _loadFonts() async {
  final jost = FontLoader('Jost');
  for (final w in [300, 400, 500, 600]) {
    jost.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Jost-$w.ttf').readAsBytesSync())));
  }
  await jost.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
  }
}

// та же тема, что в приложении
ThemeData _theme() => AppTheme(AppThemeMode.dark, 'Jost').darkTheme(null);

Widget _frame(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _theme(),
  home: Scaffold(backgroundColor: const Color(Sonar.night0), body: child),
);

class _NoUpdates extends SonarUpdater {
  @override
  SonarUpdateState build() => const SonarUpdateState(SonarUpdatePhase.idle);
}

class _Ready extends SonarUpdater {
  @override
  SonarUpdateState build() => const SonarUpdateState(SonarUpdatePhase.ready, version: '1.2.1');
}

class _AutoStart extends AutoStartNotifier {
  @override
  Future<bool> build() async => true;
}

class _Analytics extends AnalyticsController {
  @override
  Future<bool> build() async => false;
}

class _Directories extends AppDirectories {
  @override
  Future<Directories> build() async {
    final dir = Directory.systemTemp.createTempSync('sonar_screens');
    return (baseDir: dir, workingDir: dir, tempDir: dir);
  }
}

Future<List<Override>> _app() async {
  SharedPreferences.setMockInitialValues({'region': 'ru', 'locale': 'ru'});
  PackageInfo.setMockInitialValues(
    appName: 'Sonar',
    packageName: 'app.sonar.vpn',
    version: '1.2.0',
    buildNumber: '12000',
    buildSignature: '',
  );
  final ru = await AppLocale.ru.build();
  final prefs = await SharedPreferences.getInstance();
  return [
    environmentProvider.overrideWithValue(Environment.prod),
    translationsProvider.overrideWith((ref) => ru),
    sharedPreferencesProvider.overrideWith((ref) => prefs),
    autoStartNotifierProvider.overrideWith(_AutoStart.new),
    analyticsControllerProvider.overrideWith(_Analytics.new),
    appDirectoriesProvider.overrideWith(_Directories.new),
  ];
}

class _AutoGuard extends SonarChannelGuard {
  @override
  SonarChannelState build() => const SonarChannelState(current: 'a');
}

class _FakeProxies extends ProxiesOverviewNotifier {
  @override
  Stream<OutboundGroup?> build() => Stream.value(
    OutboundGroup(
      tag: 'select',
      selected: 'a',
      items: [
        OutboundInfo(tag: 'lowest', tagDisplay: 'lowest', isGroup: true, isVisible: true, urlTestDelay: 51),
        OutboundInfo(tag: 'balance', tagDisplay: 'balance', isGroup: true, isVisible: true, urlTestDelay: 51),
        OutboundInfo(tag: 'c', tagDisplay: 'Sonar · Запасной', isVisible: true, urlTestDelay: 148),
        OutboundInfo(tag: 'b', tagDisplay: 'Sonar · Игры', isVisible: true, urlTestDelay: 64),
        OutboundInfo(tag: 'a', tagDisplay: 'Sonar · Основной', isVisible: true, urlTestDelay: 51),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  Future<void> shot(WidgetTester tester, String name, Widget child, {Size size = const Size(460, 780)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(child);
    // настроение перетекает больше секунды: ждём, пока цвета встанут
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/$name.png'));
  }

  final states = {
    'idle': const SonarHomeData(
      sphere: SphereState.idle,
      title: 'Коснитесь капли',
      subtitle: 'Умный режим: через Sonar только заблокированное',
    ),
    'connecting': const SonarHomeData(
      sphere: SphereState.connecting,
      title: 'Подключаю…',
      subtitle: '',
      tappable: false,
    ),
    'connected': SonarHomeData(
      sphere: SphereState.connected,
      title: 'Всё открыто',
      subtitle: 'Лучший канал · через Sonar только заблокированное',
      ping: 51,
      connectedSince: DateTime.now().subtract(const Duration(minutes: 12, seconds: 34)),
      down: 2516582,
      up: 131072,
      downTotal: 1288490188,
      upTotal: 88080384,
    ),
    'failed': const SonarHomeData(
      sphere: SphereState.failed,
      title: 'Не удалось подключиться',
      subtitle: 'Коснитесь капли ещё раз. Если не помогает, выберите канал «Запасной 443».',
    ),
    'all-through': SonarHomeData(
      sphere: SphereState.connected,
      title: 'Всё открыто',
      subtitle: 'Основной · через Sonar всё, кроме РФ',
      smart: false,
      channel: 'Основной',
      ping: 48,
      connectedSince: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
      down: 734003,
      up: 51200,
      downTotal: 3355443,
      upTotal: 412000,
    ),
  };

  for (final e in states.entries) {
    testWidgets('экран: ${e.key}', skip: !_enabled, (tester) async {
      await shot(tester, 'home-${e.key}', _frame(SonarHomeView(data: e.value, onChannel: () {}, onMode: (_) {})));
    });
  }

  testWidgets('экран: телефон, в сети', skip: !_enabled, (tester) async {
    await shot(
      tester,
      'phone-connected',
      _frame(SonarHomeView(data: states['connected']!, onChannel: () {})),
      size: const Size(390, 844),
    );
  });

  testWidgets('экран: самое маленькое окно, в сети', skip: !_enabled, (tester) async {
    await shot(
      tester,
      'small-connected',
      _frame(SonarHomeView(data: states['connected']!, onChannel: () {})),
      size: const Size(380, 620),
    );
  });

  testWidgets('экран: первый запуск', skip: !_enabled, (tester) async {
    await shot(
      tester,
      'intro',
      ProviderScope(
        overrides: [sonarUpdaterProvider.overrideWith(_NoUpdates.new)],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: _theme(), home: const SonarIntro()),
      ),
    );
  });

  testWidgets('экран: выбор канала', skip: !_enabled, (tester) async {
    await shot(
      tester,
      'channels',
      ProviderScope(
        overrides: [
          proxiesOverviewNotifierProvider.overrideWith(_FakeProxies.new),
          sonarChannelGuardProvider.overrideWith(_AutoGuard.new),
        ],
        child: _frame(
          Stack(
            children: [
              SonarHomeView(data: states['connected']!),
              const Align(alignment: Alignment.bottomCenter, child: SonarChannelSheet()),
            ],
          ),
        ),
      ),
    );
  });

  Future<void> page(WidgetTester tester, String name, Widget page, List<Override> extra) async {
    final base = await tester.runAsync(_app);
    final container = ProviderContainer(overrides: [...base!, ...extra]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(translationsProvider.future);
      await container.read(sharedPreferencesProvider.future);
      await container.read(appInfoProvider.future);
      await container.read(autoStartNotifierProvider.future);
      await container.read(analyticsControllerProvider.future);
      await container.read(appDirectoriesProvider.future);
      container.listen(rulesNotifierProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await shot(
      tester,
      name,
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: _theme(), home: page),
      ),
    );
  }

  testWidgets('экран: настройки', skip: !_enabled, (tester) async {
    await page(tester, 'settings', SettingsPage(), [sonarUpdaterProvider.overrideWith(_NoUpdates.new)]);
  });

  testWidgets('экран: настройки, обновление готово', skip: !_enabled, (tester) async {
    await page(tester, 'settings-update', SettingsPage(), [sonarUpdaterProvider.overrideWith(_Ready.new)]);
  });

  testWidgets('экран: общие настройки', skip: !_enabled, (tester) async {
    await page(tester, 'settings-general', const SonarBackdrop(child: GeneralPage()), [sonarUpdaterProvider.overrideWith(_NoUpdates.new)]);
  });

  final subpages = <String, Widget Function()>{
    'settings-routing': () => const RoutingOptionsPage(routeRule: null),
    'settings-dns': () => const DnsOptionsPage(),
    'settings-inbound': () => const InboundOptionsPage(),
    'settings-tls': () => const TlsTricksPage(),
    'about': () => const AboutPage(),
  };
  for (final e in subpages.entries) {
    testWidgets('экран: ${e.key}', skip: !_enabled, (tester) async {
      await page(tester, e.key, SonarBackdrop(child: e.value()), [sonarUpdaterProvider.overrideWith(_NoUpdates.new)]);
    });
  }

  testWidgets('экран: диалог', skip: !_enabled, (tester) async {
    await shot(
      tester,
      'dialog',
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Stack(
              children: [
                const ColoredBox(color: Colors.black54, child: SizedBox.expand()),
                AlertDialog(
                  title: const Text('Сбросить настройки?'),
                  content: const Text('Все параметры вернутся к стандартным. Ключ и каналы останутся.'),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Отмена')),
                    TextButton(onPressed: () {}, child: const Text('Сбросить')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  });
}
