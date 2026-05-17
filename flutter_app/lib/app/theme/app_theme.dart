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
    pagePadding: EdgeInsets.fromLTRB(20, 16, 20, 20),
    sectionSpacing: 20,
    compactSpacing: 12,
    cardRadius: 22,
    inputRadius: 22,
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

@immutable
class CodexMColors extends ThemeExtension<CodexMColors> {
  const CodexMColors({
    required this.pageBg,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.border,
    required this.divider,
    required this.textStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.primarySoft,
    required this.primaryMuted,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.codeBg,
    required this.codeFg,
  });

  final Color pageBg;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color border;
  final Color divider;
  final Color textStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color primary;
  final Color primarySoft;
  final Color primaryMuted;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;
  final Color codeBg;
  final Color codeFg;

  static const light = CodexMColors(
    pageBg: Color(0xFFF7F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F4F8),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFD8DEE8),
    divider: Color(0xFFE5EAF2),
    textStrong: Color(0xFF111827),
    text: Color(0xFF273142),
    textMuted: Color(0xFF667085),
    textSubtle: Color(0xFF98A2B3),
    primary: Color(0xFF3E6492),
    primarySoft: Color(0xFFDDE8F8),
    primaryMuted: Color(0xFF6F8DB3),
    success: Color(0xFF18794E),
    successSoft: Color(0xFFE7F6ED),
    warning: Color(0xFFB54708),
    warningSoft: Color(0xFFFFF4E5),
    error: Color(0xFFB42318),
    errorSoft: Color(0xFFFEE4E2),
    info: Color(0xFF3E6492),
    infoSoft: Color(0xFFDDE8F8),
    codeBg: Color(0xFFEEF1F5),
    codeFg: Color(0xFF243041),
  );

  static const dark = CodexMColors(
    pageBg: Color(0xFF101318),
    surface: Color(0xFF161A21),
    surfaceMuted: Color(0xFF202633),
    surfaceElevated: Color(0xFF1B202A),
    border: Color(0xFF303948),
    divider: Color(0xFF293241),
    textStrong: Color(0xFFF8FAFC),
    text: Color(0xFFE5E7EB),
    textMuted: Color(0xFFB3BDC9),
    textSubtle: Color(0xFF8793A3),
    primary: Color(0xFF9DB9DD),
    primarySoft: Color(0xFF26384F),
    primaryMuted: Color(0xFF7896BD),
    success: Color(0xFF6DD3A1),
    successSoft: Color(0xFF183A2A),
    warning: Color(0xFFFFB86A),
    warningSoft: Color(0xFF452C12),
    error: Color(0xFFFF938A),
    errorSoft: Color(0xFF4A1D1A),
    info: Color(0xFF9DB9DD),
    infoSoft: Color(0xFF26384F),
    codeBg: Color(0xFF202633),
    codeFg: Color(0xFFE5E7EB),
  );

  @override
  CodexMColors copyWith({
    Color? pageBg,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? border,
    Color? divider,
    Color? textStrong,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? primary,
    Color? primarySoft,
    Color? primaryMuted,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? error,
    Color? errorSoft,
    Color? info,
    Color? infoSoft,
    Color? codeBg,
    Color? codeFg,
  }) {
    return CodexMColors(
      pageBg: pageBg ?? this.pageBg,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      textStrong: textStrong ?? this.textStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      codeBg: codeBg ?? this.codeBg,
      codeFg: codeFg ?? this.codeFg,
    );
  }

  @override
  CodexMColors lerp(ThemeExtension<CodexMColors>? other, double t) {
    if (other is! CodexMColors) {
      return this;
    }
    return CodexMColors(
      pageBg: Color.lerp(pageBg, other.pageBg, t) ?? pageBg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      border: Color.lerp(border, other.border, t) ?? border,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      textStrong: Color.lerp(textStrong, other.textStrong, t) ?? textStrong,
      text: Color.lerp(text, other.text, t) ?? text,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t) ?? textSubtle,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t) ?? primarySoft,
      primaryMuted:
          Color.lerp(primaryMuted, other.primaryMuted, t) ?? primaryMuted,
      success: Color.lerp(success, other.success, t) ?? success,
      successSoft: Color.lerp(successSoft, other.successSoft, t) ?? successSoft,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t) ?? warningSoft,
      error: Color.lerp(error, other.error, t) ?? error,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t) ?? errorSoft,
      info: Color.lerp(info, other.info, t) ?? info,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t) ?? infoSoft,
      codeBg: Color.lerp(codeBg, other.codeBg, t) ?? codeBg,
      codeFg: Color.lerp(codeFg, other.codeFg, t) ?? codeFg,
    );
  }
}

class CodexMRadii {
  const CodexMRadii._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

class CodexMSpacing {
  const CodexMSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

extension AppThemeTokensBuildContext on BuildContext {
  AppThemeTokens get appTokens =>
      Theme.of(this).extension<AppThemeTokens>() ?? AppThemeTokens.fallback;

  CodexMColors get codexColors =>
      Theme.of(this).extension<CodexMColors>() ?? CodexMColors.light;
}

ThemeData buildAppTheme() {
  const codexColors = CodexMColors.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: codexColors.primary,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: codexColors.pageBg,
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeTokens.fallback,
      CodexMColors.light,
    ],
    textTheme: TextTheme(
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 34,
        letterSpacing: 0,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      bodyLarge: TextStyle(height: 1.5, fontSize: 15, color: codexColors.text),
      bodyMedium: TextStyle(height: 1.5, fontSize: 13, color: codexColors.text),
      bodySmall: TextStyle(
        height: 1.4,
        fontSize: 11,
        color: codexColors.textMuted,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: codexColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeTokens.fallback.cardRadius),
        side: const BorderSide(color: Color(0xFFD8DEE8)),
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
      backgroundColor: codexColors.surface,
      height: 74,
      indicatorColor: codexColors.primarySoft,
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
      fillColor: codexColors.surfaceMuted,
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
      backgroundColor: codexColors.surfaceMuted,
      selectedColor: codexColors.primarySoft,
      side: const BorderSide(color: Color(0xFFD8DEE8)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CodexMRadii.pill),
      ),
      labelStyle: TextStyle(color: codexColors.text),
    ),
    dividerTheme: DividerThemeData(
      color: codexColors.divider,
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
