import 'dart:async';
import 'dart:math' as math;

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
    final media = MediaQuery.sizeOf(context);
    return SonarAurora(
      mood: mood,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // В низком окне капля уступает место тексту и кнопкам: всё, кроме неё,
            // занимает около 240 точек, а в сети с цифрами и строкой сервера ещё 125
            final rest = data.connected ? 370.0 : 245.0;
            final sphereSize = math.min(
              (media.shortestSide * .82).clamp(230.0, 340.0),
              math.max(140.0, box.maxHeight - rest),
            );
            // при подключении появляются цифры, и капля плавно, а не скачком, становится меньше
            return TweenAnimationBuilder<double>(
              tween: Tween(end: sphereSize),
              duration: const Duration(milliseconds: 500),
              curve: const Cubic(.16, 1, .3, 1),
              builder: (_, size, _) => _layout(size, mood),
            );
          },
        ),
      ),
    );
  }

  Widget _layout(double sphereSize, SonarMood mood) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            banner ?? const SizedBox(height: 12),
            const Spacer(flex: 2),
            SonarSphere(
              state: data.sphere,
              mood: mood,
              onTap: data.tappable ? onTap : null,
              size: sphereSize,
              semanticLabel: data.connected ? 'Отключить Sonar' : 'Подключить Sonar',
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: Text(data.title, key: ValueKey(data.title), textAlign: TextAlign.center, style: SonarText.title),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(
                  data.subtitle,
                  key: ValueKey(data.subtitle),
                  textAlign: TextAlign.center,
                  style: SonarText.body,
                ),
              ),
            ),
            if (data.canRetryKey)
              TextButton(
                onPressed: onRetryKey,
                child: const Text('Попробовать ещё раз', style: TextStyle(fontFamily: 'Jost', fontSize: 15)),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 500),
              curve: const Cubic(.16, 1, .3, 1),
              child: data.connected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        children: [
                          _Stats(data: data),
                          const SizedBox(height: 10),
                          _Route(data: data),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const Spacer(flex: 3),
            SonarModeSwitch(smart: data.smart, onChanged: onMode),
            const SizedBox(height: 10),
            _ChannelRow(data: data, onTap: data.channelEnabled ? onChannel : null),
            const SizedBox(height: 18),
          ],
        ),
      ),
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});

  final SonarHomeData data;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, Widget value) => Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: sonarGlass(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: SonarText.label),
            const SizedBox(height: 5),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
            ),
          ],
        ),
      ),
    );
    Widget speed(IconData icon, int v, {bool small = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: small ? 12 : 15, color: small ? const Color(Sonar.feather) : const Color(Sonar.paper)),
        const SizedBox(width: 3),
        Text(sonarSpeed(v), style: small ? SonarText.hint.copyWith(fontSize: 12, height: 1.2) : SonarText.value),
      ],
    );
    return Row(
      children: [
        chip('В СЕТИ', _Elapsed(since: data.connectedSince)),
        const SizedBox(width: 8),
        chip(
          'ПИНГ',
          Text(
            data.ping > 0 ? '${data.ping} мс' : '—',
            style: SonarText.value.copyWith(color: sonarPingColor(data.ping)),
          ),
        ),
        const SizedBox(width: 8),
        chip(
          'СКОРОСТЬ',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [speed(Icons.south_rounded, data.down), speed(Icons.north_rounded, data.up, small: true)],
          ),
        ),
      ],
    );
  }
}

/// Строка под цифрами: где сервер и сколько уже прошло за подключение.
class _Route extends StatelessWidget {
  const _Route({required this.data});

  final SonarHomeData data;

  @override
  Widget build(BuildContext context) {
    final style = SonarText.hint.copyWith(fontSize: 12.5, fontFeatures: const [FontFeature.tabularFigures()]);
    final dim = const Color(Sonar.feather).withValues(alpha: .75);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 14, color: dim),
            const SizedBox(width: 4),
            Text('Сервер: ${Sonar.serverCity}', style: style),
          ],
        ),
        Text('·', style: style.copyWith(color: dim)),
        // стрелок в Jost нет, поэтому значки
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('за сеанс ', style: style),
            Icon(Icons.south_rounded, size: 12, color: dim),
            Text(sonarBytes(data.downTotal), style: style),
            const SizedBox(width: 6),
            Icon(Icons.north_rounded, size: 12, color: dim),
            Text(sonarBytes(data.upTotal), style: style),
          ],
        ),
      ],
    );
  }
}

/// Время в сети, тикает раз в секунду.
class _Elapsed extends HookWidget {
  const _Elapsed({required this.since});

  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
      return timer.cancel;
    }, const []);
    final d = since == null ? Duration.zero : DateTime.now().difference(since!);
    return Text(sonarElapsed(d), style: SonarText.value);
  }
}

/// Умный режим или «Всё через Sonar»: стеклянный переключатель со скользящей плашкой.
class SonarModeSwitch extends StatelessWidget {
  const SonarModeSwitch({super.key, required this.smart, this.onChanged});

  final bool smart;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget half(bool value, String title, String hint) {
      final on = smart == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: on || onChanged == null ? null : () => onChanged!(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
              child: Column(
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: SonarText.item.copyWith(
                      fontSize: 15,
                      color: on ? const Color(Sonar.paper) : const Color(Sonar.feather),
                    ),
                    child: Text(title),
                  ),
                  const SizedBox(height: 2),
                  Text(hint, textAlign: TextAlign.center, style: SonarText.hint.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: sonarGlass(),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: smart ? Alignment.centerLeft : Alignment.centerRight,
              duration: const Duration(milliseconds: 450),
              curve: const Cubic(.16, 1, .3, 1),
              child: FractionallySizedBox(
                widthFactor: .5,
                heightFactor: 1,
                child: DecoratedBox(decoration: sonarGlass(radius: 12, active: true, glow: const Color(0xFF8B9CFF))),
              ),
            ),
          ),
          Row(
            children: [
              half(true, 'Умный режим', 'игры и РФ напрямую'),
              half(false, 'Всё через Sonar', 'кроме российских сайтов'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.data, this.onTap});

  final SonarHomeData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: sonarGlass(),
          child: Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 20, color: const Color(Sonar.feather).withValues(alpha: .9)),
              const SizedBox(width: 12),
              const Text('КАНАЛ', style: SonarText.label),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enabled ? data.channel : '—',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: SonarText.item.copyWith(fontSize: 15),
                ),
              ),
              if (data.connected && data.ping > 0) ...[const SizedBox(width: 10), _PingDot(ms: data.ping)],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: const Color(Sonar.feather).withValues(alpha: enabled ? 1 : .35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PingDot extends StatelessWidget {
  const _PingDot({required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final color = sonarPingColor(ms);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: .6), blurRadius: 8)],
      ),
    );
  }
}
