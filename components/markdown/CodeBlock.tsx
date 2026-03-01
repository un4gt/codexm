import { useEffect, useMemo, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import * as Clipboard from 'expo-clipboard';

import { Colors, Fonts } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';

type Props = {
  code: string;
  language?: string | null;
  selectable?: boolean;
};

export function CodeBlock({ code, language = null, selectable = true }: Props) {
  const colorScheme = useColorScheme() ?? 'light';
  const colors = Colors[colorScheme];

  const [copied, setCopied] = useState(false);
  const copiedTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const normalized = useMemo(() => code.replace(/\n$/, ''), [code]);

  useEffect(() => {
    return () => {
      if (copiedTimerRef.current) clearTimeout(copiedTimerRef.current);
    };
  }, []);

  async function copyCode() {
    if (!normalized) return;
    try {
      await Clipboard.setStringAsync(normalized);
    } catch {
      return;
    }
    setCopied(true);
    if (copiedTimerRef.current) clearTimeout(copiedTimerRef.current);
    copiedTimerRef.current = setTimeout(() => setCopied(false), 1200);
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.surface2, borderColor: colors.outlineMuted }]}>
      <View style={styles.header}>
        {language ? (
          <Text style={[styles.language, { color: colors.icon }]} numberOfLines={1}>
            {language}
          </Text>
        ) : (
          <View />
        )}

        <Pressable
          accessibilityRole="button"
          accessibilityLabel="复制代码"
          onPress={copyCode}
          style={({ pressed }) => [
            styles.copyButton,
            {
              backgroundColor: pressed
                ? colorScheme === 'dark'
                  ? 'rgba(255,255,255,0.08)'
                  : 'rgba(0,0,0,0.06)'
                : 'transparent',
            },
          ]}>
          <MaterialIcons
            size={16}
            name={copied ? 'check' : 'content-copy'}
            color={copied ? colors.tint : colors.icon}
          />
          <Text style={[styles.copyText, { color: colors.text }]}>{copied ? '已复制' : '复制'}</Text>
        </Pressable>
      </View>

      <ScrollView
        horizontal
        bounces={false}
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}>
        <Text selectable={selectable} style={[styles.code, { color: colors.text }]}>
          {normalized}
        </Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 12,
    borderWidth: 1,
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 12,
    paddingTop: 10,
    paddingBottom: 6,
  },
  language: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.2,
    opacity: 0.9,
  },
  copyButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderRadius: 999,
    overflow: 'hidden',
  },
  copyText: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.1,
  },
  scrollContent: {
    paddingHorizontal: 12,
    paddingTop: 6,
    paddingBottom: 12,
  },
  code: {
    fontFamily: Fonts.mono,
    fontSize: 13,
    lineHeight: 18,
  },
});
