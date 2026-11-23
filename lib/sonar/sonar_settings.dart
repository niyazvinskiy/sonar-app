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
    padding: const EdgeInsetsDirectional.fromSTEB(0, 28, 0, 12),
    child: Text(text, style: SonarText.item),
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
      if (i > 0) items.add(const Divider(indent: 56, endIndent: 18, height: 1, color: Color(0xFF29364A)));
      items.add(children[i]);
    }
    return DecoratedBox(
      decoration: sonarGlass(radius: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          type: MaterialType.transparency,
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// Пункт настроек с привычной нативной иерархией: название, пояснение, действие.
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
    contentPadding: const EdgeInsetsDirectional.fromSTEB(18, 10, 14, 10),
    minLeadingWidth: 22,
    horizontalTitleGap: 14,
    leading: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Icon(icon, size: 22, color: const Color(Sonar.mist)),
    ),
    title: Text(title, style: SonarText.item),
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
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF314054))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Assets.images.logo.svg(width: 32, height: 32),
              const Gap(12),
              Expanded(
                child: Text(
                  version.isEmpty ? 'Sonar' : 'Sonar $version',
                  style: SonarText.title.copyWith(fontSize: 24),
                ),
              ),
              if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const Gap(12),
          Semantics(liveRegion: true, child: Text(status, style: SonarText.body)),
          if (u.phase == SonarUpdatePhase.downloading) ...[const Gap(12), LinearProgressIndicator(value: u.progress)],
          if (action != null) ...[
            const Gap(8),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.system_update_alt_rounded, size: 18),
              label: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}
