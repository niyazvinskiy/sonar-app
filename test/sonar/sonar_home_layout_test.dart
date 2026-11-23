import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/sonar/sonar_home_view.dart';
import 'package:hiddify/sonar/sonar_settings.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';

const _connected = SonarHomeData(
  sphere: SphereState.connected,
  title: 'Всё открыто',
  subtitle: 'Основной · через Sonar только заблокированное',
  channel: 'Основной',
  ping: 51,
  down: 2516582,
  up: 131072,
  downTotal: 1288490188,
  upTotal: 88080384,
);

Widget _app(Widget child, {double scale = 1, bool reducedMotion = true}) => MaterialApp(
  theme: ThemeData.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale), disableAnimations: reducedMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('connection, mode and channel actions keep their callbacks', (tester) async {
    tester.view.physicalSize = const Size(1080, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var disconnected = false;
    var channel = false;
    bool? mode;
    await tester.pumpWidget(
      _app(
        SonarHomeView(
          data: _connected,
          onTap: () => disconnected = true,
          onMode: (value) => mode = value,
          onChannel: () => channel = true,
        ),
      ),
    );
    await tester.tap(find.text('Отключить'));
    await tester.tap(find.text('Всё через Sonar'));
    await tester.tap(find.text('Основной'));
    expect(disconnected, isTrue);
    expect(mode, isFalse);
    expect(channel, isTrue);
    expect(find.text('51 мс'), findsOneWidget);
    expect(find.textContaining('Хельсинки'), findsNothing);
  });

  testWidgets('connecting disables the action when data forbids stopping', (tester) async {
    await tester.pumpWidget(
      _app(
        SonarHomeView(
          data: const SonarHomeData(sphere: SphereState.connecting, title: 'Подключаю…', subtitle: '', tappable: false),
          onTap: () => fail('Disabled action must not connect twice'),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(find.byWidgetPredicate((widget) => widget is FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Подключение…'), findsOneWidget);
    expect(find.text('Показатели появятся после подключения.'), findsOneWidget);
  });

  for (final scale in [1.0, 1.8]) {
    testWidgets('380px window keeps controls reachable at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(380, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SonarHomeView(data: _connected, onTap: () {}, onChannel: () {}, onMode: (_) {}),
          scale: scale,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Отключить'));
      await tester.tap(find.text('Отключить'));
      await tester.ensureVisible(find.text('Основной'));
      await tester.tap(find.text('Основной'));
      await tester.ensureVisible(find.textContaining('За сеанс:'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion stops both ambient and sphere animation', (tester) async {
    await tester.pumpWidget(_app(const SonarHomeView(data: _connected)));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings row wraps long explanations in narrow enlarged layout', (tester) async {
    tester.view.physicalSize = const Size(380, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: SonarSettingsGroup(
            children: [
              SonarSettingsTile(
                icon: Icons.power_settings_new_rounded,
                title: 'Запускать вместе с Windows',
                subtitle: 'Sonar будет запускаться при входе в вашу учётную запись.',
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
            ],
          ),
        ),
        scale: 1.8,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Запускать вместе с Windows'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
