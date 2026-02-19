import { useMemo } from 'react';
import { ActivityIndicator, Alert, FlatList, Pressable, StyleSheet, View } from 'react-native';

import { useRouter } from 'expo-router';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useWorkspaces } from '@/src/workspaces/provider';

function formatDate(ms: number) {
  try {
    return new Date(ms).toLocaleString();
  } catch {
    return String(ms);
  }
}

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

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <ThemedText type="title">工作区</ThemedText>
          <ThemedText type="default" style={styles.muted}>
            当前：<ThemedText type="defaultSemiBold">{activeLabel}</ThemedText>
          </ThemedText>
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/new-workspace')}
          style={({ pressed }) => [
            styles.headerButton,
            { opacity: pressed ? 0.7 : 1, borderColor: Colors[colorScheme].icon },
          ]}>
          <ThemedText type="defaultSemiBold">新建</ThemedText>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            if (!activeWorkspaceId) {
              Alert.alert('未选择工作区', '请先选择一个工作区。');
              return;
            }
            router.push(`/workspace/${activeWorkspaceId}`);
          }}
          style={({ pressed }) => [
            styles.headerButton,
            { opacity: pressed ? 0.7 : 1, borderColor: Colors[colorScheme].icon },
          ]}>
          <ThemedText type="defaultSemiBold">设置</ThemedText>
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
          data={workspaces}
          keyExtractor={(w) => w.id}
          contentContainerStyle={{ paddingBottom: 24 }}
          renderItem={({ item }) => {
            const isActive = item.id === activeWorkspaceId;
            return (
              <Pressable
                accessibilityRole="button"
                onPress={async () => {
                  await setActive(item.id);
                }}
                onLongPress={() => {
                  Alert.alert(item.name, '请选择操作', [
                    { text: '取消', style: 'cancel' },
                    { text: '设置', onPress: () => router.push(`/workspace/${item.id}`) },
                    { text: '删除', style: 'destructive', onPress: async () => remove(item.id) },
                  ]);
                }}
                style={({ pressed }) => [
                  styles.row,
                  {
                    opacity: pressed ? 0.8 : 1,
                    borderColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.10)',
                    backgroundColor: isActive
                      ? colorScheme === 'dark'
                        ? 'rgba(59,130,246,0.18)'
                        : 'rgba(59,130,246,0.10)'
                      : 'transparent',
                  },
                ]}>
                <View style={{ flex: 1 }}>
                  <ThemedText type="defaultSemiBold">{item.name}</ThemedText>
                  <ThemedText type="default" style={styles.muted}>
                    {formatDate(item.createdAt)}
                  </ThemedText>
                </View>
                <ThemedText type="default" style={styles.muted}>
                  {isActive ? '当前' : ' '}
                </ThemedText>
              </Pressable>
            );
          }}
          ListEmptyComponent={
            <ThemedText type="default" style={styles.muted}>
              还没有工作区。可以在上方创建一个。
            </ThemedText>
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
  headerButton: {
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderRadius: 10,
  },
  card: {
    borderWidth: 1,
    borderRadius: 14,
    padding: 12,
    marginBottom: 16,
  },
  input: {
    borderWidth: 1,
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 12,
    fontSize: 16,
    marginBottom: 10,
  },
  primaryButton: {
    minHeight: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
  },
  primaryButtonText: {
    color: '#ffffff',
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
