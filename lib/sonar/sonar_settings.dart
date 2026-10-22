import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_aurora.dart';
import 'package:hiddify/sonar/sonar_style.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Фон внутренних экранов: то же спокойное сияние, что в настройках. Сама страница
/// и её шапка становятся прозрачными и лежат поверх него.
class SonarBackdrop extends StatelessWidget {
  const SonarBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SonarAurora(
      mood: SonarMood.idle,
      calm: true,
      child: Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: theme.appBarTheme.copyWith(backgroundColor: Colors.transparent),
        ),
        child: child,
      ),
    );
  }
}

/// Подпись над группой настроек.
class SonarSettingsLabel extends StatelessWidget {
  const SonarSettingsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 22, 8, 8),
    child: Text(text.toUpperCase(), style: SonarText.label),
  );
}

/// Стеклянная карточка с пунктами, разделёнными тонкой линией.
class SonarSettingsGroup extends StatelessWidget {
  const SonarSettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(indent: 68, height: 1));
      items.add(children[i]);
    }
    return DecoratedBox(
      decoration: sonarGlass(radius: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          type: MaterialType.transparency,
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// Пункт настроек: значок в цветной плашке, название, пояснение.
class SonarSettingsTile extends StatelessWidget {
  const SonarSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tint = const Color(0xFF7C8CFF),
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color tint;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tint.withValues(alpha: .28)),
      ),
      child: Icon(icon, size: 19, color: Color.lerp(tint, Colors.white, .25)),
    ),
    title: Text(title, style: SonarText.item.copyWith(fontWeight: FontWeight.w400)),
    subtitle: subtitle == null ? null : Text(subtitle!, style: SonarText.hint),
    trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: const Color(Sonar.feather).withValues(alpha: .6)),
  );
}

/// Карточка приложения в настройках: версия и обновления под рукой.
class SonarAppCard extends HookConsumerWidget {
  const SonarAppCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appInfoProvider).valueOrNull?.presentVersion ?? '';
    final u = ref.watch(sonarUpdaterProvider);
    final checking = useState(false);
    final checked = useState(false);

    Future<void> check() async {
      checking.value = true;
      await ref.read(sonarUpdaterProvider.notifier).check();
      if (!context.mounted) return;
      checking.value = false;
      checked.value = true;
    }

    final (String status, String? action, VoidCallback? onAction) = switch (u.phase) {
      SonarUpdatePhase.downloading => ('Скачиваю ${u.version}… ${(u.progress * 100).round()}%', null, null),
      SonarUpdatePhase.ready => (
        'Версия ${u.version} готова',
        Platform.isAndroid ? 'Установить' : (Platform.isMacOS ? 'Открыть' : 'Обновить'),
        () => ref.read(sonarUpdaterProvider.notifier).install(),
      ),
      SonarUpdatePhase.installing => ('Ставлю ${u.version}…', null, null),
      SonarUpdatePhase.failed => (
        'Обновление ${u.version} не скачалось',
        'Вручную',
        () => launchUrl(Uri.parse(u.page), mode: LaunchMode.externalApplication),
      ),
      SonarUpdatePhase.idle when checking.value => ('Проверяю обновления…', null, null),
      SonarUpdatePhase.idle when checked.value => ('Это последняя версия', 'Проверить', check),
      SonarUpdatePhase.idle => ('Обновляется сам, в фоне', 'Проверить', check),
    };
    final busy = checking.value || u.phase == SonarUpdatePhase.downloading || u.phase == SonarUpdatePhase.installing;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 10, 16),
      decoration: sonarGlass(radius: 22, active: true, glow: const Color(0xFF7C8CFF)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-.3, -.4),
                colors: [Color(0xFF2A3A66), Color(Sonar.night1)],
              ),
              border: Border.all(color: const Color(Sonar.mist).withValues(alpha: .18)),
            ),
            child: Assets.images.logo.svg(),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(version.isEmpty ? 'Sonar' : 'Sonar $version', style: SonarText.value.copyWith(fontSize: 18)),
                const Gap(3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    status,
                    key: ValueKey(status),
                    style: SonarText.hint.copyWith(
                      color: u.phase == SonarUpdatePhase.ready ? const Color(0xFF5EEAD4) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
