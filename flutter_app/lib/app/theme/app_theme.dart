import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pagePadding,
    required this.sectionSpacing,
    required this.compactSpacing,
    required this.cardRadius,
    required this.inputRadius,
    required this.composerMinHeight,
    required this.maxContentWidth,
  });

  final EdgeInsets pagePadding;
  final double sectionSpacing;
  final double compactSpacing;
  final double cardRadius;
  final double inputRadius;
  final double composerMinHeight;
  final double maxContentWidth;

  static const fallback = AppThemeTokens(
    pagePadding: EdgeInsets.fromLTRB(16, 16, 16, 20),
    sectionSpacing: 16,
    compactSpacing: 12,
    cardRadius: 8,
    inputRadius: 8,
    composerMinHeight: 132,
    maxContentWidth: 1180,
  );

  @override
  AppThemeTokens copyWith({
    EdgeInsets? pagePadding,
    double? sectionSpacing,
    double? compactSpacing,
    double? cardRadius,
    double? inputRadius,
    double? composerMinHeight,
    double? maxContentWidth,
  }) {
    return AppThemeTokens(
      pagePadding: pagePadding ?? this.pagePadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      compactSpacing: compactSpacing ?? this.compactSpacing,
      cardRadius: cardRadius ?? this.cardRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      composerMinHeight: composerMinHeight ?? this.composerMinHeight,
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      pagePadding:
          EdgeInsets.lerp(pagePadding, other.pagePadding, t) ?? pagePadding,
      sectionSpacing: lerpDouble(sectionSpacing, other.sectionSpacing, t),
      compactSpacing: lerpDouble(compactSpacing, other.compactSpacing, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      inputRadius: lerpDouble(inputRadius, other.inputRadius, t),
      composerMinHeight: lerpDouble(
        composerMinHeight,
        other.composerMinHeight,
        t,
      ),
      maxContentWidth: lerpDouble(maxContentWidth, other.maxContentWidth, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppThemeTokensBuildContext on BuildContext {
  AppThemeTokens get appTokens =>
      Theme.of(this).extension<AppThemeTokens>() ?? AppThemeTokens.fallback;
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E293B), // Elegant slate primary
    brightness: Brightness.light,
  );
  final surfaceTint = colorScheme.surfaceContainerHighest.withValues(
    alpha: 0.3,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8F6F6),
    extensions: const <ThemeExtension<dynamic>>[AppThemeTokens.fallback],
    textTheme: TextTheme(
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      bodyLarge: TextStyle(
        height: 1.5,
        fontSize: 15,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        height: 1.5,
        fontSize: 13,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        height: 1.4,
        fontSize: 11,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.cardRadius),
        side: BorderSide.none,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      height: 72,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      minWidth: 88,
      selectedLabelTextStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceTint,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppThemeTokens.fallback.inputRadius,
        ),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppThemeTokens.fallback.inputRadius,
        ),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppThemeTokens.fallback.inputRadius,
        ),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppThemeTokens.fallback.inputRadius,
        ),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppThemeTokens.fallback.inputRadius,
        ),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      selectedColor: colorScheme.primaryContainer,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.9),
      thickness: 1,
      space: 24,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
    ),
  );
}
