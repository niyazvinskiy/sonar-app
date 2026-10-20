import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_home.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('сфера', () {
    for (final state in SphereState.values) {
      testWidgets('рисуется в состоянии ${state.name}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SonarSphere(state: state, onTap: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(find.byType(SonarSphere), findsOneWidget);
      });
    }

    testWidgets('нажатие доходит до кнопки, а без обработчика её нет', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SonarSphere(state: SphereState.idle, onTap: () => taps++, semanticLabel: 'Подключить'),
          ),
        ),
      );
      await tester.tap(find.byType(SonarSphere));
      expect(taps, 1);

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: SonarSphere(state: SphereState.connecting)),
        ),
      );
      await tester.tap(find.byType(SonarSphere), warnIfMissed: false);
      expect(taps, 1);
    });

    testWidgets('без анимаций стоит на месте', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Center(child: SonarSphere(state: SphereState.connected)),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('подпись канала', () {
    test('убирает приставку Sonar', () {
      expect(sonarChannelLabel('Sonar · Основной'), 'Основной');
      expect(sonarChannelLabel('Sonar · Запасной 443'), 'Запасной 443');
    });
    test('автовыбор и пустое называет лучшим каналом', () {
      expect(sonarChannelLabel(''), 'Лучший канал');
      expect(sonarChannelLabel('auto'), 'Лучший канал');
      expect(sonarChannelLabel('Lowest Ping'), 'Лучший канал');
    });
  });

  group('ключ', () {
    test('идентификатор устройства создаётся один раз', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = await sonarDeviceId(prefs);
      expect(first.length, greaterThanOrEqualTo(16));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(first), isTrue);
      expect(await sonarDeviceId(prefs), first);
    });

    test('без адреса сервера в сборке ключ не запрашивается', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      if (Sonar.api.isNotEmpty) return; // сборка с адресом: проверять тут нечего
      expect(
        () => sonarIssueKey(prefs),
        throwsA(isA<SonarKeyException>().having((e) => e.message, 'message', contains('нет адреса'))),
      );
    });
  });
}
