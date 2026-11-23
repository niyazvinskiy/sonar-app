import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_aurora.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';
import 'package:hiddify/sonar/sonar_style.dart';

/// Всё, что показывает главный экран. Собирается из состояния ядра в SonarHome,
/// а в тестах подставляется руками, чтобы рисовать экран без ядра.
@immutable
class SonarHomeData {
  const SonarHomeData({
    required this.sphere,
    required this.title,
    required this.subtitle,
    this.smart = true,
    this.channel = 'Лучший канал',
    this.ping = 0,
    this.connectedSince,
    this.down = 0,
    this.up = 0,
    this.downTotal = 0,
    this.upTotal = 0,
    this.tappable = true,
    this.canRetryKey = false,
    this.retryLabel = 'Попробовать ещё раз',
    this.channelEnabled = true,
  });

  final SphereState sphere;
  final String title;
  final String subtitle;
  final bool smart;
  final String channel;
  final int ping;
  final DateTime? connectedSince;
  final int down;
  final int up;

  /// Сколько прошло за это подключение
  final int downTotal;
  final int upTotal;
  final bool tappable;
  final bool canRetryKey;
  final String retryLabel;
  final bool channelEnabled;

  bool get connected => sphere == SphereState.connected;
}

class SonarHomeView extends StatelessWidget {
  const SonarHomeView({
    super.key,
    required this.data,
    this.banner,
    this.onTap,
    this.onMode,
    this.onChannel,
    this.onRetryKey,
  });

  final SonarHomeData data;
  final Widget? banner;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onMode;
  final VoidCallback? onChannel;
  final VoidCallback? onRetryKey;

  @override
  Widget build(BuildContext context) {
    final mood = SonarMood.of(data.sphere);
    return SonarAurora(
      mood: mood,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final compact = !wide && constraints.maxHeight < 700;
            final connection = _ConnectionStage(
              data: data,
              mood: mood,
              compact: compact,
              wide: wide,
              onTap: onTap,
              onRetryKey: onRetryKey,
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Маршрут', style: SonarText.item),
                const SizedBox(height: 12),
                SonarModeSwitch(smart: data.smart, onChanged: onMode),
                const SizedBox(height: 12),
                _ChannelRow(data: data, onTap: data.channelEnabled ? onChannel : null),
                const SizedBox(height: 28),
                _Session(data: data),
              ],
            );
            return SingleChildScrollView(
              key: const ValueKey('sonar-home-scroll'),
              padding: EdgeInsets.fromLTRB(wide ? 40 : 24, 64, wide ? 40 : 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (banner != null) ...[banner!, const SizedBox(height: 12)],
                      if (wide)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: connection),
                              const SizedBox(width: 40),
                              SizedBox(width: 340, child: details),
                            ],
                          ),
                        )
                      else ...[
                        connection,
                        const SizedBox(height: 28),
                        details,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionStage extends StatelessWidget {
  const _ConnectionStage({
    required this.data,
    required this.mood,
    required this.compact,
    required this.wide,
    this.onTap,
    this.onRetryKey,
  });

  final SonarHomeData data;
  final SonarMood mood;
  final bool compact;
  final bool wide;
  final VoidCallback? onTap;
  final VoidCallback? onRetryKey;

  @override
  Widget build(BuildContext context) {
    final action = switch (data.sphere) {
      SphereState.connected => 'Отключить',
      SphereState.connecting => data.tappable ? 'Остановить' : 'Подключение…',
      SphereState.failed => 'Подключить снова',
      SphereState.idle => 'Подключить',
    };
    final available = data.tappable ? onTap : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            data.title,
            textAlign: TextAlign.center,
            style: SonarText.title.copyWith(fontSize: wide ? 34 : 28),
          ),
        ),
        if (data.subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(data.subtitle, textAlign: TextAlign.center, style: SonarText.body),
        ],
        Center(
          child: ExcludeSemantics(
            child: SonarSphere(
              state: data.sphere,
              mood: mood,
              onTap: available,
              size: wide
                  ? 310
                  : compact
                  ? 160
                  : 220,
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 190, maxWidth: 320),
            child: FilledButton.icon(
              onPressed: available,
              style: FilledButton.styleFrom(
                foregroundColor: const Color(Sonar.night0),
                backgroundColor: const Color(Sonar.paper),
                disabledBackgroundColor: const Color(0xFF26344B),
                disabledForegroundColor: const Color(Sonar.mist),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: SonarText.item,
              ),
              icon: const Icon(Icons.power_settings_new_rounded, size: 20),
              label: Text(action, textAlign: TextAlign.center),
            ),
          ),
        ),
        if (data.canRetryKey) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetryKey,
            child: Text(data.retryLabel, textAlign: TextAlign.center),
          ),
        ],
      ],
    );
  }
}

