import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/analytics/analytics_controller.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_key.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Первый запуск: одна кнопка. Ключ создаётся сам, регион и умный режим уже
/// выставлены, после нажатия Sonar сразу подключается.
class SonarIntro extends HookConsumerWidget {
  const SonarIntro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyStatus = ref.watch(sonarKeyProvider);
    final starting = useState(false);
    final busy = starting.value || keyStatus is SonarKeyIssuing;

    Future<void> start() async {
      if (busy) return;
      starting.value = true;
      try {
        await ref.read(ConfigOptions.region.notifier).update(Region.ru);
        try {
          if (ref.read(analyticsControllerProvider).valueOrNull ?? false) {
            await ref.read(analyticsControllerProvider.notifier).disableAnalytics();
          }
        } catch (_) {}
        if (!await ref.read(sonarKeyProvider.notifier).ensure()) return;
        // Ключ на месте: главный экран подключится сам, как и обещали на сайте
        ref.read(sonarConnectOnHomeProvider.notifier).state = true;
        await ref.read(Preferences.introCompleted.notifier).update(true);
      } finally {
        if (context.mounted) starting.value = false;
      }
    }

    const paper = Color(Sonar.paper);
    const feather = Color(Sonar.feather);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.5),
            radius: 1.3,
            colors: [Color(Sonar.night2), Color(Sonar.night1), Color(Sonar.night0)],
            stops: [0, .45, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    // Обновление проверяется и здесь: старая сборка обновится до первого «Начать»
                    const SonarUpdateBanner(),
                    const SizedBox(height: 12),
                    SonarSphere(
                      state: busy
                          ? SphereState.connecting
                          : keyStatus is SonarKeyFailed
                          ? SphereState.failed
                          : SphereState.idle,
                      size: 240,
                      onTap: busy ? null : start,
                      semanticLabel: 'Начать',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Всё открыто.\nПинг на месте.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, height: 1.12, fontWeight: FontWeight.w300, color: paper),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'YouTube, Discord, Instagram и нейросети открываются, а игры и российские сайты идут напрямую. '
                      'Личный ключ создастся сам: без регистрации и настроек.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.5, color: feather),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: paper,
                          foregroundColor: const Color(Sonar.night0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        onPressed: busy ? null : start,
                        child: busy
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                            : const Text('Начать'),
                      ),
                    ),
                    if (keyStatus is SonarKeyFailed) ...[
                      const SizedBox(height: 14),
                      Text(
                        keyStatus.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Color(0xFFE9C4C8), height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 12, color: feather, height: 1.5),
                        children: [
                          const TextSpan(text: 'Sonar основан на открытом приложении '),
                          TextSpan(
                            text: 'Hiddify',
                            style: const TextStyle(decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(Uri.parse('https://github.com/hiddify/hiddify-app')),
                          ),
                          const TextSpan(text: ' и распространяется по его лицензии. '),
                          TextSpan(
                            text: 'Исходный код',
                            style: const TextStyle(decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(Uri.parse('https://github.com/${Sonar.repo}')),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
