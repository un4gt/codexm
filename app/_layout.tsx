import { DarkTheme as NavigationDarkTheme, DefaultTheme as NavigationDefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import 'react-native-reanimated';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { adaptNavigationTheme, PaperProvider } from 'react-native-paper';

import { MaterialDarkTheme, MaterialLightTheme } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { McpProvider } from '@/src/mcp/provider';
import { WorkspacesProvider } from '@/src/workspaces/provider';

export const unstable_settings = {
  anchor: '(tabs)',
};

const { LightTheme: NavigationLightTheme, DarkTheme: NavigationDarkThemeAdapted } = adaptNavigationTheme({
  reactNavigationLight: NavigationDefaultTheme,
  reactNavigationDark: NavigationDarkTheme,
});

const CombinedLightTheme = {
  ...MaterialLightTheme,
  ...NavigationLightTheme,
  colors: {
    ...MaterialLightTheme.colors,
    ...NavigationLightTheme.colors,
  },
  fonts: {
    ...MaterialLightTheme.fonts,
    ...NavigationLightTheme.fonts,
  },
};

const CombinedDarkTheme = {
  ...MaterialDarkTheme,
  ...NavigationDarkThemeAdapted,
  colors: {
    ...MaterialDarkTheme.colors,
    ...NavigationDarkThemeAdapted.colors,
  },
  fonts: {
    ...MaterialDarkTheme.fonts,
    ...NavigationDarkThemeAdapted.fonts,
  },
};

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const theme = colorScheme === 'dark' ? CombinedDarkTheme : CombinedLightTheme;

  return (
    <SafeAreaProvider>
      <PaperProvider theme={theme as any}>
        <WorkspacesProvider>
          <McpProvider>
            <ThemeProvider value={theme as any}>
              <Stack>
                <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
                <Stack.Screen name="modal" options={{ presentation: 'modal', title: '弹窗' }} />
              </Stack>
              <StatusBar style="auto" />
            </ThemeProvider>
          </McpProvider>
        </WorkspacesProvider>
      </PaperProvider>
    </SafeAreaProvider>
  );
}
