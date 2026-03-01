import { useMemo } from 'react';
import { ActivityIndicator, Alert, FlatList, Pressable, StyleSheet, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';

import { useRouter } from 'expo-router';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useWorkspaces } from '@/src/workspaces/provider';
import type { Workspace } from '@/src/workspaces/types';

function formatDate(ms: number) {
  try {
    return new Date(ms).toLocaleString();
  } catch {
    return String(ms);
  }
}

type WorkspaceListItem =
  | { type: 'section'; id: string; title: string }
  | { type: 'workspace'; id: string; workspace: Workspace; isActive: boolean };

export default function WorkspacesScreen() {
  const router = useRouter();
  const colorScheme = useColorScheme() ?? 'light';
  const {
    loading,
    error,
    workspaces,
    activeWorkspaceId,
    setActive,
    remove,
  } = useWorkspaces();

  const activeLabel = useMemo(() => {
    const active = workspaces.find((w) => w.id === activeWorkspaceId);
    return active ? active.name : '未选择';
  }, [activeWorkspaceId, workspaces]);

  const rippleColor = useMemo(
    () => (colorScheme === 'dark' ? 'rgba(255,255,255,0.14)' : 'rgba(2,6,23,0.08)'),
    [colorScheme]
  );

  const listItems = useMemo<WorkspaceListItem[]>(() => {
    const active = workspaces.find((w) => w.id === activeWorkspaceId) ?? null;
    const others = workspaces.filter((w) => w.id !== activeWorkspaceId);

    const items: WorkspaceListItem[] = [];
    if (active) {
      items.push({ type: 'section', id: 'sec-active', title: '当前' });
      items.push({ type: 'workspace', id: active.id, workspace: active, isActive: true });
    }
    if (others.length > 0) {
      items.push({ type: 'section', id: 'sec-others', title: active ? '其他' : '工作区' });
      for (const w of others) items.push({ type: 'workspace', id: w.id, workspace: w, isActive: false });
    }
    return items;
  }, [activeWorkspaceId, workspaces]);

  return (
    <ThemedView style={styles.screen}>
      <View style={styles.container}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <ThemedText type="title">工作区</ThemedText>
          <ThemedText type="default" style={styles.muted}>
            当前：<ThemedText type="defaultSemiBold">{activeLabel}</ThemedText>
          </ThemedText>
        </View>
        <Pressable
          accessibilityRole="button"
          android_ripple={{ color: rippleColor }}
          onPress={() => router.push('/new-workspace')}
          style={({ pressed }) => [
            styles.primaryButton,
            { opacity: pressed ? 0.9 : 1, backgroundColor: Colors[colorScheme].tint },
          ]}>
          <ThemedText type="defaultSemiBold" style={{ color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }}>
            新建
          </ThemedText>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          android_ripple={{ color: rippleColor }}
          onPress={() => {
            if (!activeWorkspaceId) {
              Alert.alert('未选择工作区', '请先选择一个工作区。');
              return;
            }
            router.push(`/workspace/${activeWorkspaceId}`);
          }}
          style={({ pressed }) => [
            styles.secondaryButton,
            {
              opacity: pressed ? 0.92 : 1,
              borderColor: Colors[colorScheme].outline,
              backgroundColor: Colors[colorScheme].surface,
            },
          ]}>
          <ThemedText type="defaultSemiBold">设置</ThemedText>
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
            if (item.type === 'section') {
              return (
                <ThemedText type="default" style={[styles.sectionTitle, { color: Colors[colorScheme].icon }]}>
                  {item.title}
                </ThemedText>
              );
            }

            const prev = listItems[index - 1];
            const next = listItems[index + 1];
            const isFirst = prev?.type === 'section' || prev == null;
            const isLast = next?.type === 'section' || next == null;
            const isSingle = isFirst && isLast;

            const activeBg = colorScheme === 'dark' ? 'rgba(34,211,238,0.16)' : 'rgba(10,126,164,0.12)';

            return (
              <Pressable
                accessibilityRole="button"
                android_ripple={{ color: rippleColor }}
                onPress={async () => {
                  await setActive(item.workspace.id);
                }}
                onLongPress={() => {
                  Alert.alert(item.workspace.name, '请选择操作', [
                    { text: '取消', style: 'cancel' },
                    { text: '设置', onPress: () => router.push(`/workspace/${item.workspace.id}`) },
                    { text: '删除', style: 'destructive', onPress: async () => remove(item.workspace.id) },
                  ]);
                }}
                style={({ pressed }) => [
                  styles.workspaceCard,
                  !isFirst && styles.workspaceCardNotFirst,
                  isSingle
                    ? styles.workspaceCardSingle
                    : isFirst
                      ? styles.workspaceCardFirst
                      : isLast
                        ? styles.workspaceCardLast
                        : undefined,
                  {
                    opacity: pressed ? 0.92 : 1,
                    borderColor: Colors[colorScheme].outline,
                    backgroundColor: item.isActive ? activeBg : Colors[colorScheme].surface,
                  },
                ]}>
                <View style={{ flex: 1 }}>
                  <ThemedText type="defaultSemiBold" numberOfLines={1} style={{ marginBottom: 2 }}>
                    {item.workspace.name}
                  </ThemedText>
                  <ThemedText type="default" style={styles.muted} numberOfLines={1}>
                    {formatDate(item.workspace.createdAt)}
                  </ThemedText>
                </View>

                {item.isActive ? (
                  <View
                    style={[
                      styles.activePill,
                      {
                        backgroundColor: Colors[colorScheme].surface2,
                        borderColor: Colors[colorScheme].outlineMuted,
                      },
                    ]}>
                    <MaterialIcons name="check" size={16} color={Colors[colorScheme].tint} />
                    <ThemedText type="defaultSemiBold" style={{ color: Colors[colorScheme].tint }}>
                      当前
                    </ThemedText>
                  </View>
                ) : (
                  <MaterialIcons name="chevron-right" size={20} color={Colors[colorScheme].icon} />
                )}
              </Pressable>
            );
          }}
          ListEmptyComponent={
            <ThemedText type="default" style={styles.muted}>
              还没有工作区。
            </ThemedText>
          }
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
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    overflow: 'hidden',
  },
  secondaryButton: {
    minHeight: 44,
    borderRadius: 12,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    overflow: 'hidden',
  },
  sectionTitle: {
    marginTop: 14,
    marginBottom: 8,
    fontSize: 13,
    letterSpacing: 0.2,
    opacity: 0.85,
  },
  workspaceCard: {
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
  workspaceCardNotFirst: {
    marginTop: -1,
  },
  workspaceCardFirst: {
    borderTopLeftRadius: 14,
    borderTopRightRadius: 14,
  },
  workspaceCardLast: {
    borderBottomLeftRadius: 14,
    borderBottomRightRadius: 14,
    marginBottom: 12,
  },
  workspaceCardSingle: {
    borderRadius: 14,
    marginBottom: 12,
  },
  activePill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    borderWidth: 1,
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
