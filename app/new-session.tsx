import { Stack, useRouter } from 'expo-router';
import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ActivityIndicator, Button, Card, Checkbox, Divider, List, Text, TextInput, useTheme } from 'react-native-paper';

import { ThemedView } from '@/components/themed-view';
import { Layout, Spacing } from '@/constants/theme';
import { useMcp } from '@/src/mcp/provider';
import { isMcpServerProbablyRunnable } from '@/src/mcp/runnable';
import { createSession } from '@/src/sessions/store';
import { useWorkspaces } from '@/src/workspaces/provider';

export default function NewSessionScreen() {
  const router = useRouter();
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { workspaces, activeWorkspaceId } = useWorkspaces();
  const { loading: mcpLoading, error: mcpError, servers } = useMcp();

  const [mcpRunnable, setMcpRunnable] = useState<Record<string, boolean>>({});

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const entries = await Promise.all(
        servers.map(async (s) => [s.id, await isMcpServerProbablyRunnable(s)] as const)
      );
      if (cancelled) return;
      setMcpRunnable(Object.fromEntries(entries));
    })().catch(() => {
      if (cancelled) return;
      setMcpRunnable({});
    });
    return () => {
      cancelled = true;
    };
  }, [servers]);

  const active = useMemo(() => workspaces.find((w) => w.id === activeWorkspaceId) ?? null, [activeWorkspaceId, workspaces]);

  const [title, setTitle] = useState('');
  const [enabledIds, setEnabledIds] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setEnabledIds(active?.mcpDefaultEnabledServerIds ?? []);
  }, [active?.id, active?.mcpDefaultEnabledServerIds]);

  if (!active) {
    return (
      <ThemedView style={[styles.screen, styles.container]}>
        <Stack.Screen options={{ title: '新建会话' }} />
        <Text variant="headlineMedium">新建会话</Text>
        <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
          请先选择一个工作区。
        </Text>
      </ThemedView>
    );
  }

  const toggle = (id: string) => {
    setEnabledIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  return (
    <ThemedView style={styles.screen}>
      <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          contentContainerStyle={[
            styles.container,
            {
              paddingTop: Spacing.lg + insets.top,
              paddingBottom: Spacing.xl + insets.bottom,
            },
          ]}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag">
          <Stack.Screen options={{ title: '新建会话' }} />

          <View style={styles.header}>
            <Text variant="headlineMedium">新建会话</Text>
            <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
              工作区：<Text variant="bodyMedium" style={{ fontWeight: '600' }}>{active.name}</Text>
            </Text>
          </View>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="基本信息" />
            <Card.Content>
              <TextInput
                mode="outlined"
                label="标题（可选）"
                value={title}
                onChangeText={setTitle}
              />
              <Text variant="bodySmall" style={{ marginTop: Spacing.sm, color: theme.colors.onSurfaceVariant }}>
                不填则默认为“新会话”。
              </Text>
            </Card.Content>
          </Card>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="MCP（可选）" />
            <Card.Content>
              <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
                默认会预选当前工作区的 MCP 默认集合；你也可以在这里覆盖。
              </Text>

              <View style={{ marginTop: Spacing.md }}>
                {mcpLoading ? (
                  <View style={styles.center}>
                    <ActivityIndicator />
                  </View>
                ) : (
                  <>
                    {mcpError ? <Text style={{ color: theme.colors.error }}>{mcpError}</Text> : null}

                    {servers.length === 0 ? (
                      <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
                        暂无已登记的 MCP 服务器。你可以先到下方 Tab「MCP」里新增。
                      </Text>
                    ) : (
                      <View style={styles.list}>
                        {servers.map((s, idx) => {
                          const checked = enabledIds.includes(s.id);
                          const runnable = mcpRunnable[s.id] ?? true;
                          const disabled = !runnable && !checked;

                          return (
                            <View key={s.id}>
                              <List.Item
                                title={s.name}
                                titleNumberOfLines={1}
                                description={() => (
                                  <View style={{ gap: 2 }}>
                                    <Text variant="bodySmall" style={{ color: theme.colors.onSurfaceVariant }}>
                                      {s.transport === 'url' ? `地址：${s.url ?? ''}` : `本地：${s.command ?? ''}`}
                                    </Text>
                                    {!runnable ? (
                                      <Text variant="bodySmall" style={{ color: theme.colors.error }}>
                                        未安装/不可执行（请先在底部「MCP」里完成安装或修正启动方式）
                                      </Text>
                                    ) : null}
                                  </View>
                                )}
                                onPress={() => toggle(s.id)}
                                disabled={disabled}
                                left={() => (
                                  <Checkbox
                                    status={checked ? 'checked' : 'unchecked'}
                                    disabled={disabled}
                                    onPress={() => toggle(s.id)}
                                  />
                                )}
                              />
                              {idx < servers.length - 1 ? <Divider /> : null}
                            </View>
                          );
                        })}
                      </View>
                    )}
                  </>
                )}
              </View>
            </Card.Content>
          </Card>

          <View style={styles.actions}>
            <Button
              mode="contained"
              loading={busy}
              disabled={busy}
              onPress={async () => {
                setBusy(true);
                try {
                  const s = await createSession(active.id, title, { mcpEnabledServerIds: enabledIds });
                  router.replace(`/session/${s.id}`);
                } catch (e) {
                  const message = e instanceof Error ? e.message : String(e);
                  Alert.alert('创建失败', message);
                } finally {
                  setBusy(false);
                }
              }}>
              创建
            </Button>

            <Button mode="outlined" disabled={busy} onPress={() => router.back()}>
              取消
            </Button>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  container: {
    flexGrow: 1,
    width: '100%',
    maxWidth: Layout.maxWidthForm,
    alignSelf: 'center',
    paddingHorizontal: Spacing.lg,
  },
  header: { marginBottom: Spacing.lg },
  center: { alignItems: 'center', justifyContent: 'center', paddingVertical: Spacing.md },
  card: { marginBottom: Spacing.lg },
  list: { marginTop: Spacing.sm, borderRadius: 12, overflow: 'hidden' },
  actions: { gap: Spacing.md },
});
