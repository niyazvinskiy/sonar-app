// Снимки экранов Sonar в PNG, чтобы смотреть интерфейс без запуска приложения.
// Только по запросу, в CI не идут (шрифты там рисуются иначе):
//   SONAR_SCREENS=1 flutter test --no-pub --update-goldens test/sonar/sonar_screens_test.dart
// Картинки появляются в test/sonar/screens/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_channels.dart';
import 'package:hiddify/sonar/sonar_home_view.dart';
import 'package:hiddify/sonar/sonar_intro.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

ThemeData _theme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Jost',
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8FA1C9), brightness: Brightness.dark),
);

Widget _frame(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _theme(),
  home: Scaffold(backgroundColor: const Color(Sonar.night0), body: child),
);

class _NoUpdates extends SonarUpdater {
  @override
  SonarUpdateState build() => const SonarUpdateState(SonarUpdatePhase.idle);
}

class _FakeProxies extends ProxiesOverviewNotifier {
  @override
  Stream<OutboundGroup?> build() => Stream.value(
    OutboundGroup(
      tag: 'select',
      selected: 'auto',
      items: [
        OutboundInfo(tag: 'auto', tagDisplay: 'auto', isGroup: true, isVisible: true, urlTestDelay: 51),
        OutboundInfo(tag: 'a', tagDisplay: 'Sonar · Основной', isVisible: true, urlTestDelay: 51),
        OutboundInfo(tag: 'b', tagDisplay: 'Sonar · Игры', isVisible: true, urlTestDelay: 64),
        OutboundInfo(tag: 'c', tagDisplay: 'Sonar · Запасной', isVisible: true, urlTestDelay: 148),
        OutboundInfo(tag: 'd', tagDisplay: 'Sonar · Запасной 443', isVisible: true, urlTestDelay: 260),
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
        overrides: [proxiesOverviewNotifierProvider.overrideWith(_FakeProxies.new)],
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
}
