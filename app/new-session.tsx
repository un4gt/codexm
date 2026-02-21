import { Stack, useRouter } from 'expo-router';
import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, StyleSheet, TextInput, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useMcp } from '@/src/mcp/provider';
import { isMcpServerProbablyRunnable } from '@/src/mcp/runnable';
import { createSession } from '@/src/sessions/store';
import { useWorkspaces } from '@/src/workspaces/provider';

export default function NewSessionScreen() {
  const router = useRouter();
  const colorScheme = useColorScheme() ?? 'light';
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
  }, [active?.id]);

  if (!active) {
    return (
      <ThemedView style={styles.container}>
        <Stack.Screen options={{ title: '新建会话' }} />
        <ThemedText type="title">新建会话</ThemedText>
        <ThemedText style={styles.muted}>请先选择一个工作区。</ThemedText>
      </ThemedView>
    );
  }

  const toggle = (id: string) => {
    setEnabledIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: '新建会话' }} />

      <View style={styles.header}>
        <ThemedText type="title">新建会话</ThemedText>
        <ThemedText style={styles.muted}>
          工作区：<ThemedText type="defaultSemiBold">{active.name}</ThemedText>
        </ThemedText>
      </View>

      <ThemedView style={[styles.card, { borderColor: Colors[colorScheme].icon }]}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          基本信息
        </ThemedText>
        <TextInput
          placeholder="标题（可选）"
          placeholderTextColor={Colors[colorScheme].icon}
          value={title}
          onChangeText={setTitle}
          style={[styles.input, { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon }]}
        />
        <ThemedText style={styles.muted}>不填则默认为“新会话”。</ThemedText>
      </ThemedView>

      <ThemedView style={[styles.card, { borderColor: Colors[colorScheme].icon }]}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          MCP（可选）
        </ThemedText>
        <ThemedText style={styles.muted}>默认会预选当前工作区的 MCP 默认集合；你也可以在这里覆盖。</ThemedText>

        {mcpLoading ? (
          <View style={styles.center}>
            <ActivityIndicator />
          </View>
        ) : (
          <>
            {mcpError ? <ThemedText style={[styles.error, { color: '#ef4444' }]}>{mcpError}</ThemedText> : null}
            {servers.length === 0 ? (
              <ThemedText style={styles.muted}>暂无已登记的 MCP 服务器。你可以先到下方 Tab「MCP」里新增。</ThemedText>
            ) : (
              <View style={{ marginTop: 10 }}>
                {servers.map((s) => {
                  const checked = enabledIds.includes(s.id);
                  const runnable = mcpRunnable[s.id] ?? true;
                  return (
                    <Pressable
                      key={s.id}
                      accessibilityRole="button"
                      disabled={!runnable && !checked}
                      style={[
                        styles.row,
                        {
                          borderColor: Colors[colorScheme].icon,
                          backgroundColor: checked
                            ? colorScheme === 'dark'
                              ? 'rgba(255,255,255,0.06)'
                              : 'rgba(0,0,0,0.06)'
                            : 'transparent',
                          opacity: !runnable && !checked ? 0.6 : 1,
                        },
                      ]}
                      onPress={() => toggle(s.id)}>
                      <View style={styles.checkbox}>
                        <ThemedText type="defaultSemiBold">{checked ? '✓' : ''}</ThemedText>
                      </View>
                      <View style={{ flex: 1 }}>
                        <ThemedText type="defaultSemiBold">{s.name}</ThemedText>
                        <ThemedText style={styles.muted}>
                          {s.transport === 'url' ? `地址：${s.url ?? ''}` : `路径：${s.command ?? ''}`}
                        </ThemedText>
                        {!runnable ? (
                          <ThemedText style={[styles.muted, { color: '#ef4444' }]}>
                            未安装/不可执行（请先在底部「MCP」里安装或修正 command）
                          </ThemedText>
                        ) : null}
                      </View>
                    </Pressable>
                  );
                })}
              </View>
            )}
          </>
        )}
      </ThemedView>

      <Pressable
        accessibilityRole="button"
        disabled={busy}
        style={[
          styles.primaryButton,
          {
            backgroundColor: Colors[colorScheme].tint,
            opacity: busy ? 0.7 : 1,
          },
        ]}
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
        <ThemedText type="defaultSemiBold" style={{ color: '#fff' }}>
          创建
        </ThemedText>
      </Pressable>

      <Pressable
        accessibilityRole="button"
        disabled={busy}
        style={[
          styles.secondaryButton,
          { borderColor: Colors[colorScheme].icon, opacity: busy ? 0.7 : 1, backgroundColor: 'transparent' },
        ]}
        onPress={() => router.back()}>
        <ThemedText type="defaultSemiBold">取消</ThemedText>
      </Pressable>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, paddingHorizontal: 16, paddingTop: 16 },
  header: { marginBottom: 12 },
  center: { alignItems: 'center', justifyContent: 'center', paddingVertical: 12 },
  muted: { opacity: 0.8 },
  error: { marginTop: 10 },
  card: { borderWidth: 1, borderRadius: 14, padding: 14, marginBottom: 12 },
  input: { borderWidth: 1, borderRadius: 12, fontSize: 16, paddingHorizontal: 12, paddingVertical: 10, marginBottom: 10 },
  row: {
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 10,
    flexDirection: 'row',
    gap: 10,
    alignItems: 'center',
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryButton: { alignItems: 'center', justifyContent: 'center', borderRadius: 12, minHeight: 44, paddingHorizontal: 12 },
  secondaryButton: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 12,
    minHeight: 44,
    paddingHorizontal: 12,
    borderWidth: 1,
    marginTop: 10,
  },
});
