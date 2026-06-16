import 'package:flutter/material.dart';

import '../../features/settings/application/codex_settings_store.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pagePadding,
    required this.sectionSpacing,
    required this.compactSpacing,
    required this.spacingSmall,
    required this.spacingMedium,
    required this.spacingLarge,
    required this.cardRadius,
    required this.inputRadius,
    required this.elevationLow,
    required this.elevationMedium,
    required this.elevationHigh,
    required this.composerMinHeight,
    required this.maxContentWidth,
    required this.chatHorizontalGutterFactor,
    required this.chatMessageWidthFactor,
    required this.codePadding,
    required this.codeBackground,
    required this.lightCodeThemePreference,
    required this.darkCodeThemePreference,
  });

  final EdgeInsets pagePadding;
  final double sectionSpacing;
  final double compactSpacing;
  final double spacingSmall;
  final double spacingMedium;
  final double spacingLarge;
  final double cardRadius;
  final double inputRadius;
  final double elevationLow;
  final double elevationMedium;
  final double elevationHigh;
  final double composerMinHeight;
  final double maxContentWidth;
  final double chatHorizontalGutterFactor;
  final double chatMessageWidthFactor;
  final EdgeInsets codePadding;
  final Color codeBackground;
  final String lightCodeThemePreference;
  final String darkCodeThemePreference;

  static const fallback = AppThemeTokens(
    pagePadding: EdgeInsets.fromLTRB(16, 16, 16, 20),
    sectionSpacing: 16,
    compactSpacing: 12,
    spacingSmall: 12,
    spacingMedium: 16,
    spacingLarge: 20,
    cardRadius: 16,
    inputRadius: 16,
    elevationLow: 2,
    elevationMedium: 4,
    elevationHigh: 6,
    composerMinHeight: 132,
    maxContentWidth: 1180,
    chatHorizontalGutterFactor: 0.04,
    chatMessageWidthFactor: 0.92,
    codePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    codeBackground: Color(0xFFF3F4F6),
    lightCodeThemePreference: CodexLightCodeThemePreference.vscodeLight,
    darkCodeThemePreference: CodexDarkCodeThemePreference.vscodeDarkPlus,
  );

  @override
  AppThemeTokens copyWith({
    EdgeInsets? pagePadding,
    double? sectionSpacing,
    double? compactSpacing,
    double? spacingSmall,
    double? spacingMedium,
    double? spacingLarge,
    double? cardRadius,
    double? inputRadius,
    double? elevationLow,
    double? elevationMedium,
    double? elevationHigh,
    double? composerMinHeight,
    double? maxContentWidth,
    double? chatHorizontalGutterFactor,
    double? chatMessageWidthFactor,
    EdgeInsets? codePadding,
    Color? codeBackground,
    String? lightCodeThemePreference,
    String? darkCodeThemePreference,
  }) {
    return AppThemeTokens(
      pagePadding: pagePadding ?? this.pagePadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      compactSpacing: compactSpacing ?? this.compactSpacing,
      spacingSmall: spacingSmall ?? this.spacingSmall,
      spacingMedium: spacingMedium ?? this.spacingMedium,
      spacingLarge: spacingLarge ?? this.spacingLarge,
      cardRadius: cardRadius ?? this.cardRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      elevationLow: elevationLow ?? this.elevationLow,
      elevationMedium: elevationMedium ?? this.elevationMedium,
      elevationHigh: elevationHigh ?? this.elevationHigh,
      composerMinHeight: composerMinHeight ?? this.composerMinHeight,
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
      chatHorizontalGutterFactor:
          chatHorizontalGutterFactor ?? this.chatHorizontalGutterFactor,
      chatMessageWidthFactor:
          chatMessageWidthFactor ?? this.chatMessageWidthFactor,
      codePadding: codePadding ?? this.codePadding,
      codeBackground: codeBackground ?? this.codeBackground,
      lightCodeThemePreference: CodexLightCodeThemePreference.normalize(
        lightCodeThemePreference ?? this.lightCodeThemePreference,
      ),
      darkCodeThemePreference: CodexDarkCodeThemePreference.normalize(
        darkCodeThemePreference ?? this.darkCodeThemePreference,
      ),
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
      sectionSpacing: _lerpDouble(sectionSpacing, other.sectionSpacing, t),
      compactSpacing: _lerpDouble(compactSpacing, other.compactSpacing, t),
      spacingSmall: _lerpDouble(spacingSmall, other.spacingSmall, t),
      spacingMedium: _lerpDouble(spacingMedium, other.spacingMedium, t),
      spacingLarge: _lerpDouble(spacingLarge, other.spacingLarge, t),
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      inputRadius: _lerpDouble(inputRadius, other.inputRadius, t),
      elevationLow: _lerpDouble(elevationLow, other.elevationLow, t),
      elevationMedium: _lerpDouble(elevationMedium, other.elevationMedium, t),
      elevationHigh: _lerpDouble(elevationHigh, other.elevationHigh, t),
      composerMinHeight: _lerpDouble(
        composerMinHeight,
        other.composerMinHeight,
        t,
      ),
      maxContentWidth: _lerpDouble(maxContentWidth, other.maxContentWidth, t),
      chatHorizontalGutterFactor: _lerpDouble(
        chatHorizontalGutterFactor,
        other.chatHorizontalGutterFactor,
        t,
      ),
      chatMessageWidthFactor: _lerpDouble(
        chatMessageWidthFactor,
        other.chatMessageWidthFactor,
        t,
      ),
      codePadding:
          EdgeInsets.lerp(codePadding, other.codePadding, t) ?? codePadding,
      codeBackground:
          Color.lerp(codeBackground, other.codeBackground, t) ?? codeBackground,
      lightCodeThemePreference: t < 0.5
          ? lightCodeThemePreference
          : other.lightCodeThemePreference,
      darkCodeThemePreference: t < 0.5
          ? darkCodeThemePreference
          : other.darkCodeThemePreference,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppThemeTokensBuildContext on BuildContext {
  AppThemeTokens get appTokens =>
      Theme.of(this).extension<AppThemeTokens>() ?? AppThemeTokens.fallback;
}

class CodexMThemePalette {
  const CodexMThemePalette._();

  static const lightBackground = Color(0xFFF7F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF4F46E5);
  static const lightSecondary = Color(0xFF06B6D4);
  static const lightTextPrimary = Color(0xFF111827);
  static const lightCodeBackground = Color(0xFFF3F4F6);

  static const darkBackground = Color(0xFF0B0F19);
  static const darkSurface = Color(0xFF111827);
  static const darkPrimary = Color(0xFF6366F1);
  static const darkSecondary = Color(0xFF22D3EE);
  static const darkTextPrimary = Color(0xFFE5E7EB);
  static const darkCodeBackground = Color(0xFF0F172A);
}

ThemeMode codexThemeModeFromPreference(String? preference) {
  return switch (preference) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  ColorScheme? dynamicColorScheme,
  Color? accentColor,
  String? lightCodeThemePreference,
  String? darkCodeThemePreference,
}) {
  final fixed = _fixedColorScheme(brightness);
  final colorScheme =
      dynamicColorScheme ??
      (accentColor == null
          ? fixed
          : ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: brightness,
            ).copyWith(
              surface: fixed.surface,
              onSurface: fixed.onSurface,
              surfaceContainerLowest: fixed.surfaceContainerLowest,
              surfaceContainerLow: fixed.surfaceContainerLow,
              surfaceContainer: fixed.surfaceContainer,
              surfaceContainerHigh: fixed.surfaceContainerHigh,
              surfaceContainerHighest: fixed.surfaceContainerHighest,
              outline: fixed.outline,
              outlineVariant: fixed.outlineVariant,
            ));
  return _buildAppThemeFromScheme(
    colorScheme: colorScheme,
    brightness: brightness,
    lightCodeThemePreference: lightCodeThemePreference,
    darkCodeThemePreference: darkCodeThemePreference,
  );
}

