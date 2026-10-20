import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_style.dart';

/// Живой фон: ночная вода и медленное северное сияние цвета настроения.
/// Когда Sonar подключён, облака ярче и плывут быстрее.
class SonarAurora extends HookWidget {
  const SonarAurora({super.key, required this.mood, this.child, this.calm = false});

  final SonarMood mood;
  final Widget? child;

  /// Без движения: для экранов, где фон только настроение, а не жизнь соединения
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final still = calm || MediaQuery.of(context).disableAnimations;
    final clock = useAnimationController(duration: const Duration(minutes: 2));
    useEffect(() {
      if (still) {
        clock.value = .2;
      } else {
        clock.repeat();
      }
      return null;
    }, [still]);

    return TweenAnimationBuilder<SonarMood>(
      tween: SonarMoodTween(end: mood),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOutCubic,
      builder: (context, m, child) => CustomPaint(painter: _AuroraPainter(clock, m), child: child),
      child: child,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.clock, this.mood) : super(repaint: clock);

  final Animation<double> clock;
  final SonarMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(Sonar.night1), Color(Sonar.night0)],
        ).createShader(rect),
    );

    final t = clock.value * 120 * (.55 + .45 * mood.energy); // секунды, быстрее при энергии
    final big = size.longestSide;
    void blob(Offset c, double r, Color color, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * .35),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .45, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final e = mood.energy;
    blob(
      Offset(size.width * (.28 + .14 * math.sin(t / 9)), size.height * (.26 + .08 * math.cos(t / 11))),
      big * .62,
      mood.primary,
      .10 + .20 * e,
    );
    blob(
      Offset(size.width * (.78 + .12 * math.cos(t / 13)), size.height * (.52 + .12 * math.sin(t / 10))),
      big * .58,
      mood.secondary,
      .10 + .16 * e,
    );
    blob(
      Offset(size.width * (.45 + .18 * math.sin(t / 17 + 2)), size.height * (1.02 + .04 * math.cos(t / 7))),
      big * .7,
      Color.lerp(mood.primary, const Color(Sonar.night2), .55)!,
      .18 + .12 * e,
    );

    // Края темнее: взгляд держится на капле
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.05,
          colors: [Colors.transparent, const Color(Sonar.night0).withValues(alpha: .55)],
          stops: const [.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.mood != mood;
}
