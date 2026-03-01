import { useMemo } from 'react';
import { Alert, Linking, StyleSheet, Text, View } from 'react-native';
import { openBrowserAsync, WebBrowserPresentationStyle } from 'expo-web-browser';

import { Colors, Fonts } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { parseMarkdown } from '@/src/markdown/parseMarkdown';
import type { MarkdownSpan } from '@/src/markdown/types';

import { CodeBlock } from './CodeBlock';

type Props = {
  markdown: string;
  selectable?: boolean;
};

async function openLink(url: string) {
  if (!url) return;

  if (process.env.EXPO_OS !== 'web') {
    try {
      await openBrowserAsync(url, { presentationStyle: WebBrowserPresentationStyle.AUTOMATIC });
      return;
    } catch {
      // fall through
    }
  }

  try {
    const can = await Linking.canOpenURL(url);
    if (!can) {
      Alert.alert('无法打开链接', '该链接无法在当前设备中打开。');
      return;
    }
  } catch {
    // ignore
  }

  try {
    await Linking.openURL(url);
  } catch {
    Alert.alert('无法打开链接', '该链接无法在当前设备中打开。');
  }
}

function SpansText({
  spans,
  selectable,
  baseStyle,
  linkColor,
  codeBg,
  codeBorder,
}: {
  spans: MarkdownSpan[];
  selectable: boolean;
  baseStyle: any;
  linkColor: string;
  codeBg: string;
  codeBorder: string;
}) {
  return (
    <Text selectable={selectable} style={baseStyle}>
      {spans.map((span, idx) => {
        const isBold = span.styles.includes('bold');
        const isItalic = span.styles.includes('italic');
        const isCode = span.styles.includes('code');

        const spanStyle = [
          isBold && styles.bold,
          isItalic && styles.italic,
          isCode && [
            styles.inlineCode,
            {
              backgroundColor: codeBg,
              borderColor: codeBorder,
            },
          ],
          span.url && [styles.link, { color: linkColor }],
        ];

        return (
          <Text
            key={`${idx}-${span.text.slice(0, 12)}`}
            suppressHighlighting={!!span.url}
            onPress={span.url ? () => openLink(span.url!) : undefined}
            style={spanStyle}>
            {span.text}
          </Text>
        );
      })}
    </Text>
  );
}

export function MarkdownView({ markdown, selectable = true }: Props) {
  const colorScheme = useColorScheme() ?? 'light';
  const colors = Colors[colorScheme];

  const blocks = useMemo(() => parseMarkdown(markdown), [markdown]);

  const codeBg = colorScheme === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)';
  const codeBorder = colorScheme === 'dark' ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.10)';

  return (
    <View style={styles.container}>
      {blocks.map((block, index) => {
        const key = `${block.type}-${index}`;
        switch (block.type) {
          case 'header': {
            const headerStyle =
              block.level === 1
                ? styles.h1
                : block.level === 2
                  ? styles.h2
                  : block.level === 3
                    ? styles.h3
                    : styles.h4;
            return (
              <View key={key} style={styles.block}>
                <SpansText
                  spans={block.content}
                  selectable={selectable}
                  baseStyle={[styles.text, headerStyle, { color: colors.text }]}
                  linkColor={colors.tint}
                  codeBg={codeBg}
                  codeBorder={codeBorder}
                />
              </View>
            );
          }
          case 'horizontal-rule':
            return (
              <View key={key} style={styles.block}>
                <View style={[styles.hr, { backgroundColor: colors.outlineMuted }]} />
              </View>
            );
          case 'code-block':
            return (
              <View key={key} style={styles.block}>
                <CodeBlock code={block.content} language={block.language} selectable={selectable} />
              </View>
            );
          case 'list':
            return (
              <View key={key} style={styles.block}>
                {block.items.map((itemSpans, itemIndex) => (
                  <View key={`${key}-li-${itemIndex}`} style={styles.listRow}>
                    <Text style={[styles.listBullet, { color: colors.icon }]}>•</Text>
                    <View style={styles.listContent}>
                      <SpansText
                        spans={itemSpans}
                        selectable={selectable}
                        baseStyle={[styles.text, { color: colors.text }]}
                        linkColor={colors.tint}
                        codeBg={codeBg}
                        codeBorder={codeBorder}
                      />
                    </View>
                  </View>
                ))}
              </View>
            );
          case 'numbered-list':
            return (
              <View key={key} style={styles.block}>
                {block.items.map((it, itemIndex) => (
                  <View key={`${key}-nli-${itemIndex}`} style={styles.listRow}>
                    <Text style={[styles.listBullet, { color: colors.icon }]}>{it.number}.</Text>
                    <View style={styles.listContent}>
                      <SpansText
                        spans={it.spans}
                        selectable={selectable}
                        baseStyle={[styles.text, { color: colors.text }]}
                        linkColor={colors.tint}
                        codeBg={codeBg}
                        codeBorder={codeBorder}
                      />
                    </View>
                  </View>
                ))}
              </View>
            );
          case 'blockquote':
            return (
              <View
                key={key}
                style={[
                  styles.block,
                  styles.blockquote,
                  { borderLeftColor: colors.outline, backgroundColor: colors.surface2 },
                ]}>
                <SpansText
                  spans={block.content}
                  selectable={selectable}
                  baseStyle={[styles.text, { color: colors.text }]}
                  linkColor={colors.tint}
                  codeBg={codeBg}
                  codeBorder={codeBorder}
                />
              </View>
            );
          case 'text':
          default:
            return (
              <View key={key} style={styles.block}>
                <SpansText
                  spans={block.content}
                  selectable={selectable}
                  baseStyle={[styles.text, { color: colors.text }]}
                  linkColor={colors.tint}
                  codeBg={codeBg}
                  codeBorder={codeBorder}
                />
              </View>
            );
        }
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexShrink: 1,
  },
  block: {
    marginBottom: 10,
  },
  text: {
    fontSize: 15,
    lineHeight: 22,
  },
  h1: {
    fontSize: 22,
    lineHeight: 28,
    fontWeight: '800',
    letterSpacing: 0.2,
    marginTop: 2,
  },
  h2: {
    fontSize: 18,
    lineHeight: 24,
    fontWeight: '800',
    letterSpacing: 0.2,
    marginTop: 2,
  },
  h3: {
    fontSize: 16,
    lineHeight: 22,
    fontWeight: '700',
  },
  h4: {
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '700',
  },
  bold: {
    fontWeight: '700',
  },
  italic: {
    fontStyle: 'italic',
  },
  link: {
    textDecorationLine: 'underline',
    textDecorationStyle: 'solid',
  },
  inlineCode: {
    fontFamily: Fonts.mono,
    fontSize: 13,
    lineHeight: 18,
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  hr: {
    height: 1,
    opacity: 0.7,
  },
  listRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingVertical: 2,
  },
  listBullet: {
    width: 24,
    fontSize: 15,
    lineHeight: 22,
  },
  listContent: {
    flex: 1,
  },
  blockquote: {
    borderLeftWidth: 3,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
});
