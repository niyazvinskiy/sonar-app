import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_style.dart';

enum SphereState { idle, connecting, connected, failed }

/// Живая капля Sonar, как «Моя волна»: дышит в покое, бежит кометой при
/// подключении, посылает цветные импульсы и светится, когда трафик идёт.
/// Нажатие подключает и отключает, капля отвечает всплеском.
class SonarSphere extends HookWidget {
  const SonarSphere({super.key, required this.state, this.mood, this.onTap, this.size = 260, this.semanticLabel});

  final SphereState state;
  final SonarMood? mood;
  final VoidCallback? onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final clock = useAnimationController(duration: const Duration(seconds: 60));
    final splash = useAnimationController(duration: const Duration(milliseconds: 900));
    useEffect(() {
      if (still) {
        clock.value = .3;
      } else {
        clock.repeat();
      }
      return null;
    }, [still]);
    final pressed = useState(false);
    final hover = useState(false);

    void tap() {
      HapticFeedback.mediumImpact();
      splash.forward(from: 0);
      onTap?.call();
    }

    final scale = pressed.value ? .95 : (hover.value && onTap != null ? 1.03 : 1.0);
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
          onTapDown: onTap == null ? null : (_) => pressed.value = true,
          onTapCancel: () => pressed.value = false,
          onTapUp: (_) => pressed.value = false,
          onTap: onTap == null ? null : tap,
          child: AnimatedScale(
            scale: scale,
            duration: Duration(milliseconds: pressed.value ? 120 : 600),
            curve: pressed.value ? Curves.easeOut : const Cubic(.16, 1, .3, 1),
            child: RepaintBoundary(
              child: TweenAnimationBuilder<SonarMood>(
                tween: SonarMoodTween(end: mood ?? SonarMood.of(state)),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeInOutCubic,
                builder: (context, m, _) => CustomPaint(
                  size: Size.square(size),
                  painter: _SpherePainter(Listenable.merge([clock, splash]), clock, splash, state, m),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpherePainter extends CustomPainter {
  _SpherePainter(Listenable repaint, this.clock, this.splash, this.state, this.mood) : super(repaint: repaint);

  final Animation<double> clock;
  final Animation<double> splash;
  final SphereState state;
  final SonarMood mood;

  static const _paper = Color(Sonar.paper);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 60.0; // секунды
    final c = size.center(Offset.zero);
    final s = size.shortestSide;
    final r = s * .2;
    final breath = 1 + .03 * math.sin(t * 2 * math.pi / 4.2);
    final e = mood.energy;
    final p = mood.primary;
    final q = mood.secondary;

    // Ореол цвета настроения
    canvas.drawCircle(
      c,
      r * 2.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.withValues(alpha: .34 * e + .06),
            q.withValues(alpha: .10 * e),
            Colors.transparent,
          ],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2.5)),
    );

    // Импульсы: чаще при подключении, ярче в сети
    final (period, strength) = switch (state) {
      SphereState.connecting => (1.1, .55),
      SphereState.connected => (2.6, .7),
      SphereState.idle => (4.2, .28),
      SphereState.failed => (0.0, 0.0),
    };
    if (period > 0) {
      for (var i = 0; i < 3; i++) {
        final phase = ((t / period) + i / 3) % 1.0;
        final rr = r * (1.1 + 1.45 * Curves.easeOutCubic.transform(phase));
        final a = math.pow(1 - phase, 1.6).toDouble() * strength;
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * (.004 + .004 * (1 - phase))
            ..color = Color.lerp(p, _paper, .35)!.withValues(alpha: a),
        );
      }
    }

    // В сети: частицы на орбите
    if (state == SphereState.connected) {
      for (var i = 0; i < 14; i++) {
        final ang = t * (.18 + (i % 3) * .05) + i * 2 * math.pi / 14;
        final orbit = r * (1.62 + .14 * math.sin(t * .7 + i));
        final o = c + Offset(math.cos(ang), math.sin(ang)) * orbit;
        final a = .35 + .35 * math.sin(t * 1.3 + i * 1.7).abs();
        canvas.drawCircle(o, s * .0055, Paint()..color = Color.lerp(p, _paper, .5)!.withValues(alpha: a));
      }
    }

    // Подключение: комета бежит по кругу
    if (state == SphereState.connecting) {
      final arcRect = Rect.fromCircle(center: c, radius: r * 1.42);
      final start = t * 4.2;
      canvas.drawArc(
        arcRect,
        start,
        math.pi * .9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * .012
          ..shader = SweepGradient(
            endAngle: math.pi * .9,
            colors: [p.withValues(alpha: 0), q.withValues(alpha: .55), _paper.withValues(alpha: .95)],
            stops: const [0, .7, 1],
            transform: GradientRotation(start),
          ).createShader(arcRect),
      );
    }

    // Линия воды под каплей: в сети бежит быстрее
    final speed = state == SphereState.connected ? 1.8 : .55;
    final wave = Path();
    final w = s * .78;
    final x0 = c.dx - w / 2;
    final base = c.dy + r * 2.15;
    for (var i = 0; i <= 90; i++) {
      final k = i / 90;
      final y = base + math.sin(k * math.pi * 2.6 + t * speed) * r * .13 * (1 - (k - .5).abs() * 2);
      i == 0 ? wave.moveTo(x0 + w * k, y) : wave.lineTo(x0 + w * k, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .006
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            p.withValues(alpha: 0),
            Color.lerp(p, _paper, .4)!.withValues(alpha: .55 + .2 * e),
            q.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x0, base - r, w, r * 2)),
    );

