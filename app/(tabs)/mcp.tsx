import React, { useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, StyleSheet, TextInput, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useMcp } from '@/src/mcp/provider';
import { installManagedMcpFromUrl, uninstallManagedMcp } from '@/src/mcp/installer';
import type { McpServer } from '@/src/mcp/types';
import { uuidV4 } from '@/src/utils/uuid';

type Transport = McpServer['transport'];

function parseArgsText(v: string) {
  const lines = v
    .split('\n')
    .map((x) => x.trim())
    .filter(Boolean);
  return lines;
}

export default function McpScreen() {
  const colorScheme = useColorScheme() ?? 'light';
  const { loading, error, servers, add, update, remove } = useMcp();

  const [transport, setTransport] = useState<Transport>('url');
  const [name, setName] = useState('');
  const [url, setUrl] = useState('');
  const [command, setCommand] = useState('');
  const [argsText, setArgsText] = useState('');
  const [installUrl, setInstallUrl] = useState('');
  const [busy, setBusy] = useState(false);

  const [editingId, setEditingId] = useState<string | null>(null);
  const editing = useMemo(() => servers.find((s) => s.id === editingId) ?? null, [editingId, servers]);
  const [editTransport, setEditTransport] = useState<Transport>('url');
  const [editName, setEditName] = useState('');
  const [editUrl, setEditUrl] = useState('');
  const [editCommand, setEditCommand] = useState('');
  const [editArgsText, setEditArgsText] = useState('');
  const [editInstallUrl, setEditInstallUrl] = useState('');

  const startEdit = (s: McpServer) => {
    setEditingId(s.id);
    setEditTransport(s.transport);
    setEditName(s.name);
    setEditUrl(s.url ?? '');
    setEditCommand(s.command ?? '');
    setEditArgsText(Array.isArray(s.args) ? s.args.join('\n') : '');
    setEditInstallUrl('');
  };

  const stopEdit = () => {
    setEditingId(null);
    setEditTransport('url');
    setEditName('');
    setEditUrl('');
    setEditCommand('');
    setEditArgsText('');
    setEditInstallUrl('');
  };

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <ThemedText type="title">MCP</ThemedText>
          <ThemedText style={styles.muted}>全局登记 MCP Server（默认不启用），可在新建会话时选择启用。</ThemedText>
        </View>
      </View>

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator />
        </View>
      ) : (
        <>
          {error ? <ThemedText style={[styles.error, { color: '#ef4444' }]}>{error}</ThemedText> : null}

          <ThemedView style={[styles.card, { borderColor: Colors[colorScheme].icon }]}>
            <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
              新增 Server
            </ThemedText>

            <View style={styles.segments}>
              <Pressable
                accessibilityRole="button"
                style={[
                  styles.segment,
                  {
                    borderColor: Colors[colorScheme].icon,
                    backgroundColor:
                      transport === 'url'
                        ? colorScheme === 'dark'
                          ? 'rgba(255,255,255,0.06)'
                          : 'rgba(0,0,0,0.06)'
                        : 'transparent',
                  },
                ]}
                onPress={() => setTransport('url')}>
                <ThemedText type="defaultSemiBold">URL</ThemedText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                style={[
                  styles.segment,
                  {
                    borderColor: Colors[colorScheme].icon,
                    backgroundColor:
                      transport === 'stdio'
                        ? colorScheme === 'dark'
                          ? 'rgba(255,255,255,0.06)'
                          : 'rgba(0,0,0,0.06)'
                        : 'transparent',
                  },
                ]}
                onPress={() => setTransport('stdio')}>
                <ThemedText type="defaultSemiBold">stdio</ThemedText>
              </Pressable>
            </View>

            <TextInput
              placeholder="名称（展示用）"
              placeholderTextColor={Colors[colorScheme].icon}
              value={name}
              onChangeText={setName}
              style={[styles.input, { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon }]}
            />

            {transport === 'url' ? (
              <TextInput
                placeholder="URL（https://...）"
                placeholderTextColor={Colors[colorScheme].icon}
                value={url}
                onChangeText={setUrl}
                autoCapitalize="none"
                style={[styles.input, { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon }]}
              />
            ) : (
              <>
                <TextInput
                  placeholder="command（本机可执行文件路径）"
                  placeholderTextColor={Colors[colorScheme].icon}
                  value={command}
                  onChangeText={setCommand}
                  autoCapitalize="none"
                  style={[styles.input, { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon }]}
                />
                <TextInput
                  placeholder={'args（每行一个参数，可选）\n例如：--foo\nbar'}
                  placeholderTextColor={Colors[colorScheme].icon}
                  value={argsText}
                  onChangeText={setArgsText}
                  multiline
                  style={[
                    styles.input,
                    { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon, minHeight: 96 },
                  ]}
                />
                <TextInput
                  placeholder={'安装包 URL（.tar.gz/.tgz 或直接二进制，可选）'}
                  placeholderTextColor={Colors[colorScheme].icon}
                  value={installUrl}
                  onChangeText={setInstallUrl}
                  autoCapitalize="none"
                  style={[styles.input, { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon }]}
                />
              </>
            )}

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
                  let id: string | undefined = undefined;
                  let resolvedCommand = command;
                  const installUrlTrimmed = installUrl.trim();

                  if (transport === 'stdio' && installUrlTrimmed) {
                    id = uuidV4();
                    try {
                      const installed = await installManagedMcpFromUrl(id, installUrlTrimmed);
                      resolvedCommand = installed.execPath;
                    } catch (e) {
                      await uninstallManagedMcp(id);
                      throw e;
                    }
                  }

                  try {
                    await add({
                      id,
                      kind: 'rmcp',
                      name,
                      transport,
                      url: transport === 'url' ? url : undefined,
                      command: transport === 'stdio' ? resolvedCommand : undefined,
                      args: transport === 'stdio' ? parseArgsText(argsText) : undefined,
                    });
                  } catch (e) {
                    if (id && transport === 'stdio' && installUrlTrimmed) {
                      try {
                        await uninstallManagedMcp(id);
                      } catch {
                        // ignore
                      }
                    }
                    throw e;
                  }
                  setName('');
                  setUrl('');
                  setCommand('');
                  setArgsText('');
                  setInstallUrl('');
                } catch (e) {
                  const message = e instanceof Error ? e.message : String(e);
                  Alert.alert('新增失败', message);
                } finally {
                  setBusy(false);
                }
              }}>
              <ThemedText type="defaultSemiBold" style={{ color: '#fff' }}>
                {transport === 'stdio' && installUrl.trim() ? '下载并新增' : '新增'}
              </ThemedText>
            </Pressable>

            <ThemedText style={styles.muted}>
              提示：stdio 类型会在启动 Codex 时执行本机命令，请仅添加你信任的可执行文件。对于 Rust-based 本地 MCP，你可以先运行时安装
              （下载 `.tar.gz`/二进制）后自动填入 command，或手动填写可执行文件的绝对路径。注意：部分 Android 设备可能限制从应用可写目录
              执行下载的 ELF；如遇 Permission denied，请改用远程 MCP 或在你的运行环境中放开限制。
            </ThemedText>
          </ThemedView>

          <ThemedView style={[styles.card, { borderColor: Colors[colorScheme].icon }]}>
            <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
              已登记的 Servers
            </ThemedText>

            {servers.length === 0 ? (
              <ThemedText style={styles.muted}>暂无。你可以先新增一个 URL 或 stdio Server。</ThemedText>
            ) : null}

            {servers.map((s) => {
              const isEditing = editingId === s.id;
              return (
                <View
                  key={s.id}
                  style={[
                    styles.row,
                    {
                      borderColor: Colors[colorScheme].icon,
                      backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.02)',
                    },
                  ]}>
                  <View style={{ flex: 1 }}>
                    <ThemedText type="defaultSemiBold">{s.name}</ThemedText>
                    <ThemedText style={styles.muted}>
                      {s.transport === 'url' ? `url: ${s.url ?? ''}` : `command: ${s.command ?? ''}`}
                    </ThemedText>
                    <ThemedText style={styles.muted}>configKey: {s.configKey}</ThemedText>
                  </View>

                  <Pressable
                    accessibilityRole="button"
                    style={[
                      styles.smallButton,
                      { borderColor: Colors[colorScheme].icon, backgroundColor: 'transparent' },
                    ]}
                    onPress={() => (isEditing ? stopEdit() : startEdit(s))}>
                    <ThemedText type="defaultSemiBold">{isEditing ? '取消' : '编辑'}</ThemedText>
                  </Pressable>

                  <Pressable
                    accessibilityRole="button"
                    style={[
                      styles.smallButton,
                      { borderColor: Colors[colorScheme].icon, backgroundColor: 'transparent' },
                    ]}
                    onPress={() => {
                      Alert.alert('删除 MCP Server', `确定删除「${s.name}」？`, [
                        { text: '取消', style: 'cancel' },
                        {
                          text: '删除',
                          style: 'destructive',
                          onPress: async () => {
                            try {
                              await uninstallManagedMcp(s.id);
                              await remove(s.id);
                              if (editingId === s.id) stopEdit();
                            } catch (e) {
                              const message = e instanceof Error ? e.message : String(e);
                              Alert.alert('删除失败', message);
                            }
                          },
                        },
                      ]);
                    }}>
                    <ThemedText type="defaultSemiBold">删除</ThemedText>
                  </Pressable>

                  {isEditing && editing ? (
                    <View style={{ width: '100%', marginTop: 12 }}>
                      <View style={styles.segments}>
                        <Pressable
                          accessibilityRole="button"
                          style={[
                            styles.segment,
                            {
                              borderColor: Colors[colorScheme].icon,
                              backgroundColor:
                                editTransport === 'url'
                                  ? colorScheme === 'dark'
                                    ? 'rgba(255,255,255,0.06)'
                                    : 'rgba(0,0,0,0.06)'
                                  : 'transparent',
                            },
                          ]}
                          onPress={() => setEditTransport('url')}>
                          <ThemedText type="defaultSemiBold">URL</ThemedText>
                        </Pressable>
                        <Pressable
                          accessibilityRole="button"
                          style={[
                            styles.segment,
                            {
                              borderColor: Colors[colorScheme].icon,
                              backgroundColor:
                                editTransport === 'stdio'
                                  ? colorScheme === 'dark'
                                    ? 'rgba(255,255,255,0.06)'
                                    : 'rgba(0,0,0,0.06)'
                                  : 'transparent',
                            },
                          ]}
                          onPress={() => setEditTransport('stdio')}>
                          <ThemedText type="defaultSemiBold">stdio</ThemedText>
                        </Pressable>
                      </View>

                      <TextInput
                        placeholder="名称"
                        placeholderTextColor={Colors[colorScheme].icon}
                        value={editName}
                        onChangeText={setEditName}
                        style={[styles.input, { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon }]}
                      />

                      {editTransport === 'url' ? (
                        <TextInput
                          placeholder="URL（https://...）"
                          placeholderTextColor={Colors[colorScheme].icon}
                          value={editUrl}
                          onChangeText={setEditUrl}
                          autoCapitalize="none"
                          style={[
                            styles.input,
                            { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon },
                          ]}
                        />
                      ) : (
                        <>
                          <TextInput
                            placeholder="command"
                            placeholderTextColor={Colors[colorScheme].icon}
                            value={editCommand}
                            onChangeText={setEditCommand}
                            autoCapitalize="none"
                            style={[
                              styles.input,
                              { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon },
                            ]}
                          />
                          <TextInput
                            placeholder={'args（每行一个参数，可选）'}
                            placeholderTextColor={Colors[colorScheme].icon}
                            value={editArgsText}
                            onChangeText={setEditArgsText}
                            multiline
                            style={[
                              styles.input,
                              { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon, minHeight: 96 },
                            ]}
                          />
                          <TextInput
                            placeholder={'安装包 URL（.tar.gz/.tgz 或直接二进制）'}
                            placeholderTextColor={Colors[colorScheme].icon}
                            value={editInstallUrl}
                            onChangeText={setEditInstallUrl}
                            autoCapitalize="none"
                            style={[
                              styles.input,
                              { color: Colors[colorScheme].text, borderColor: Colors[colorScheme].icon },
                            ]}
                          />
                          <View style={styles.segments}>
                            <Pressable
                              accessibilityRole="button"
                              disabled={busy}
                              style={[
                                styles.smallButton,
                                { borderColor: Colors[colorScheme].icon, backgroundColor: 'transparent', opacity: busy ? 0.7 : 1 },
                              ]}
                              onPress={async () => {
                                const u = editInstallUrl.trim();
                                if (!u) return Alert.alert('缺少 URL', '请填写安装包 URL（.tar.gz/.tgz 或直接二进制）。');
                                setBusy(true);
                                try {
                                  const installed = await installManagedMcpFromUrl(s.id, u);
                                  setEditCommand(installed.execPath);
                                  await update(s.id, {
                                    name: editName,
                                    transport: 'stdio',
                                    command: installed.execPath,
                                    args: parseArgsText(editArgsText),
                                  });
                                  setEditInstallUrl('');
                                } catch (e) {
                                  const message = e instanceof Error ? e.message : String(e);
                                  Alert.alert('安装失败', message);
                                } finally {
                                  setBusy(false);
                                }
                              }}>
                              <ThemedText type="defaultSemiBold">下载并安装</ThemedText>
                            </Pressable>
                            <Pressable
                              accessibilityRole="button"
                              disabled={busy}
                              style={[
                                styles.smallButton,
                                { borderColor: Colors[colorScheme].icon, backgroundColor: 'transparent', opacity: busy ? 0.7 : 1 },
                              ]}
                              onPress={() => {
                                Alert.alert('卸载本地文件', '将删除该 Server 的本地安装文件，但不会删除 Server 登记。', [
                                  { text: '取消', style: 'cancel' },
                                  {
                                    text: '卸载',
                                    style: 'destructive',
                                    onPress: () => {
                                      setBusy(true);
                                      uninstallManagedMcp(s.id)
                                        .then(() => Alert.alert('已卸载', '本地文件已删除。'))
                                        .catch((e) => {
                                          const message = e instanceof Error ? e.message : String(e);
                                          Alert.alert('卸载失败', message);
                                        })
                                        .finally(() => setBusy(false));
                                    },
                                  },
                                ]);
                              }}>
                              <ThemedText type="defaultSemiBold">卸载</ThemedText>
                            </Pressable>
                          </View>
                        </>
                      )}

                      <Pressable
                        accessibilityRole="button"
                        style={[
                          styles.secondaryButton,
                          {
                            borderColor: Colors[colorScheme].icon,
                            backgroundColor: 'transparent',
                          },
                        ]}
                        onPress={async () => {
                          try {
                            await update(s.id, {
                              name: editName,
                              transport: editTransport,
                              url: editTransport === 'url' ? editUrl : undefined,
                              command: editTransport === 'stdio' ? editCommand : undefined,
                              args: editTransport === 'stdio' ? parseArgsText(editArgsText) : undefined,
                            });
                            stopEdit();
                          } catch (e) {
                            const message = e instanceof Error ? e.message : String(e);
                            Alert.alert('保存失败', message);
                          }
                        }}>
                        <ThemedText type="defaultSemiBold">保存</ThemedText>
                      </Pressable>
                    </View>
                  ) : null}
                </View>
              );
            })}
          </ThemedView>
        </>
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, paddingHorizontal: 16, paddingTop: 16 },
  header: { alignItems: 'flex-start', flexDirection: 'row', gap: 12, marginBottom: 12 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  muted: { opacity: 0.8 },
  error: { marginBottom: 12 },
  card: { borderWidth: 1, borderRadius: 14, padding: 14, marginBottom: 12 },
  row: {
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 10,
    flexDirection: 'row',
    gap: 10,
    flexWrap: 'wrap',
    alignItems: 'flex-start',
  },
  segments: { flexDirection: 'row', gap: 10, marginBottom: 10 },
  segment: { flex: 1, borderRadius: 10, borderWidth: 1, minHeight: 36, alignItems: 'center', justifyContent: 'center' },
  input: { borderWidth: 1, borderRadius: 12, fontSize: 16, paddingHorizontal: 12, paddingVertical: 10, marginBottom: 10 },
  primaryButton: { alignItems: 'center', justifyContent: 'center', borderRadius: 12, minHeight: 44, paddingHorizontal: 12 },
  secondaryButton: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 12,
    minHeight: 44,
    paddingHorizontal: 12,
    borderWidth: 1,
    marginTop: 8,
  },
  smallButton: {
    borderWidth: 1,
    borderRadius: 10,
    minHeight: 34,
    paddingHorizontal: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
