import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_aurora.dart';
import 'package:hiddify/sonar/sonar_settings.dart';
import 'package:hiddify/sonar/sonar_style.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // Sonar: меню нет, поэтому назад на главную ведёт стрелка
        leading: IconButton(
          tooltip: 'На главную',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: SonarAurora(
        mood: SonarMood.idle,
        calm: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  const SonarAppCard(),
                  const SonarSettingsLabel('Основное'),
                  SonarSettingsGroup(
                    children: [
                      SonarSettingsTile(
                        icon: Icons.tune_rounded,
                        title: t.pages.settings.general.title,
                        subtitle: PlatformUtils.isDesktop ? 'Язык, автозапуск, окно' : 'Язык, уведомления, батарея',
                        onTap: () => context.go(context.namedLocation('general')),
                      ),
                      SonarSettingsTile(
                        icon: Icons.alt_route_rounded,
                        tint: const Color(0xFF5EEAD4),
                        title: t.pages.settings.routing.title,
                        subtitle: 'Что идёт через Sonar, а что напрямую',
                        onTap: () => context.go(context.namedLocation('routingOptions')),
                      ),
                    ],
                  ),
                  // Sonar: тонкие настройки ядра отдельно, обычно их не трогают
                  const SonarSettingsLabel('Для опытных'),
                  SonarSettingsGroup(
                    children: [
                      SonarSettingsTile(
                        icon: Icons.dns_rounded,
                        tint: const Color(0xFFB48CFF),
                        title: t.pages.settings.dns.title,
                        subtitle: 'Через какие серверы искать адреса',
                        onTap: () => context.go(context.namedLocation('dnsOptions')),
                      ),
                      SonarSettingsTile(
                        icon: Icons.input_rounded,
                        tint: const Color(0xFFB48CFF),
                        title: t.pages.settings.inbound.title,
                        subtitle: 'Режим работы, порты, локальная сеть',
                        onTap: () => context.go(context.namedLocation('inboundOptions')),
                      ),
                      SonarSettingsTile(
                        icon: Icons.content_cut_rounded,
                        tint: const Color(0xFFB48CFF),
                        title: t.pages.settings.tlsTricks.title,
                        subtitle: 'Маскировка для очень строгих сетей',
                        onTap: () => context.go(context.namedLocation('tlsTricks')),
                      ),
                      if (PlatformUtils.isIOS)
                        SonarSettingsTile(
                          icon: Icons.autorenew_rounded,
                          tint: const Color(0xFFFFC979),
                          title: t.pages.settings.resetTunnel,
                          trailing: const SizedBox(),
                          onTap: () async => await ref.read(resetTunnelNotifierProvider.notifier).run(),
                        ),
                    ],
                  ),
                  const SonarSettingsLabel('Sonar'),
                  SonarSettingsGroup(
                    children: [
                      SonarSettingsTile(
                        icon: Icons.devices_rounded,
                        tint: const Color(0xFF5EEAD4),
                        title: 'Другие устройства',
                        subtitle: 'Скачать Sonar на телефон или компьютер',
                        trailing: Icon(
                          Icons.north_east_rounded,
                          size: 18,
                          color: const Color(Sonar.feather).withValues(alpha: .6),
                        ),
                        // зеркало открывается у всех провайдеров, vercel.app не везде
                        onTap: () => launchUrl(Uri.parse(Sonar.mirror), mode: LaunchMode.externalApplication),
                      ),
                      SonarSettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: t.pages.about.title,
                        subtitle: 'Версия, лицензии, рабочая папка',
                        onTap: () => context.go(context.namedLocation('about')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
