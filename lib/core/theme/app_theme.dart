import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);

  // флаги и эмодзи на Windows рисует свой шрифт, остальное Jost
  static final _fallback = !kIsWeb && Platform.isWindows ? const ['Emoji'] : null;
  final AppThemeMode mode;
  final String fontFamily;

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final ColorScheme scheme = lightColorScheme ?? ColorScheme.fromSeed(seedColor: const Color(0xFF293CA0));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: _fallback,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    // Sonar: свои цвета вместо системных, как на сайте
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8FA1C9),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0E1630),
      surfaceContainerLowest: const Color(0xFF070B16),
      surfaceContainerLow: const Color(0xFF0E1630),
      surfaceContainer: const Color(0xFF131C38),
      surfaceContainerHigh: const Color(0xFF1A2442),
      surfaceContainerHighest: const Color(0xFF1E2D4A),
      primary: const Color(0xFFDDE2E8),
      onPrimary: const Color(0xFF070B16),
      primaryContainer: const Color(0xFF1E2D4A),
      onPrimaryContainer: const Color(0xFFF6F7F9),
      secondaryContainer: const Color(0xFF1E2D4A),
      onSecondaryContainer: const Color(0xFFDDE2E8),
      onSurface: const Color(0xFFF6F7F9),
      onSurfaceVariant: const Color(0xFFAEB6C2),
      outline: const Color(0x47DDE2E8),
      outlineVariant: const Color(0x1FDDE2E8),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : const Color(0xFF070B16),
      fontFamily: fontFamily,
      fontFamilyFallback: _fallback,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
