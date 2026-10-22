import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/sonar/sonar_channel_guard.dart';
import 'package:hiddify/sonar/sonar_channels.dart';
import 'package:hiddify/sonar/sonar_home_view.dart';
import 'package:hiddify/sonar/sonar_key.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:hiddify/sonar/sonar_updater.dart';
import 'package:hiddify/sonar/sonar_windows.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// «Sonar · Основной» → «Основной»; автовыбор Hiddify показывается как «Лучший канал».
String sonarChannelLabel(String tag) {
  final t = tag.trim();
  final lower = t.toLowerCase();
  if (t.isEmpty || ['auto', 'lowest', 'select', 'balance'].any(lower.contains)) {
    return 'Лучший канал';
  }
  return t.replaceFirst(RegExp(r'^Sonar\s*·\s*'), '');
}

/// Главный экран: собирает состояние ядра в данные для SonarHomeView.
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
    final stats = connected ? ref.watch(statsNotifierProvider).valueOrNull : null;

    // С какого момента в сети: для счётчика времени
    final since = useState<DateTime?>(null);
    useEffect(() {
      if (connected && since.value == null) since.value = DateTime.now();
      if (!connected) since.value = null;
      return null;
    }, [connected]);

    // Сразу после «Начать»: подключаемся, как только ядро сообщило, что готово
    void autoConnect(AsyncValue<ConnectionStatus> s) {
      if (!ref.read(sonarConnectOnHomeProvider) || s.valueOrNull is! Disconnected) return;
      ref.read(sonarConnectOnHomeProvider.notifier).state = false;
      ref.read(connectionNotifierProvider.notifier).toggleConnection();
    }

    ref.listen(connectionNotifierProvider, (_, next) => autoConnect(next));
    useEffect(() {
      Future.microtask(() async {
        // перезапустились с правами администратора ради режима VPN: подключаемся сами
        if (await SonarWindows.takeConnectAfterRestart(ref)) ref.read(sonarConnectOnHomeProvider.notifier).state = true;
        autoConnect(ref.read(connectionNotifierProvider));
      });
      return null;
    }, const []);

    final sphere = switch (status) {
      _ when keyStatus is SonarKeyIssuing => SphereState.connecting,
      _ when keyStatus is SonarKeyFailed => SphereState.failed,
      AsyncError() => SphereState.failed,
      AsyncValue(valueOrNull: Disconnected(connectionFailure: _?)) => SphereState.failed,
      AsyncValue(valueOrNull: Connecting()) || AsyncValue(valueOrNull: Disconnecting()) => SphereState.connecting,
      AsyncValue(valueOrNull: Connected()) when delay == 0 => SphereState.connecting,
      AsyncValue(valueOrNull: Connected()) => SphereState.connected,
      // ядро ещё не сообщило состояние: показываем запуск, а не «нажмите»
      AsyncLoading(valueOrNull: null) => SphereState.connecting,
      _ => SphereState.idle,
    };
    final needsAdmin = sphere == SphereState.failed && _needsAdmin(status);

    // Автовыбор Sonar держит один канал; на экране видно, какой именно
    final guard = ref.watch(sonarChannelGuardProvider);
    final picked = sonarChannelLabel(proxy?.groupSelectedTagDisplay ?? '');
    final channel = guard.auto && picked != 'Лучший канал' ? 'Авто · $picked' : picked;
    final title = switch (sphere) {
      _ when keyStatus is SonarKeyIssuing => 'Получаю личный ключ…',
      _ when keyStatus is SonarKeyFailed => 'Ключ не получен',
      SphereState.connected => 'Всё открыто',
      SphereState.connecting when status.valueOrNull == null => 'Запускаю Sonar…',
      SphereState.connecting when status.valueOrNull is Connected => 'Проверяю канал…',
      SphereState.connecting => status.valueOrNull is Disconnecting ? 'Отключаю…' : 'Подключаю…',
      SphereState.failed => 'Не удалось подключиться',
      SphereState.idle => hasProfile ? 'Коснитесь капли' : 'Коснитесь капли, чтобы начать',
    };
    final subtitle = switch (sphere) {
      _ when keyStatus is SonarKeyFailed => keyStatus.message,
      SphereState.connected when ConnectionConst.isValidDelay(delay) =>
        smart ? '$channel · через Sonar только заблокированное' : '$channel · через Sonar всё, кроме РФ',
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

    return SonarHomeView(
      data: SonarHomeData(
        sphere: sphere,
        title: title,
        subtitle: subtitle,
        smart: smart,
        channel: channel,
        ping: ConnectionConst.isValidDelay(delay) ? delay : 0,
        connectedSince: since.value,
        down: stats?.downlink.toInt() ?? 0,
        up: stats?.uplink.toInt() ?? 0,
        downTotal: stats?.downlinkTotal.toInt() ?? 0,
        upTotal: stats?.uplinkTotal.toInt() ?? 0,
        // во время подключения капля не реагирует, а в сети отключает
        tappable: sphere != SphereState.connecting || connected,
        canRetryKey: keyStatus is SonarKeyFailed || needsAdmin,
        retryLabel: needsAdmin ? 'Перезапустить с правами администратора' : 'Попробовать ещё раз',
        channelEnabled: hasProfile,
      ),
      banner: const SonarUpdateBanner(),
      onTap: onTap,
      onRetryKey: needsAdmin ? () => SonarWindows.restartAsAdmin(ref) : onTap,
      onMode: (v) => ref.read(rulesNotifierProvider.notifier).setSonarSmart(v),
      onChannel: () => showSonarChannels(context),
    );
  }

  static String _failureText(AsyncValue<ConnectionStatus> status) => switch (status) {
    AsyncValue(valueOrNull: Disconnected(connectionFailure: final f?)) => f.toString(),
    AsyncError(:final error) => error.toString(),
    _ => '',
  };

  static bool _needsAdmin(AsyncValue<ConnectionStatus> status) {
    final failure = _failureText(status);
    return failure.contains('missingPrivilege') || failure.contains('Access is denied');
  }

  static String _failure(AsyncValue<ConnectionStatus> status) {
    if (_needsAdmin(status)) {
      return 'Для режима VPN Windows нужны права администратора. Sonar перезапустится и попросит их.';
    }
    return 'Коснитесь капли ещё раз. Если не помогает, выберите канал «Игры» или «Запасной».';
  }
}
