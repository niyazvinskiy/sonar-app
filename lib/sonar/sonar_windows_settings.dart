import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/sonar/sonar_connection_recovery.dart';
import 'package:hiddify/sonar/sonar_settings.dart';
import 'package:hiddify/sonar/sonar_windows.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Windows automation is separate from the connection button: switching off
/// startup does not unexpectedly tear down a call that is already connected.
class SonarWindowsSettings extends HookConsumerWidget {
  const SonarWindowsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(autoStartNotifierProvider);
    final recovery = ref.watch(sonarConnectionRecoveryProvider);
    final busy = useState(false);
    final error = useState<String?>(null);
    Future<void> changeStartup(bool on) async {
      busy.value = true;
      error.value = null;
      try {
        final notifier = ref.read(autoStartNotifierProvider.notifier);
        if (on) {
          await notifier.enable();
        } else {
          await notifier.disable();
        }
      } catch (_) {
        if (context.mounted) error.value = 'Windows не сохранила настройку. Нажмите «Настроить запуск»';
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SonarSettingsLabel('Автоматическая работа'),
        SonarSettingsGroup(
          children: [
            SonarSettingsTile(
              icon: Icons.power_settings_new_rounded,
              title: 'Запускать вместе с Windows',
              subtitle: 'После входа в вашу учётную запись, без повторного запроса прав',
              trailing: Switch(
                value: startup.valueOrNull ?? false,
                onChanged: busy.value || !startup.hasValue ? null : changeStartup,
              ),
            ),
            SonarSettingsTile(
              icon: Icons.sync_rounded,
              title: 'Подключаться при запуске',
              subtitle: 'При новом включении ПК. Кнопка отключения останавливает текущие попытки',
              trailing: Switch(
                value: recovery.autoConnect,
                onChanged: ref.read(sonarConnectionRecoveryProvider.notifier).setAutoConnect,
              ),
            ),
            SonarSettingsTile(
              icon: Icons.verified_user_outlined,
              title: 'Настроить запуск',
              subtitle: error.value ?? 'Одно подтверждение Windows для настройки прав VPN',
              onTap: () => SonarWindows.restartAsAdmin(ref),
            ),
          ],
        ),
      ],
    );
  }
}
