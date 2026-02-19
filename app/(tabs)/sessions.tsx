import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, FlatList, Pressable, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useWorkspaces } from '@/src/workspaces/provider';
import { createSession, deleteSession, listSessions } from '@/src/sessions/store';
import type { Session } from '@/src/sessions/types';
import { useRouter } from 'expo-router';

export default function SessionsScreen() {
  const router = useRouter();
  const colorScheme = useColorScheme() ?? 'light';
  const { workspaces, activeWorkspaceId } = useWorkspaces();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);

  const active = useMemo(() => workspaces.find((w) => w.id === activeWorkspaceId) ?? null, [activeWorkspaceId, workspaces]);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      if (!active) {
        setSessions([]);
        setError(null);
        return;
      }
      setLoading(true);
      setError(null);
      try {
        const all = await listSessions(active.id);
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
  }, [active]);

  if (!active) {
    return (
      <ThemedView style={styles.container}>
        <ThemedText type="title">会话</ThemedText>
        <ThemedText style={styles.muted}>请先选择一个工作区。</ThemedText>
      </ThemedView>
    );
  }

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <ThemedText type="title">会话</ThemedText>
          <ThemedText style={styles.muted}>
            工作区：<ThemedText type="defaultSemiBold">{active.name}</ThemedText>
          </ThemedText>
        </View>
        <Pressable
          accessibilityRole="button"
          style={[styles.button, { borderColor: Colors[colorScheme].icon }]}
          onPress={async () => {
            setLoading(true);
            setError(null);
            try {
              const s = await createSession(active.id);
              const all = await listSessions(active.id);
              setSessions(all);
              router.push(`/session/${s.id}`);
            } catch (e) {
              const message = e instanceof Error ? e.message : String(e);
              setError(message);
            } finally {
              setLoading(false);
            }
          }}>
          <ThemedText type="defaultSemiBold">新建</ThemedText>
        </Pressable>
      </View>

      {error ? (
        <ThemedText type="default" style={[styles.error, { color: '#ef4444' }]}>
          {error}
        </ThemedText>
      ) : null}

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator />
        </View>
      ) : (
        <FlatList
          data={sessions}
          keyExtractor={(s) => s.id}
          contentContainerStyle={{ paddingBottom: 24 }}
          renderItem={({ item }) => (
            <Pressable
              accessibilityRole="button"
              onPress={() => router.push(`/session/${item.id}`)}
              onLongPress={() => {
                Alert.alert('删除会话？', item.title, [
                  { text: '取消', style: 'cancel' },
                  {
                    text: '删除',
                    style: 'destructive',
                    onPress: async () => {
                      await deleteSession(active.id, item.id);
                      const all = await listSessions(active.id);
                      setSessions(all);
                    },
                  },
                ]);
              }}
              style={({ pressed }) => [
                styles.row,
                { opacity: pressed ? 0.85 : 1, borderColor: Colors[colorScheme].icon },
              ]}>
              <ThemedText type="defaultSemiBold" numberOfLines={1} style={{ flex: 1 }}>
                {item.title}
              </ThemedText>
              <ThemedText style={styles.muted}>{new Date(item.updatedAt).toLocaleDateString()}</ThemedText>
            </Pressable>
          )}
          ListEmptyComponent={
            <ThemedText style={styles.muted}>还没有会话。点击“新建”创建一个。</ThemedText>
          }
        />
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 24,
    paddingHorizontal: 16,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 16,
  },
  button: {
    minHeight: 44,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  row: {
    minHeight: 56,
    paddingVertical: 12,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderRadius: 14,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
    gap: 10,
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