class _Session extends StatelessWidget {
  const _Session({required this.data});
  final SonarHomeData data;

  @override
  Widget build(BuildContext context) {
    Widget measurement(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: SonarText.body)),
          const SizedBox(width: 12),
          Flexible(child: value),
        ],
      ),
    );
    Widget value(String text) => Text(text, textAlign: TextAlign.end, style: SonarText.value);
    final connected = data.connected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Текущий сеанс', style: SonarText.item)),
            if (connected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 6, color: Color(Sonar.mist)),
              const SizedBox(width: 6),
              const Text('В сети', style: SonarText.hint),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFF314054)),
        measurement('Время в сети', connected ? _Elapsed(since: data.connectedSince) : value('—')),
        measurement('Задержка', value(connected && data.ping > 0 ? '${data.ping} мс' : '—')),
        measurement('Загрузка', value(connected ? sonarSpeed(data.down) : '—')),
        measurement('Отдача', value(connected ? sonarSpeed(data.up) : '—')),
        const Divider(height: 1, color: Color(0xFF314054)),
        const SizedBox(height: 10),
        Text(
          connected
              ? 'За сеанс: получено ${sonarBytes(data.downTotal)}, отправлено ${sonarBytes(data.upTotal)}'
              : 'Показатели появятся после подключения.',
          style: SonarText.hint,
        ),
      ],
    );
  }
}

class _Elapsed extends HookWidget {
  const _Elapsed({required this.since});
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    useEffect(() {
      if (since == null) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
      return timer.cancel;
    }, [since]);
    final elapsed = since == null ? null : DateTime.now().difference(since!);
    return Text(elapsed == null ? '—' : sonarElapsed(elapsed), style: SonarText.value);
  }
}

class SonarModeSwitch extends StatelessWidget {
  const SonarModeSwitch({super.key, required this.smart, this.onChanged});
  final bool smart;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, String title) {
      final selected = smart == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          child: TextButton(
            onPressed: onChanged == null || selected ? null : () => onChanged!(value),
            style: TextButton.styleFrom(
              foregroundColor: selected ? const Color(Sonar.night0) : const Color(Sonar.mist),
              disabledForegroundColor: selected ? const Color(Sonar.night0) : const Color(Sonar.feather),
              backgroundColor: selected ? const Color(Sonar.paper) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              textStyle: SonarText.item.copyWith(fontSize: 14),
            ),
            child: Text(title, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: sonarGlass(radius: 13),
          child: Row(
            children: [option(true, 'Умный режим'), const SizedBox(width: 4), option(false, 'Всё через Sonar')],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          smart
              ? 'Через Sonar — заблокированные сервисы. Игры и российские сайты — напрямую.'
              : 'Весь трафик через Sonar. Российские сайты — напрямую.',
          style: SonarText.hint,
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.data, this.onTap});
  final SonarHomeData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF101B2B),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, size: 20, color: Color(Sonar.mist)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Канал', style: SonarText.hint),
                  const SizedBox(height: 2),
                  Text(data.channelEnabled ? data.channel : 'Появится после получения ключа', style: SonarText.item),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(Sonar.feather)),
            ],
          ],
        ),
      ),
    ),
  );
}
