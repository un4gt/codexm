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
    sectionSpacing: 20,
    compactSpacing: 12,
    cardRadius: 24,
    inputRadius: 18,
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
      pagePadding: EdgeInsets.lerp(pagePadding, other.pagePadding, t) ?? pagePadding,
      sectionSpacing: lerpDouble(sectionSpacing, other.sectionSpacing, t),
      compactSpacing: lerpDouble(compactSpacing, other.compactSpacing, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      inputRadius: lerpDouble(inputRadius, other.inputRadius, t),
      composerMinHeight: lerpDouble(composerMinHeight, other.composerMinHeight, t),
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
    seedColor: const Color(0xFFEC5B13),
    brightness: Brightness.light,
  );
  final surfaceTint = colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8F6F6),
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeTokens.fallback,
    ],
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(height: 1.45),
      bodyMedium: TextStyle(height: 1.4),
      bodySmall: TextStyle(height: 1.35),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.cardRadius),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.9)),
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
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      height: 72,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceTint,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.inputRadius),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.inputRadius),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.inputRadius),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      selectedColor: colorScheme.primaryContainer,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
