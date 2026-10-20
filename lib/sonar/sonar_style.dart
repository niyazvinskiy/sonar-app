import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_sphere.dart';

/// Цвет и энергия экрана: от них зависят и фон, и капля. Меняются плавно.
@immutable
class SonarMood {
  const SonarMood(this.primary, this.secondary, this.energy);

  final Color primary;
  final Color secondary;

  /// 0 тишина, 1 подключено и всё течёт
  final double energy;

  static const idle = SonarMood(Color(0xFF7C8CFF), Color(0xFF3B4A8F), .38);
  static const connecting = SonarMood(Color(0xFF9AA8FF), Color(0xFFB48CFF), .7);
  static const connected = SonarMood(Color(0xFF5EEAD4), Color(0xFF8B9CFF), 1);
  static const failed = SonarMood(Color(0xFFFF7A90), Color(0xFF7A3358), .5);

  static SonarMood of(SphereState s) => switch (s) {
    SphereState.idle => idle,
    SphereState.connecting => connecting,
    SphereState.connected => connected,
    SphereState.failed => failed,
  };

  factory SonarMood.lerp(SonarMood a, SonarMood b, double t) => SonarMood(
    Color.lerp(a.primary, b.primary, t)!,
    Color.lerp(a.secondary, b.secondary, t)!,
    lerpDouble(a.energy, b.energy, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is SonarMood && other.primary == primary && other.secondary == secondary && other.energy == energy;

  @override
  int get hashCode => Object.hash(primary, secondary, energy);
}

class SonarMoodTween extends Tween<SonarMood> {
  SonarMoodTween({super.begin, super.end});

  @override
  SonarMood lerp(double t) => SonarMood.lerp(begin!, end!, t);
}

abstract class SonarText {
  static const _f = 'Jost';
  static const title = TextStyle(
    fontFamily: _f,
    fontSize: 30,
    fontWeight: FontWeight.w300,
    height: 1.15,
    letterSpacing: -.2,
    color: Color(Sonar.paper),
  );
  static const body = TextStyle(fontFamily: _f, fontSize: 15, height: 1.45, color: Color(Sonar.feather));
  static const label = TextStyle(
    fontFamily: _f,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.6,
    color: Color(Sonar.feather),
  );
  static const value = TextStyle(
    fontFamily: _f,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: Color(Sonar.paper),
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const item = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, color: Color(Sonar.paper));
  static const hint = TextStyle(fontFamily: _f, fontSize: 13, height: 1.35, color: Color(Sonar.feather));
}

/// Стеклянная панель поверх живого фона.
BoxDecoration sonarGlass({double radius = 16, bool active = false, Color? glow}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: active ? .11 : .065),
      Colors.white.withValues(alpha: active ? .05 : .025),
    ],
  ),
  border: Border.all(color: (glow ?? Colors.white).withValues(alpha: active ? .42 : .11)),
  boxShadow: active && glow != null
      ? [BoxShadow(color: glow.withValues(alpha: .18), blurRadius: 24, spreadRadius: -4)]
      : null,
);

/// Пинг цветом: быстрый бирюзовый, средний янтарный, плохой розовый.
Color sonarPingColor(int ms) => ms <= 0
    ? const Color(Sonar.feather)
    : ms < 90
    ? const Color(0xFF5EEAD4)
    : ms < 220
    ? const Color(0xFFFFC979)
    : const Color(0xFFFF7A90);

String sonarSpeed(int bytesPerSecond) {
  if (bytesPerSecond < 1024) return '$bytesPerSecond Б/с';
  if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).round()} КБ/с';
  final mb = bytesPerSecond / 1048576;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0).replaceAll('.', ',')} МБ/с';
}

/// Объём по-русски: «840 КБ», «1,2 ГБ».
String sonarBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  const units = ['КБ', 'МБ', 'ГБ', 'ТБ'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final digits = v < 10 && i > 0 ? 1 : 0;
  return '${v.toStringAsFixed(digits).replaceAll('.', ',')} ${units[i]}';
}

/// Промежуток по-русски: «10 мин», «2 ч».
String sonarDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds} с';
  if (d.inMinutes < 60 || d.inMinutes % 60 != 0) return '${d.inMinutes} мин';
  return '${d.inHours} ч';
}

String sonarElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
