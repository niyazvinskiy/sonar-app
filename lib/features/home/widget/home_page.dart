import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_home.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sonar: сфера вместо карточки профиля и кнопки Hiddify
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(Sonar.night0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(Sonar.paper),
        title: Row(
          children: [
            Assets.images.logo.svg(height: 24),
            const Gap(10),
            const Text('Sonar', style: TextStyle(fontWeight: FontWeight.w400, letterSpacing: .5)),
            const Gap(8),
            const AppVersionLabel(),
          ],
        ),
      ),
      body: const SonarHome(),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
