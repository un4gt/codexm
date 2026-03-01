import { useCallback, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Pressable, StyleSheet, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';

import { useFocusEffect } from '@react-navigation/native';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useWorkspaces } from '@/src/workspaces/provider';
import { deleteSession, listSessions } from '@/src/sessions/store';
import type { Session } from '@/src/sessions/types';
import { useRouter } from 'expo-router';

type SessionListItem =
  | { type: 'date-header'; id: string; title: string }
  | { type: 'session'; id: string; session: Session };

function isSameDay(a: Date, b: Date) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function formatDayLabel(timestamp: number) {
  const d = new Date(timestamp);
  const now = new Date();
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);

  if (isSameDay(d, now)) return '今天';
  if (isSameDay(d, yesterday)) return '昨天';
  return d.toLocaleDateString();
}

function buildSessionListItems(sessions: Session[]): SessionListItem[] {
  const sorted = [...sessions].sort((a, b) => b.updatedAt - a.updatedAt);
  const items: SessionListItem[] = [];
  let lastLabel: string | null = null;

  for (const s of sorted) {
    const label = formatDayLabel(s.updatedAt);
    if (label !== lastLabel) {
      items.push({ type: 'date-header', id: `h-${label}`, title: label });
      lastLabel = label;
    }
    items.push({ type: 'session', id: s.id, session: s });
  }

  return items;
}

export default function SessionsScreen() {
  const router = useRouter();
  const colorScheme = useColorScheme() ?? 'light';
  const { workspaces, activeWorkspaceId } = useWorkspaces();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);

  const active = useMemo(() => workspaces.find((w) => w.id === activeWorkspaceId) ?? null, [activeWorkspaceId, workspaces]);
  const activeId = active?.id ?? null;

  const listItems = useMemo(() => buildSessionListItems(sessions), [sessions]);

  const rippleColor = useMemo(
    () => (colorScheme === 'dark' ? 'rgba(255,255,255,0.14)' : 'rgba(2,6,23,0.08)'),
    [colorScheme]
  );

  useFocusEffect(
    useCallback(() => {
    let cancelled = false;
    async function run() {
      if (!activeId) {
        setSessions([]);
        setError(null);
        return;
      }
      setLoading(true);
      setError(null);
      try {
        const all = await listSessions(activeId);
        if (!cancelled) setSessions(all);
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        if (!cancelled) setError(message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    run();
    return () => {
      cancelled = true;
    };
    }, [activeId])
  );

  if (!active) {
    return (
      <ThemedView style={styles.screen}>
        <View style={styles.container}>
          <ThemedText type="title">会话</ThemedText>
          <ThemedText style={styles.muted}>请先选择一个工作区。</ThemedText>
        </View>
      </ThemedView>
    );
  }

  return (
    <ThemedView style={styles.screen}>
      <View style={styles.container}>
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            <ThemedText type="title">会话</ThemedText>
            <ThemedText style={styles.muted}>
              工作区：<ThemedText type="defaultSemiBold">{active.name}</ThemedText>
            </ThemedText>
          </View>
          <Pressable
            accessibilityRole="button"
            android_ripple={{ color: rippleColor }}
            style={({ pressed }) => [
              styles.primaryButton,
              { opacity: pressed ? 0.9 : 1, backgroundColor: Colors[colorScheme].tint },
            ]}
            onPress={() => router.push('/new-session' as any)}>
            <ThemedText type="defaultSemiBold" style={{ color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }}>
              新建
            </ThemedText>
          </Pressable>
        </View>

        {error ? (
          <ThemedText type="default" style={[styles.error, { color: Colors[colorScheme].danger }]}>
            {error}
          </ThemedText>
        ) : null}

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator />
          </View>
        ) : (
          <FlatList
            data={listItems}
            keyExtractor={(it) => it.id}
            contentContainerStyle={{ paddingBottom: 24 }}
            keyboardDismissMode="on-drag"
            keyboardShouldPersistTaps="handled"
            renderItem={({ item, index }) => {
              if (item.type === 'date-header') {
                return (
                  <ThemedText type="default" style={[styles.sectionTitle, { color: Colors[colorScheme].icon }]}>
                    {item.title}
                  </ThemedText>
                );
              }

              const prev = listItems[index - 1];
              const next = listItems[index + 1];
              const isFirst = prev?.type === 'date-header' || prev == null;
              const isLast = next?.type === 'date-header' || next == null;
              const isSingle = isFirst && isLast;

              return (
                <Pressable
                  accessibilityRole="button"
                  android_ripple={{ color: rippleColor }}
                  onPress={() => router.push(`/session/${item.session.id}`)}
                  onLongPress={() => {
                    Alert.alert('删除会话？', item.session.title, [
                      { text: '取消', style: 'cancel' },
                      {
                        text: '删除',
                        style: 'destructive',
                        onPress: async () => {
                          await deleteSession(active.id, item.session.id);
                          const all = await listSessions(active.id);
                          setSessions(all);
                        },
                      },
                    ]);
                  }}
                  style={({ pressed }) => [
                    styles.sessionCard,
                    !isFirst && styles.sessionCardNotFirst,
                    isSingle ? styles.sessionCardSingle : isFirst ? styles.sessionCardFirst : isLast ? styles.sessionCardLast : undefined,
                    {
                      opacity: pressed ? 0.92 : 1,
                      borderColor: Colors[colorScheme].outline,
                      backgroundColor: Colors[colorScheme].surface,
                    },
                  ]}>
                  <View style={{ flex: 1 }}>
                    <ThemedText type="defaultSemiBold" numberOfLines={1} style={{ marginBottom: 2 }}>
                      {item.session.title}
                    </ThemedText>
                    <ThemedText style={styles.muted} numberOfLines={1}>
                      {new Date(item.session.updatedAt).toLocaleTimeString()}
                    </ThemedText>
                  </View>
                  <MaterialIcons name="chevron-right" size={20} color={Colors[colorScheme].icon} />
                </Pressable>
              );
            }}
            ListEmptyComponent={<ThemedText style={styles.muted}>还没有会话。</ThemedText>}
          />
        )}
      </View>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    flex: 1,
    paddingTop: 24,
    paddingHorizontal: 16,
    width: '100%',
    maxWidth: 980,
    alignSelf: 'center',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 16,
  },
  primaryButton: {
    minHeight: 44,
    paddingHorizontal: 12,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  sectionTitle: {
    marginTop: 14,
    marginBottom: 8,
    fontSize: 13,
    letterSpacing: 0.2,
    opacity: 0.85,
  },
  sessionCard: {
    minHeight: 56,
    paddingVertical: 12,
    paddingHorizontal: 12,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 10,
    overflow: 'hidden',
  },
  sessionCardNotFirst: {
    marginTop: -1,
  },
  sessionCardFirst: {
    borderTopLeftRadius: 14,
    borderTopRightRadius: 14,
  },
  sessionCardLast: {
    borderBottomLeftRadius: 14,
    borderBottomRightRadius: 14,
    marginBottom: 12,
  },
  sessionCardSingle: {
    borderRadius: 14,
    marginBottom: 12,
  },
  muted: {
    opacity: 0.7,
  },
  error: {
    marginBottom: 8,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
