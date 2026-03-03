import { useMemo } from 'react';
import { Alert, FlatList, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { ActivityIndicator, Button, Card, Chip, IconButton, List, Text, useTheme } from 'react-native-paper';

import { Layout, Spacing } from '@/constants/theme';
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
  const theme = useTheme();
  const insets = useSafeAreaInsets();
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
    <View style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <View style={[styles.container, { paddingTop: 16 + insets.top }]}>
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            <Text variant="headlineMedium" style={{ fontWeight: 'bold' }}>工作区</Text>
            <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
              当前：<Text variant="bodyMedium" style={{ fontWeight: 'bold' }}>{activeLabel}</Text>
            </Text>
          </View>
          <Button
            mode="contained"
            onPress={() => router.push('/new-workspace')}
            style={styles.button}
          >
            新建
          </Button>
          <Button
            mode="outlined"
            onPress={() => {
              if (!activeWorkspaceId) {
                Alert.alert('未选择工作区', '请先选择一个工作区。');
                return;
              }
              router.push(`/workspace/${activeWorkspaceId}`);
            }}
            style={styles.button}
          >
            设置
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
              if (item.type === 'section') {
                return (
                  <List.Subheader style={{ color: theme.colors.primary }}>
                    {item.title}
                  </List.Subheader>
                );
              }

              return (
                <Card
                  style={[
                    styles.workspaceCard,
                    {
                      backgroundColor: item.isActive ? theme.colors.secondaryContainer : theme.colors.surfaceVariant,
                    }
                  ]}
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
                >
                  <Card.Title
                    title={item.workspace.name}
                    titleVariant="titleMedium"
                    subtitle={formatDate(item.workspace.createdAt)}
                    subtitleVariant="bodySmall"
                    right={(props) => item.isActive ? (
                      <Chip icon="check" style={styles.activePill} textStyle={{ color: theme.colors.onSecondaryContainer }}>
                        当前
                      </Chip>
                    ) : (
                      <IconButton {...props} icon="chevron-right" />
                    )}
                  />
                </Card>
              );
            }}
            ListEmptyComponent={
              <Text style={{ color: theme.colors.onSurfaceVariant, textAlign: 'center', marginTop: 24 }}>
                还没有工作区。
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
  workspaceCard: {
    marginBottom: 12,
    borderRadius: 12,
  },
  activePill: {
    marginRight: 16,
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
