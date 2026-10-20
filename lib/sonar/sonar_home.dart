import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_key.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _paper = Color(Sonar.paper);

/// «Sonar · Основной» → «Основной»; автовыбор Hiddify показывается как «Лучший канал».
String sonarChannelLabel(String tag) {
  final t = tag.trim();
  final lower = t.toLowerCase();
  if (t.isEmpty || lower.contains('auto') || lower.contains('lowest') || lower.contains('select')) {
    return 'Лучший канал';
  }
  return t.replaceFirst(RegExp(r'^Sonar\s*·\s*'), '');
}

const _mist = Color(Sonar.mist);
const _feather = Color(Sonar.feather);

/// Главный экран Sonar: сфера, состояние, режим и канал. Больше ничего.
class SonarHome extends HookConsumerWidget {
  const SonarHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionNotifierProvider);
    final proxy = ref.watch(activeProxyNotifierProvider).unwrapPrevious().valueOrNull;
    final delay = proxy?.urlTestDelay ?? 0;
    final keyStatus = ref.watch(sonarKeyProvider);
    final hasProfile = ref.watch(hasAnyProfileProvider).valueOrNull ?? false;
    final smart = ref.watch(rulesNotifierProvider).sonarSmart;

    final connected = status.valueOrNull is Connected;
    final sphere = switch (status) {
      _ when keyStatus is SonarKeyIssuing => SphereState.connecting,
      _ when keyStatus is SonarKeyFailed => SphereState.failed,
      AsyncError() => SphereState.failed,
      AsyncValue(valueOrNull: Disconnected(connectionFailure: _?)) => SphereState.failed,
      AsyncValue(valueOrNull: Connecting()) || AsyncValue(valueOrNull: Disconnecting()) => SphereState.connecting,
      AsyncValue(valueOrNull: Connected()) when delay == 0 => SphereState.connecting,
      AsyncValue(valueOrNull: Connected()) => SphereState.connected,
      _ => SphereState.idle,
    };

    final title = switch (sphere) {
      _ when keyStatus is SonarKeyIssuing => 'Получаю личный ключ…',
      _ when keyStatus is SonarKeyFailed => 'Ключ не получен',
      SphereState.connected => 'Подключено',
      SphereState.connecting => status.valueOrNull is Disconnecting ? 'Отключаю…' : 'Подключаю…',
      SphereState.failed => 'Не удалось подключиться',
      SphereState.idle => hasProfile ? 'Коснитесь капли' : 'Коснитесь капли, чтобы начать',
    };
    final subtitle = switch (sphere) {
      _ when keyStatus is SonarKeyFailed => keyStatus.message,
      SphereState.connected when ConnectionConst.isValidDelay(delay) =>
        '$delay мс · ${sonarChannelLabel(proxy?.groupSelectedTagDisplay ?? proxy?.tagDisplay ?? '')}',
      SphereState.connected => 'Сервер не отвечает на проверку, пробую другой канал',
      SphereState.failed => _failure(status),
      SphereState.idle =>
        smart ? 'Умный режим: через Sonar только заблокированное' : 'Через Sonar всё, кроме российских сайтов',
      _ => '',
    };

    Future<void> onTap() async {
      final notifier = ref.read(connectionNotifierProvider.notifier);
      if (connected) return notifier.toggleConnection();
      if (status.valueOrNull is! Disconnected && status is! AsyncError) return;
      if (!await ref.read(sonarKeyProvider.notifier).ensure()) return;
      // Подписка только что добавлена: даём ядру подхватить её
      if (!hasProfile) await Future<void>.delayed(const Duration(milliseconds: 600));
      await notifier.toggleConnection();
    }

    final busy = sphere == SphereState.connecting;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.55),
          radius: 1.25,
          colors: [Color(Sonar.night2), Color(Sonar.night1), Color(Sonar.night0)],
          stops: [0, .45, 1],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SonarUpdateBanner(),
                  const Spacer(),
                  SonarSphere(
                    state: sphere,
                    onTap: busy ? null : onTap,
                    size: MediaQuery.sizeOf(context).shortestSide.clamp(220, 320),
                    semanticLabel: connected ? 'Отключить Sonar' : 'Подключить Sonar',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300, color: _paper, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: _feather, height: 1.45),
                    ),
                  ),
                  if (keyStatus is SonarKeyFailed)
                    TextButton(onPressed: onTap, child: const Text('Попробовать ещё раз')),
                  const Spacer(),
                  _ModeSwitch(
                    smart: smart,
                    onChanged: (v) => ref.read(rulesNotifierProvider.notifier).setSonarSmart(v),
                  ),
                  const SizedBox(height: 12),
                  _ChannelButton(
                    label: sonarChannelLabel(proxy?.groupSelectedTagDisplay ?? ''),
                    enabled: hasProfile,
                    onTap: () => context.goNamed('proxies'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _failure(AsyncValue<ConnectionStatus> status) {
    final failure = switch (status) {
      AsyncValue(valueOrNull: Disconnected(connectionFailure: final f?)) => f.toString(),
      AsyncError(:final error) => error.toString(),
      _ => '',
    };
    if (failure.contains('missingPrivilege') || failure.contains('Access is denied')) {
      return 'Для режима VPN Windows нужны права администратора. Запустите Sonar от имени администратора или выберите системный прокси в настройках.';
    }
    return 'Коснитесь капли ещё раз. Если не помогает, выберите канал «Запасной 443».';
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.smart, required this.onChanged});

  final bool smart;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, String hint, bool value) {
      final on = smart == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: on ? null : () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(.16, 1, .3, 1),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: on ? _paper.withValues(alpha: .1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? _paper.withValues(alpha: .5) : _mist.withValues(alpha: .12)),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 15, color: on ? _paper : _mist, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: _feather),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item('Умный режим', 'игры и РФ напрямую', true),
        const SizedBox(width: 8),
        item('Всё через Sonar', 'кроме российских сайтов', false),
      ],
    );
  }
}

class _ChannelButton extends StatelessWidget {
  const _ChannelButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _mist.withValues(alpha: .12)),
        ),
        child: Row(
          children: [
            const Text('Канал', style: TextStyle(fontSize: 15, color: _feather)),
            const Spacer(),
            Text(enabled ? label : '—', style: const TextStyle(fontSize: 15, color: _paper)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: _feather.withValues(alpha: enabled ? 1 : .4), size: 20),
          ],
        ),
      ),
    );
  }
}
