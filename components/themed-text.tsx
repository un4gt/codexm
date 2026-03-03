import type { ComponentProps } from 'react';
import { StyleSheet } from 'react-native';
import { Text } from 'react-native-paper';

import { useThemeColor } from '@/hooks/use-theme-color';

export type ThemedTextProps = ComponentProps<typeof Text> & {
  lightColor?: string;
  darkColor?: string;
  type?: 'default' | 'title' | 'defaultSemiBold' | 'subtitle' | 'link';
};

export function ThemedText({
  style,
  lightColor,
  darkColor,
  type = 'default',
  ...rest
}: ThemedTextProps) {
  const color = useThemeColor({ light: lightColor, dark: darkColor }, type === 'link' ? 'tint' : 'text');

  return (
    <Text
      variant={type === 'title' ? 'headlineMedium' : type === 'subtitle' ? 'titleLarge' : 'bodyLarge'}
      style={[
        { color },
        type === 'defaultSemiBold' ? styles.semiBold : undefined,
        type === 'link' ? styles.link : undefined,
        style,
      ]}
      {...rest}
    />
  );
}

const styles = StyleSheet.create({
  semiBold: {
    fontWeight: '600',
  },
  link: {
    fontWeight: '600',
    textDecorationLine: 'underline',
  },
});
