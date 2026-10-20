import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/sonar/sonar_settings.dart';
import 'package:hiddify/utils/utils.dart';

enum TransitionType { slide, fade }

Page<dynamic> customTransition(TransitionType transition, LocalKey pageKey, Widget page) {
  // Sonar: у всех внутренних экранов один ночной фон с сиянием
  final child = SonarBackdrop(child: page);
  // On iOS, use CupertinoPage so pages get the native interactive (edge-swipe)
  // back gesture. CustomTransitionPage does not support that gesture.
  if (PlatformUtils.isIOS) {
    return CupertinoPage<dynamic>(key: pageKey, child: child);
  }
  // Sonar: страница наплывает чуть сбоку и проявляется, без резкого выезда на весь экран
  return CustomTransitionPage<dynamic>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: switch (transition) {
          TransitionType.slide => SlideTransition(
            position: Tween<Offset>(begin: const Offset(.08, 0), end: Offset.zero).animate(curved),
            textDirection: Directionality.of(context),
            child: child,
          ),
          TransitionType.fade => ScaleTransition(
            scale: Tween<double>(begin: .98, end: 1).animate(curved),
            child: child,
          ),
        },
      );
    },
  );
}