ThemeData buildLightAppTheme({
  ColorScheme? dynamicColorScheme,
  Color? accentColor,
  String? lightCodeThemePreference,
  String? darkCodeThemePreference,
}) {
  return buildAppTheme(
    brightness: Brightness.light,
    dynamicColorScheme: dynamicColorScheme,
    accentColor: accentColor,
    lightCodeThemePreference: lightCodeThemePreference,
    darkCodeThemePreference: darkCodeThemePreference,
  );
}

ThemeData buildDarkAppTheme({
  ColorScheme? dynamicColorScheme,
  Color? accentColor,
  String? lightCodeThemePreference,
  String? darkCodeThemePreference,
}) {
  return buildAppTheme(
    brightness: Brightness.dark,
    dynamicColorScheme: dynamicColorScheme,
    accentColor: accentColor,
    lightCodeThemePreference: lightCodeThemePreference,
    darkCodeThemePreference: darkCodeThemePreference,
  );
}

ColorScheme _fixedColorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final surface = isDark
      ? CodexMThemePalette.darkSurface
      : CodexMThemePalette.lightSurface;
  final primary = isDark
      ? CodexMThemePalette.darkPrimary
      : CodexMThemePalette.lightPrimary;
  final secondary = isDark
      ? CodexMThemePalette.darkSecondary
      : CodexMThemePalette.lightSecondary;
  final onSurface = isDark
      ? CodexMThemePalette.darkTextPrimary
      : CodexMThemePalette.lightTextPrimary;

  return ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF312E81)
        : const Color(0xFFE0E7FF),
    onPrimaryContainer: isDark
        ? const Color(0xFFEDE9FE)
        : const Color(0xFF1E1B4B),
    secondary: secondary,
    onSecondary: isDark ? const Color(0xFF082F49) : Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF164E63)
        : const Color(0xFFCFFAFE),
    onSecondaryContainer: isDark
        ? const Color(0xFFE0F2FE)
        : const Color(0xFF083344),
    surface: surface,
    onSurface: onSurface,
    surfaceContainerLowest: isDark ? const Color(0xFF070A12) : Colors.white,
    surfaceContainerLow: isDark
        ? const Color(0xFF0D1422)
        : const Color(0xFFFBFCFE),
    surfaceContainer: isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF7F8FA),
    surfaceContainerHigh: isDark
        ? const Color(0xFF172033)
        : const Color(0xFFF3F4F6),
    surfaceContainerHighest: isDark
        ? const Color(0xFF1F2937)
        : const Color(0xFFE5E7EB),
    outline: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
    outlineVariant: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
    onInverseSurface: isDark
        ? const Color(0xFF111827)
        : const Color(0xFFE5E7EB),
    error: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
  );
}

