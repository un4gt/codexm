/**
 * Below are the colors that are used in the app. The colors are defined in the light and dark mode.
 * There are many other ways to style your app. For example, [Nativewind](https://www.nativewind.dev/), [Tamagui](https://tamagui.dev/), [unistyles](https://reactnativeunistyles.vercel.app), etc.
 */

import { Platform } from 'react-native';
import { MD3DarkTheme, MD3LightTheme } from 'react-native-paper';

const ROUNDNESS = 12;

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
} as const;

export const Radii = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 28,
  pill: 999,
} as const;

export const Layout = {
  maxWidthWide: 980,
  maxWidthForm: 720,
} as const;

export const MaterialLightTheme = {
  ...MD3LightTheme,
  roundness: ROUNDNESS,
} as const;

export const MaterialDarkTheme = {
  ...MD3DarkTheme,
  roundness: ROUNDNESS,
} as const;

export const Colors = {
  light: {
    text: MaterialLightTheme.colors.onBackground,
    background: MaterialLightTheme.colors.background,
    surface: MaterialLightTheme.colors.surface,
    surface2: MaterialLightTheme.colors.surfaceVariant,
    tint: MaterialLightTheme.colors.primary,
    onTint: MaterialLightTheme.colors.onPrimary,
    icon: MaterialLightTheme.colors.onSurfaceVariant,
    outline: MaterialLightTheme.colors.outline,
    outlineMuted: MaterialLightTheme.colors.outlineVariant,
    danger: MaterialLightTheme.colors.error,
    tabIconDefault: MaterialLightTheme.colors.onSurfaceVariant,
    tabIconSelected: MaterialLightTheme.colors.primary,
  },
  dark: {
    text: MaterialDarkTheme.colors.onBackground,
    background: MaterialDarkTheme.colors.background,
    surface: MaterialDarkTheme.colors.surface,
    surface2: MaterialDarkTheme.colors.surfaceVariant,
    tint: MaterialDarkTheme.colors.primary,
    onTint: MaterialDarkTheme.colors.onPrimary,
    icon: MaterialDarkTheme.colors.onSurfaceVariant,
    outline: MaterialDarkTheme.colors.outline,
    outlineMuted: MaterialDarkTheme.colors.outlineVariant,
    danger: MaterialDarkTheme.colors.error,
    tabIconDefault: MaterialDarkTheme.colors.onSurfaceVariant,
    tabIconSelected: MaterialDarkTheme.colors.primary,
  },
} as const;

export const Fonts = Platform.select({
  ios: {
    /** iOS `UIFontDescriptorSystemDesignDefault` */
    sans: 'system-ui',
    /** iOS `UIFontDescriptorSystemDesignSerif` */
    serif: 'ui-serif',
    /** iOS `UIFontDescriptorSystemDesignRounded` */
    rounded: 'ui-rounded',
    /** iOS `UIFontDescriptorSystemDesignMonospaced` */
    mono: 'ui-monospace',
  },
  default: {
    sans: 'normal',
    serif: 'serif',
    rounded: 'normal',
    mono: 'monospace',
  },
  web: {
    sans: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
    serif: "Georgia, 'Times New Roman', serif",
    rounded: "'SF Pro Rounded', 'Hiragino Maru Gothic ProN', Meiryo, 'MS PGothic', sans-serif",
    mono: "SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace",
  },
});
