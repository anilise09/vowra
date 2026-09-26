import 'package:flutter/material.dart';

abstract final class VawraColors {
  static const coral = Color(0xFFF24F78);
  static const coralDark = Color(0xFFD93663);
  static const plum = Color(0xFF5A274F);
  static const ink = Color(0xFF21161E);
  static const muted = Color(0xFF756A72);
  static const blush = Color(0xFFFFF3F7);
  static const canvas = Color(0xFFFFFAFC);
  static const lavender = Color(0xFFF1ECFF);
  static const superLike = Color(0xFF4C6FFF);
}

abstract final class VawraTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: VawraColors.coral,
          brightness: Brightness.light,
        ).copyWith(
          primary: VawraColors.coral,
          onPrimary: Colors.white,
          secondary: VawraColors.plum,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: VawraColors.ink,
          surfaceContainerHighest: VawraColors.blush,
          outline: const Color(0xFFE2D7DE),
          outlineVariant: const Color(0xFFF0E6EB),
        );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: VawraColors.canvas,
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          color: VawraColors.ink,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: -1.2,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: VawraColors.ink,
          fontWeight: FontWeight.w800,
          height: 1.08,
          letterSpacing: -0.8,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: VawraColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: VawraColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: VawraColors.ink,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: VawraColors.ink,
          height: 1.42,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: VawraColors.muted,
          height: 1.4,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: VawraColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: VawraColors.plum,
          side: const BorderSide(color: Color(0xFFE4D6DF)),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: VawraColors.blush,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          color: VawraColors.plum,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: const Color(0xFF182465),
        indicatorColor: VawraColors.coral,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFFC8CCE8),
            size: 25,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE9DFE5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE9DFE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: VawraColors.coral, width: 2),
        ),
      ),
    );
  }
}
