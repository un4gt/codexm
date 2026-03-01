import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';

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

  const cardStyle = useMemo(
    () => ({
      backgroundColor: Colors[colorScheme].surface,
      borderColor: Colors[colorScheme].outline,
    }),
    [colorScheme]
  );

  const inputStyle = useMemo(
    () => ({
      color: Colors[colorScheme].text,
      borderColor: Colors[colorScheme].outline,
      backgroundColor: Colors[colorScheme].surface2,
    }),
    [colorScheme]
  );

  const placeholderTextColor = useMemo(
    () => (colorScheme === 'dark' ? 'rgba(255,255,255,0.38)' : 'rgba(0,0,0,0.38)'),
    [colorScheme]
  );

  const rippleColor = useMemo(
    () => (colorScheme === 'dark' ? 'rgba(255,255,255,0.14)' : 'rgba(2,6,23,0.08)'),
    [colorScheme]
  );

  return (
    <ThemedView style={styles.screen}>
      <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
        <ScrollView
          contentContainerStyle={styles.container}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag">
          <View style={styles.header}>
            <View style={{ flex: 1 }}>
              <ThemedText type="title">MCP</ThemedText>
              <ThemedText style={styles.muted}>全局登记 MCP 服务器（默认不启用），可在新建会话时选择启用。</ThemedText>
            </View>
          </View>

          {loading ? (
            <View style={styles.center}>
              <ActivityIndicator />
            </View>
          ) : (
            <>
              {error ? <ThemedText style={[styles.error, { color: Colors[colorScheme].danger }]}>{error}</ThemedText> : null}

              <ThemedView style={[styles.card, cardStyle]}>
                <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
                  新增服务器
                </ThemedText>

                <View style={styles.segments}>
                  <Pressable
                    accessibilityRole="button"
                    android_ripple={{ color: rippleColor }}
                    style={({ pressed }) => [
                      styles.segment,
                      {
                        opacity: pressed ? 0.92 : 1,
                        borderColor: transport === 'url' ? Colors[colorScheme].tint : Colors[colorScheme].outline,
                        backgroundColor: transport === 'url' ? Colors[colorScheme].surface2 : 'transparent',
                      },
                    ]}
                    onPress={() => setTransport('url')}>
                    <ThemedText type="defaultSemiBold">URL</ThemedText>
                  </Pressable>
                  <Pressable
                    accessibilityRole="button"
                    android_ripple={{ color: rippleColor }}
                    style={({ pressed }) => [
                      styles.segment,
                      {
                        opacity: pressed ? 0.92 : 1,
                        borderColor: transport === 'stdio' ? Colors[colorScheme].tint : Colors[colorScheme].outline,
                        backgroundColor: transport === 'stdio' ? Colors[colorScheme].surface2 : 'transparent',
                      },
                    ]}
                    onPress={() => setTransport('stdio')}>
                    <ThemedText type="defaultSemiBold">本地</ThemedText>
                  </Pressable>
                </View>

            <TextInput
              placeholder="名称（展示用）"
              placeholderTextColor={placeholderTextColor}
              value={name}
              onChangeText={setName}
              selectionColor={Colors[colorScheme].tint}
              style={[styles.input, inputStyle]}
            />

            {transport === 'url' ? (
              <TextInput
                placeholder="URL（https://...）"
                placeholderTextColor={placeholderTextColor}
                value={url}
                onChangeText={setUrl}
                autoCapitalize="none"
                selectionColor={Colors[colorScheme].tint}
                style={[styles.input, inputStyle]}
              />
            ) : (
              <>
                <TextInput
                  placeholder="可执行文件路径（本机）"
                  placeholderTextColor={placeholderTextColor}
                  value={command}
                  onChangeText={setCommand}
                  autoCapitalize="none"
                  selectionColor={Colors[colorScheme].tint}
                  style={[styles.input, inputStyle]}
                />
                <TextInput
                  placeholder={'可选参数（每行一条）'}
                  placeholderTextColor={placeholderTextColor}
                  value={argsText}
                  onChangeText={setArgsText}
                  multiline
                  style={[
                    styles.input,
                    inputStyle,
                    { minHeight: 112, textAlignVertical: 'top' },
                  ]}
                />
                <TextInput
                  placeholder={'安装地址（可选）'}
                  placeholderTextColor={placeholderTextColor}
                  value={installUrl}
                  onChangeText={setInstallUrl}
                  autoCapitalize="none"
                  selectionColor={Colors[colorScheme].tint}
                  style={[styles.input, inputStyle]}
                />
              </>
            )}

            <Pressable
              accessibilityRole="button"
              disabled={busy}
              android_ripple={{ color: rippleColor }}
              style={({ pressed }) => [
                styles.primaryButton,
                {
                  backgroundColor: Colors[colorScheme].tint,
                  opacity: busy ? 0.6 : pressed ? 0.92 : 1,
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
              <ThemedText type="defaultSemiBold" style={{ color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }}>
                {transport === 'stdio' && installUrl.trim() ? '下载并新增' : '新增'}
              </ThemedText>
            </Pressable>

            <ThemedText style={styles.muted}>
              提示：本地类型会执行本机程序，请只添加你信任的来源。可选填“安装地址”以自动安装，也可以手动填写可执行文件路径。
              若无法启动，请尝试使用远程服务器。
            </ThemedText>
          </ThemedView>

          <ThemedView style={[styles.card, cardStyle]}>
            <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
              已添加的服务器
            </ThemedText>

            {servers.length === 0 ? <ThemedText style={styles.muted}>暂无。你可以先新增一个服务器。</ThemedText> : null}

            {servers.map((s) => {
              const isEditing = editingId === s.id;
              return (
                <View
                  key={s.id}
                  style={[
                    styles.row,
                    {
                      borderColor: Colors[colorScheme].outline,
                      backgroundColor: Colors[colorScheme].surface2,
                    },
                  ]}>
                  <View style={{ flex: 1 }}>
                    <ThemedText type="defaultSemiBold">{s.name}</ThemedText>
                    <ThemedText style={styles.muted}>
                      {s.transport === 'url' ? `地址：${s.url ?? ''}` : `路径：${s.command ?? ''}`}
                    </ThemedText>
                    <ThemedText style={styles.muted}>标识：{s.configKey}</ThemedText>
                  </View>

                  <Pressable
                    accessibilityRole="button"
                    android_ripple={{ color: rippleColor }}
                    style={({ pressed }) => [
                      styles.smallButton,
                      {
                        borderColor: Colors[colorScheme].outline,
                        backgroundColor: 'transparent',
                        opacity: pressed ? 0.92 : 1,
                      },
                    ]}
                    onPress={() => (isEditing ? stopEdit() : startEdit(s))}>
                    <ThemedText type="defaultSemiBold">{isEditing ? '取消' : '编辑'}</ThemedText>
                  </Pressable>

                  <Pressable
                    accessibilityRole="button"
                    android_ripple={{ color: rippleColor }}
                    style={({ pressed }) => [
                      styles.smallButton,
                      {
                        borderColor: Colors[colorScheme].outline,
                        backgroundColor: 'transparent',
                        opacity: pressed ? 0.92 : 1,
                      },
                    ]}
                    onPress={() => {
                      Alert.alert('删除 MCP 服务器', `确定删除「${s.name}」？`, [
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
                          android_ripple={{ color: rippleColor }}
                          style={({ pressed }) => [
                            styles.segment,
                            {
                              opacity: pressed ? 0.92 : 1,
                              borderColor: editTransport === 'url' ? Colors[colorScheme].tint : Colors[colorScheme].outline,
                              backgroundColor: editTransport === 'url' ? Colors[colorScheme].surface2 : 'transparent',
                            },
                          ]}
                          onPress={() => setEditTransport('url')}>
                          <ThemedText type="defaultSemiBold">URL</ThemedText>
                        </Pressable>
                        <Pressable
                          accessibilityRole="button"
                          android_ripple={{ color: rippleColor }}
                          style={({ pressed }) => [
                            styles.segment,
                            {
                              opacity: pressed ? 0.92 : 1,
                              borderColor: editTransport === 'stdio' ? Colors[colorScheme].tint : Colors[colorScheme].outline,
                              backgroundColor: editTransport === 'stdio' ? Colors[colorScheme].surface2 : 'transparent',
                            },
                          ]}
                          onPress={() => setEditTransport('stdio')}>
                          <ThemedText type="defaultSemiBold">本地</ThemedText>
                        </Pressable>
                      </View>

                      <TextInput
                        placeholder="名称"
                        placeholderTextColor={placeholderTextColor}
                        value={editName}
                        onChangeText={setEditName}
                        selectionColor={Colors[colorScheme].tint}
                        style={[styles.input, inputStyle]}
                      />

                      {editTransport === 'url' ? (
                        <TextInput
                          placeholder="URL（https://...）"
                          placeholderTextColor={placeholderTextColor}
                          value={editUrl}
                          onChangeText={setEditUrl}
                          autoCapitalize="none"
                          selectionColor={Colors[colorScheme].tint}
                          style={[styles.input, inputStyle]}
                        />
                      ) : (
                        <>
                          <TextInput
                            placeholder="可执行文件路径（本机）"
                            placeholderTextColor={placeholderTextColor}
                            value={editCommand}
                            onChangeText={setEditCommand}
                            autoCapitalize="none"
                            selectionColor={Colors[colorScheme].tint}
                            style={[styles.input, inputStyle]}
                          />
                          <TextInput
                            placeholder={'可选参数（每行一条）'}
                            placeholderTextColor={placeholderTextColor}
                            value={editArgsText}
                            onChangeText={setEditArgsText}
                            multiline
                            style={[
                              styles.input,
                              inputStyle,
                              { minHeight: 112, textAlignVertical: 'top' },
                            ]}
                          />
                          <TextInput
                            placeholder={'安装地址（可选）'}
                            placeholderTextColor={placeholderTextColor}
                            value={editInstallUrl}
                            onChangeText={setEditInstallUrl}
                            autoCapitalize="none"
                            selectionColor={Colors[colorScheme].tint}
                            style={[
                              styles.input,
                              inputStyle,
                            ]}
                          />
                          <View style={styles.segments}>
                             <Pressable
                               accessibilityRole="button"
                               disabled={busy}
                               android_ripple={{ color: rippleColor }}
                               style={({ pressed }) => [
                                 styles.smallButton,
                                 {
                                   borderColor: Colors[colorScheme].outline,
                                   backgroundColor: 'transparent',
                                   opacity: busy ? 0.6 : pressed ? 0.92 : 1,
                                 },
                               ]}
                               onPress={async () => {
                                 const u = editInstallUrl.trim();
                                 if (!u) return Alert.alert('缺少 URL', '请填写安装地址。');
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
                               android_ripple={{ color: rippleColor }}
                               style={({ pressed }) => [
                                 styles.smallButton,
                                 {
                                   borderColor: Colors[colorScheme].outline,
                                   backgroundColor: 'transparent',
                                   opacity: busy ? 0.6 : pressed ? 0.92 : 1,
                                 },
                               ]}
                               onPress={() => {
                                 Alert.alert('卸载本地文件', '将删除该服务器的本地安装文件，但不会删除服务器记录。', [
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
                        android_ripple={{ color: rippleColor }}
                        style={({ pressed }) => [
                          styles.secondaryButton,
                          {
                            borderColor: Colors[colorScheme].outline,
                            backgroundColor: Colors[colorScheme].surface,
                            opacity: pressed ? 0.92 : 1,
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
    maxWidth: 720,
    alignSelf: 'center',
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 32,
  },
  header: { alignItems: 'flex-start', flexDirection: 'row', gap: 12, marginBottom: 16 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  muted: { opacity: 0.8 },
  error: { marginBottom: 12 },
  card: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 16,
    padding: 16,
    marginBottom: 14,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  row: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 12,
    marginBottom: 10,
    flexDirection: 'row',
    gap: 10,
    flexWrap: 'wrap',
    alignItems: 'flex-start',
    overflow: 'hidden',
  },
  segments: { flexDirection: 'row', gap: 10, marginBottom: 10, flexWrap: 'wrap' },
  segment: {
    flex: 1,
    borderRadius: 999,
    borderWidth: 1,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  input: {
    borderWidth: 1,
    borderRadius: 12,
    minHeight: 48,
    fontSize: 16,
    lineHeight: 20,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 12,
  },
  primaryButton: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 12,
    minHeight: 48,
    paddingHorizontal: 16,
    overflow: 'hidden',
  },
  secondaryButton: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 12,
    minHeight: 48,
    paddingHorizontal: 16,
    borderWidth: 1,
    marginTop: 8,
    overflow: 'hidden',
  },
  smallButton: {
    borderWidth: 1,
    borderRadius: 12,
    minHeight: 44,
    paddingHorizontal: 12,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
});
