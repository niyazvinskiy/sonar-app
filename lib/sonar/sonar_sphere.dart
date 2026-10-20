import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/sonar/sonar.dart';

enum SphereState { idle, connecting, connected, failed }

/// Живая сфера Sonar, как «Моя волна»: дышит, пока ждёт, и посылает импульсы,
/// когда подключается и работает. Нажатие на неё подключает и отключает.
class SonarSphere extends HookWidget {
  const SonarSphere({super.key, required this.state, this.onTap, this.size = 260, this.semanticLabel});

  final SphereState state;
  final VoidCallback? onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final clock = useAnimationController(duration: const Duration(seconds: 24));
    useEffect(() {
      if (still) {
        clock.value = .3;
      } else {
        clock.repeat();
      }
      return null;
    }, [still]);
    final hover = useState(false);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticLabel,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => hover.value = true,
        onExit: (_) => hover.value = false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedScale(
            scale: hover.value && onTap != null ? 1.03 : 1,
            duration: const Duration(milliseconds: 500),
            curve: const Cubic(.16, 1, .3, 1),
            child: RepaintBoundary(
              child: CustomPaint(size: Size.square(size), painter: _SpherePainter(clock, state)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpherePainter extends CustomPainter {
  _SpherePainter(this.clock, this.state) : super(repaint: clock);

  final Animation<double> clock;
  final SphereState state;

  static const _paper = Color(Sonar.paper);
  static const _feather = Color(Sonar.feather);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 24.0; // секунды
    final c = size.center(Offset.zero);
    final r = size.shortestSide * .19;
    final breath = 1 + .028 * math.sin(t * 2 * math.pi / 4.5);

    // Импульсы: чаще, когда подключается, ярче, когда подключено
    final (period, strength) = switch (state) {
      SphereState.connecting => (1.15, .5),
      SphereState.connected => (2.4, .6),
      SphereState.idle => (3.8, .22),
      SphereState.failed => (0.0, 0.0),
    };
    if (period > 0) {
      const rings = 3;
      for (var i = 0; i < rings; i++) {
        final phase = ((t / period) + i / rings) % 1.0;
        final radius = r * (1.08 + 1.55 * Curves.easeOutCubic.transform(phase));
        final alpha = math.pow(1 - phase, 1.7).toDouble() * strength;
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.shortestSide * .005
            ..color = _paper.withValues(alpha: alpha),
        );
      }
    }

    // Линия воды под сферой: движется быстрее, когда трафик идёт
    final speed = state == SphereState.connected ? 1.6 : .5;
    final wave = Path();
    final w = size.width * .74;
    final x0 = c.dx - w / 2;
    final base = c.dy + r * 2.05;
    for (var i = 0; i <= 80; i++) {
      final k = i / 80;
      final y = base + math.sin(k * math.pi * 2.4 + t * speed) * r * .12 * (1 - (k - .5).abs() * 2);
      i == 0 ? wave.moveTo(x0 + w * k, y) : wave.lineTo(x0 + w * k, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .006
        ..strokeCap = StrokeCap.round
        ..color = _feather.withValues(alpha: state == SphereState.failed ? .2 : .45),
    );

    // Свечение и сама сфера
    final failed = state == SphereState.failed;
    final glowAlpha = switch (state) {
      SphereState.connected => .55,
      SphereState.connecting => .35 + .2 * math.sin(t * 2 * math.pi / 1.15).abs(),
      SphereState.idle => .25,
      SphereState.failed => .18,
    };
    canvas.drawCircle(
      c,
      r * 1.35 * breath,
      Paint()
        ..color = (failed ? const Color(0xFFE8A0A0) : const Color(0xFFC9D3EA)).withValues(alpha: glowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .55),
    );
    final sphere = Rect.fromCircle(center: c, radius: r * breath);
    canvas.drawCircle(
      c,
      r * breath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.34, -.42),
          radius: .95,
          colors: failed
              ? const [Color(0xFFFFF1F1), Color(0xFFE9C4C8), Color(0xFFB98A93)]
              : state == SphereState.idle
              ? const [Color(0xFFF2F4F8), Color(0xFFB9C3D9), Color(0xFF7D8DB0)]
              : const [Color(0xFFFFFFFF), Color(0xFFC9D3EA), Color(0xFF8FA1C9)],
          stops: const [0, .45, 1],
        ).createShader(sphere),
    );
  }

  @override
  bool shouldRepaint(_SpherePainter old) => old.state != state;
}
