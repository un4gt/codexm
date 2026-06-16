import 'package:codexm_flutter/app/theme/app_theme.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixed palette produces requested core colors', () {
    final light = buildLightAppTheme();
    final dark = buildDarkAppTheme();

    expect(light.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
    expect(light.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(light.colorScheme.primary, const Color(0xFF4F46E5));
    expect(light.colorScheme.secondary, const Color(0xFF06B6D4));
    expect(light.colorScheme.onSurface, const Color(0xFF111827));
    expect(light.appTokens.codeBackground, const Color(0xFFF3F4F6));

    expect(dark.scaffoldBackgroundColor, const Color(0xFF0B0F19));
    expect(dark.colorScheme.surface, const Color(0xFF111827));
    expect(dark.colorScheme.primary, const Color(0xFF6366F1));
    expect(dark.colorScheme.secondary, const Color(0xFF22D3EE));
    expect(dark.colorScheme.onSurface, const Color(0xFFE5E7EB));
    expect(dark.appTokens.codeBackground, const Color(0xFF0F172A));
  });

  test('code theme preferences are exposed through theme tokens', () {
    final theme = buildDarkAppTheme(
      lightCodeThemePreference: CodexLightCodeThemePreference.githubLight,
      darkCodeThemePreference: CodexDarkCodeThemePreference.dracula,
    );

    expect(
      theme.appTokens.lightCodeThemePreference,
      CodexLightCodeThemePreference.githubLight,
    );
    expect(
      theme.appTokens.darkCodeThemePreference,
      CodexDarkCodeThemePreference.dracula,
    );
  });

  test('theme mode preference maps to Material theme mode', () {
    expect(codexThemeModeFromPreference('system'), ThemeMode.system);
    expect(codexThemeModeFromPreference('light'), ThemeMode.light);
    expect(codexThemeModeFromPreference('dark'), ThemeMode.dark);
    expect(codexThemeModeFromPreference('invalid'), ThemeMode.system);
  });

  test('custom accent and dynamic paths fall back safely', () {
    final custom = buildLightAppTheme(accentColor: const Color(0xFFDB2777));
    expect(custom.colorScheme.primary, isNot(const Color(0xFF4F46E5)));
    expect(custom.colorScheme.surface, const Color(0xFFFFFFFF));

    final dynamic = buildDarkAppTheme(
      dynamicColorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
    );
    expect(dynamic.colorScheme.primary, isNotNull);
    expect(dynamic.appTokens.chatHorizontalGutterFactor, 0.04);
    expect(dynamic.appTokens.chatMessageWidthFactor, 0.92);
  });
}

extension on ThemeData {
  AppThemeTokens get appTokens =>
      extension<AppThemeTokens>() ?? AppThemeTokens.fallback;
}
