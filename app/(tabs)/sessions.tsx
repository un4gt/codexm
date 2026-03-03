import { useFocusEffect } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import { useCallback, useMemo, useState } from 'react';
import { Alert, FlatList, StyleSheet, View } from 'react-native';
import { ActivityIndicator, Button, Card, IconButton, List, Text, useTheme } from 'react-native-paper';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Layout, Spacing } from '@/constants/theme';
import { deleteSession, listSessions } from '@/src/sessions/store';
import type { Session } from '@/src/sessions/types';
import { useWorkspaces } from '@/src/workspaces/provider';

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
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { workspaces, activeWorkspaceId } = useWorkspaces();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);

  const active = useMemo(() => workspaces.find((w) => w.id === activeWorkspaceId) ?? null, [activeWorkspaceId, workspaces]);
  const activeId = active?.id ?? null;

  const listItems = useMemo(() => buildSessionListItems(sessions), [sessions]);

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
      <View style={[styles.screen, { backgroundColor: theme.colors.background }]}>
        <View style={[styles.container, { paddingTop: 16 + insets.top }]}>
          <Text variant="headlineMedium" style={{ fontWeight: 'bold' }}>会话</Text>
          <Text style={{ color: theme.colors.onSurfaceVariant }}>请先选择一个工作区。</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <View style={[styles.container, { paddingTop: 16 + insets.top }]}>
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            <Text variant="headlineMedium" style={{ fontWeight: 'bold' }}>会话</Text>
            <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
              工作区：<Text variant="bodyMedium" style={{ fontWeight: 'bold' }}>{active.name}</Text>
            </Text>
          </View>
          <Button
            mode="contained"
            onPress={() => router.push('/new-session' as any)}
            style={styles.button}
          >
            新建
          </Button>
        </View>

        {error ? (
          <Text style={[styles.error, { color: theme.colors.error }]}>
            {error}
          </Text>
        ) : null}

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator animating={true} size="large" />
          </View>
        ) : (
          <FlatList
            data={listItems}
            keyExtractor={(it) => it.id}
            contentContainerStyle={{ paddingBottom: 24 }}
            keyboardDismissMode="on-drag"
            keyboardShouldPersistTaps="handled"
            renderItem={({ item }) => {
              if (item.type === 'date-header') {
                return (
                  <List.Subheader style={{ color: theme.colors.primary }}>
                    {item.title}
                  </List.Subheader>
                );
              }

              return (
                <Card
                  style={[styles.sessionCard, { backgroundColor: theme.colors.surfaceVariant }]}
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
                >
                  <Card.Title
                    title={item.session.title}
                    titleVariant="titleMedium"
                    subtitle={new Date(item.session.updatedAt).toLocaleTimeString()}
                    subtitleVariant="bodySmall"
                    right={(props) => <IconButton {...props} icon="chevron-right" />}
                  />
                </Card>
              );
            }}
            ListEmptyComponent={
              <Text style={{ color: theme.colors.onSurfaceVariant, textAlign: 'center', marginTop: 24 }}>
                还没有会话。
              </Text>
            }
          />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    flex: 1,
    paddingHorizontal: Spacing.lg,
    width: '100%',
    maxWidth: Layout.maxWidthWide,
    alignSelf: 'center',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 16,
  },
  button: {
    borderRadius: 8,
  },
  sessionCard: {
    marginBottom: 12,
    borderRadius: 12,
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