    // Свечение под каплей
    canvas.drawCircle(
      c,
      r * 1.32 * breath,
      Paint()
        ..color = p.withValues(alpha: .28 + .32 * e)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .6),
    );

    // Сама капля: перламутр, отлив цвета настроения, тень, блик и ободок
    final rad = r * breath;
    final sphere = Rect.fromCircle(center: c, radius: rad);
    final failed = state == SphereState.failed;
    canvas.drawCircle(
      c,
      rad,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.42),
          colors: [
            Colors.white,
            Color.lerp(Colors.white, q, failed ? .35 : .28)!,
            Color.lerp(p, const Color(Sonar.night1), failed ? .25 : .38)!,
          ],
          stops: const [0, .48, 1],
        ).createShader(sphere),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    // Два цветных блика медленно плавают внутри: перламутр переливается
    for (final (k, color, speed) in [(0, p, .23), (1, q, -.17)]) {
      final a = t * speed + k * math.pi;
      final o = c + Offset(math.cos(a), math.sin(a * 1.3)) * rad * .42;
      canvas.drawCircle(
        o,
        rad * .85,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .55), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: o, radius: rad * .85)),
      );
    }
    final shade = c + Offset(rad * .38, rad * .44);
    canvas.drawCircle(
      shade,
      rad * .9,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(Sonar.night0).withValues(alpha: .32), Colors.transparent],
        ).createShader(Rect.fromCircle(center: shade, radius: rad * .9)),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-rad * .36, -rad * .42), width: rad * .52, height: rad * .34),
      Paint()
        ..color = Colors.white.withValues(alpha: .78)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * .1),
    );
    canvas.drawCircle(
      c,
      rad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .005
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: .55), p.withValues(alpha: .1), q.withValues(alpha: .45)],
        ).createShader(sphere),
    );

    // Всплеск после нажатия
    final v = splash.value;
    if (v > 0 && v < 1) {
      final k = Curves.easeOutCubic.transform(v);
      canvas.drawCircle(
        c,
        r * (1 + 1.6 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .012 * (1 - k)
          ..color = _paper.withValues(alpha: .7 * (1 - k)),
      );
    }
  }

  @override
  bool shouldRepaint(_SpherePainter old) => old.state != state || old.mood != mood;
}
