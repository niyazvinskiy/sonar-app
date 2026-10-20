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
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : _night0,
      fontFamily: fontFamily,
      fontFamilyFallback: _fallback,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
      // Sonar: все экраны Hiddify в одном стиле с главным, а не стандартный Material
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: mode.trueBlack ? Colors.black : _night0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: _paper,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w400, color: _paper),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _feather,
        textColor: _paper,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: _paper),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, height: 1.35, color: _feather),
        leadingAndTrailingTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: _feather),
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        minVerticalPadding: 10,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _night0 : _feather),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _aqua : _night2.withValues(alpha: .6),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : _feather.withValues(alpha: .35),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _aqua : null),
        checkColor: const WidgetStatePropertyAll(_night0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _aqua : _feather),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _aqua,
        thumbColor: _aqua,
        inactiveTrackColor: _night2,
        valueIndicatorColor: _night2,
        valueIndicatorTextStyle: TextStyle(fontFamily: fontFamily, color: _paper),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _aqua, linearTrackColor: _night2),
      dividerTheme: DividerThemeData(color: _mist.withValues(alpha: .08), space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: _night1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _mist.withValues(alpha: .12)),
        ),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w400, color: _paper),
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, height: 1.45, color: _feather),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _night1,
        modalBackgroundColor: _night1,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: _feather.withValues(alpha: .4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: _mist.withValues(alpha: .1)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _night2,
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: _paper),
        actionTextColor: _aqua,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _night1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _mist.withValues(alpha: .12)),
        ),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, color: _paper),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(_night1),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _mist.withValues(alpha: .12)),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: _night2, borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 12, color: _paper),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mist.withValues(alpha: .14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mist.withValues(alpha: .14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _aqua, width: 1.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _aqua,
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _aqua,
          foregroundColor: _night0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _aqua,
        foregroundColor: _night0,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: .045),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _mist.withValues(alpha: .1)),
        ),
      ),
    );
  }

  static const _night0 = Color(0xFF070B16);
  static const _night1 = Color(0xFF0E1630);
  static const _night2 = Color(0xFF1E2D4A);
  static const _mist = Color(0xFFDDE2E8);
  static const _feather = Color(0xFFAEB6C2);
  static const _paper = Color(0xFFF6F7F9);
  static const _aqua = Color(0xFF5EEAD4);

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