ThemeData _buildAppThemeFromScheme({
  required ColorScheme colorScheme,
  required Brightness brightness,
  String? lightCodeThemePreference,
  String? darkCodeThemePreference,
}) {
  final isDark = brightness == Brightness.dark;
  final tokens = AppThemeTokens.fallback.copyWith(
    codeBackground: isDark
        ? CodexMThemePalette.darkCodeBackground
        : CodexMThemePalette.lightCodeBackground,
    lightCodeThemePreference: lightCodeThemePreference,
    darkCodeThemePreference: darkCodeThemePreference,
  );
  final surfaceTint = colorScheme.surfaceContainerHighest.withValues(
    alpha: isDark ? 0.22 : 0.34,
  );
  final textTheme = Typography.material2021(
    platform: TargetPlatform.android,
    colorScheme: colorScheme,
  ).black;

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: isDark
        ? CodexMThemePalette.darkBackground
        : CodexMThemePalette.lightBackground,
    extensions: <ThemeExtension<dynamic>>[tokens],
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleSmall: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        height: 1.5,
        fontSize: 15,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        height: 1.5,
        fontSize: 13,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        height: 1.4,
        fontSize: 11,
        letterSpacing: 0,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: textTheme.labelMedium?.copyWith(
        letterSpacing: 0,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        letterSpacing: 0,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: tokens.elevationLow,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
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
      backgroundColor: colorScheme.surface,
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
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
