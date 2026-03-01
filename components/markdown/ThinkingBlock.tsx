import { useMemo, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';

import { MarkdownView } from './MarkdownView';

type Props = {
  thinking: string;
};

export function ThinkingBlock({ thinking }: Props) {
  const colorScheme = useColorScheme() ?? 'light';
  const [open, setOpen] = useState(false);

  const rippleColor = useMemo(
    () => (colorScheme === 'dark' ? 'rgba(255,255,255,0.14)' : 'rgba(2,6,23,0.08)'),
    [colorScheme]
  );

  return (
    <ThemedView
      style={[
        styles.container,
        {
          backgroundColor: Colors[colorScheme].surface2,
          borderColor: Colors[colorScheme].outlineMuted,
        },
      ]}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={open ? '收起思考内容' : '展开思考内容'}
        android_ripple={{ color: rippleColor }}
        onPress={() => setOpen((v) => !v)}
        style={styles.header}>
        <View style={styles.headerLeft}>
          <MaterialIcons
            name={open ? 'expand-more' : 'chevron-right'}
            size={18}
            color={Colors[colorScheme].icon}
          />
          <ThemedText type="defaultSemiBold">思考</ThemedText>
        </View>

        <ThemedText style={styles.muted}>{open ? '收起' : '展开'}</ThemedText>
      </Pressable>

      {open ? (
        <View style={styles.content}>
          <MarkdownView markdown={thinking} selectable />
        </View>
      ) : null}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    borderWidth: 1,
    borderRadius: 12,
    overflow: 'hidden',
  },
  header: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  content: {
    paddingHorizontal: 12,
    paddingBottom: 12,
  },
  muted: {
    opacity: 0.7,
  },
});

