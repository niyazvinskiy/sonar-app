import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/widget/adaptive_icon.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_settings.dart';
import 'package:hiddify/sonar/sonar_style.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Sonar: своя страница вместо Hiddify. Обновления проверяет карточка в настройках,
// поэтому здесь только кто мы, ссылки и откуда взялся код.
class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    const open = Icon(Icons.north_east_rounded, size: 18, color: Color(0x99AEB6C2));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.about.title),
        actions: [
          PopupMenuButton(
            icon: Icon(AdaptiveIcon(context).more),
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  child: Text(t.common.addToClipboard),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appInfo.format()));
                  },
                ),
              ];
            },
          ),
          const Gap(8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const Gap(12),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-.3, -.4),
                      colors: [Color(0xFF2A3A66), Color(Sonar.night1)],
                    ),
                    border: Border.all(color: const Color(Sonar.mist).withValues(alpha: .18)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF7C8CFF).withValues(alpha: .25), blurRadius: 40, spreadRadius: -6),
                    ],
                  ),
                  child: Assets.images.logo.svg(),
                ),
              ),
              const Gap(16),
              const Text('Sonar', textAlign: TextAlign.center, style: SonarText.title),
              const Gap(4),
              Text(
                '${t.common.version} ${appInfo.presentVersion}',
                textAlign: TextAlign.center,
                style: SonarText.hint,
              ),
              const Gap(10),
              const Text(
                'Свой VPN для друзей: быстрый, без рекламы\nи без журналов посещений',
                textAlign: TextAlign.center,
                style: SonarText.body,
              ),
              const SonarSettingsLabel('Ссылки'),
              SonarSettingsGroup(
                children: [
                  SonarSettingsTile(
                    icon: Icons.public_rounded,
                    tint: const Color(0xFF5EEAD4),
                    title: 'Сайт Sonar',
                    subtitle: 'Скачать на другие устройства',
                    trailing: open,
                    onTap: () => UriUtils.tryLaunch(Uri.parse(Sonar.site)),
                  ),
                  SonarSettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Как устроена защита',
                    subtitle: 'Что видит сервер и чего не видит',
                    trailing: open,
                    onTap: () => UriUtils.tryLaunch(Uri.parse(Constants.privacyPolicyUrl)),
                  ),
                  SonarSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Вопросы и ответы',
                    trailing: open,
                    onTap: () => UriUtils.tryLaunch(Uri.parse(Constants.termsAndConditionsUrl)),
                  ),
                  SonarSettingsTile(
                    icon: Icons.code_rounded,
                    tint: const Color(0xFFB48CFF),
                    title: t.pages.about.sourceCode,
                    subtitle: 'Открытый код на GitHub',
                    trailing: open,
                    onTap: () => UriUtils.tryLaunch(Uri.parse(Constants.githubUrl)),
                  ),
                ],
              ),
              if (PlatformUtils.isDesktop) ...[
                const Gap(12),
                SonarSettingsGroup(
                  children: [
                    SonarSettingsTile(
                      icon: Icons.folder_open_rounded,
                      tint: const Color(0xFFFFC979),
                      title: t.pages.about.openWorkingDir,
                      subtitle: 'Журнал ядра и настройки, если просят помочь',
                      onTap: () async {
                        final path = ref.read(appDirectoriesProvider).requireValue.workingDir.uri;
                        await UriUtils.tryLaunch(path);
                      },
                    ),
                  ],
                ),
              ],
              const Gap(22),
              const Text(
                'Sonar сделан на основе открытого клиента Hiddify и ядра sing-box. '
                'Распространяется по лицензии Hiddify (GPL v3 с дополнениями), коммерческое использование запрещено.',
                textAlign: TextAlign.center,
                style: SonarText.hint,
              ),
              TextButton(
                onPressed: () => UriUtils.tryLaunch(Uri.parse(Constants.licenseUrl)),
                child: const Text('Текст лицензии'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
