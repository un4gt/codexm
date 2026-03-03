import React, { useMemo, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ActivityIndicator, Button, Card, SegmentedButtons, Text, TextInput, useTheme } from 'react-native-paper';

import { ThemedView } from '@/components/themed-view';
import { Layout, Spacing } from '@/constants/theme';
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
  const theme = useTheme();
  const insets = useSafeAreaInsets();
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
          <View style={styles.header}>
            <View style={{ flex: 1 }}>
              <Text variant="headlineMedium">MCP</Text>
              <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
                全局登记 MCP 服务器（默认不启用），可在新建会话时选择启用。
              </Text>
            </View>
          </View>

          {loading ? (
            <View style={styles.center}>
              <ActivityIndicator />
            </View>
          ) : (
            <>
              {error ? <Text style={[styles.error, { color: theme.colors.error }]}>{error}</Text> : null}

              <Card style={styles.card} mode="elevated">
                <Card.Title title="新增服务器" />
                <Card.Content>
                  <SegmentedButtons
                    value={transport}
                    onValueChange={(v) => setTransport(v as Transport)}
                    buttons={[
                      { value: 'url', label: 'URL' },
                      { value: 'stdio', label: '本地' },
                    ]}
                  />

                  <View style={styles.formGap} />

                  <TextInput
                    mode="outlined"
                    label="名称"
                    value={name}
                    onChangeText={setName}
                  />

                  <View style={styles.formGap} />

                  {transport === 'url' ? (
                    <TextInput
                      mode="outlined"
                      label="URL"
                      placeholder="https://…"
                      value={url}
                      onChangeText={setUrl}
                      autoCapitalize="none"
                    />
                  ) : (
                    <>
                      <TextInput
                        mode="outlined"
                        label="可执行文件位置"
                        value={command}
                        onChangeText={setCommand}
                        autoCapitalize="none"
                      />

                      <View style={styles.formGap} />

                      <TextInput
                        mode="outlined"
                        label="参数（每行一条）"
                        value={argsText}
                        onChangeText={setArgsText}
                        multiline
                        numberOfLines={4}
                      />

                      <View style={styles.formGap} />

                      <TextInput
                        mode="outlined"
                        label="安装地址（可选）"
                        value={installUrl}
                        onChangeText={setInstallUrl}
                        autoCapitalize="none"
                      />
                    </>
                  )}

                  <View style={styles.formGap} />

                  <Button
                    mode="contained"
                    loading={busy}
                    disabled={busy}
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
                    {transport === 'stdio' && installUrl.trim() ? '下载并新增' : '新增'}
                  </Button>

                  <Text variant="bodySmall" style={{ marginTop: Spacing.sm, color: theme.colors.onSurfaceVariant }}>
                    提示：本地类型会执行本机程序，请只添加你信任的来源。可选填“安装地址”以自动安装，也可以手动填写可执行文件位置。若无法启动，请尝试使用远程服务器。
                  </Text>
                </Card.Content>
              </Card>

              <Text variant="titleLarge" style={styles.sectionTitle}>
                已添加的服务器
              </Text>

              {servers.length === 0 ? (
                <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
                  暂无。你可以先新增一个服务器。
                </Text>
              ) : null}

              {servers.map((s) => {
                const isEditing = editingId === s.id;
                return (
                  <Card key={s.id} style={styles.serverCard} mode="elevated">
                    <Card.Title
                      title={s.name}
                      subtitle={s.transport === 'url' ? (s.url ?? '') : (s.command ?? '')}
                      subtitleVariant="bodySmall"
                      titleVariant="titleMedium"
                    />

                    <Card.Content>
                      <Text variant="bodySmall" style={{ color: theme.colors.onSurfaceVariant }}>
                        {s.transport === 'url' ? `地址：${s.url ?? ''}` : `本地：${s.command ?? ''}`}
                      </Text>
                      <Text variant="bodySmall" style={{ color: theme.colors.onSurfaceVariant }}>
                        标识：{s.configKey}
                      </Text>

                      {isEditing && editing ? (
                        <View style={styles.editArea}>
                          <SegmentedButtons
                            value={editTransport}
                            onValueChange={(v) => setEditTransport(v as Transport)}
                            buttons={[
                              { value: 'url', label: 'URL' },
                              { value: 'stdio', label: '本地' },
                            ]}
                          />

                          <TextInput mode="outlined" label="名称" value={editName} onChangeText={setEditName} />

                          {editTransport === 'url' ? (
                            <TextInput
                              mode="outlined"
                              label="URL"
                              placeholder="https://…"
                              value={editUrl}
                              onChangeText={setEditUrl}
                              autoCapitalize="none"
                            />
                          ) : (
                            <>
                              <TextInput
                                mode="outlined"
                                label="可执行文件位置"
                                value={editCommand}
                                onChangeText={setEditCommand}
                                autoCapitalize="none"
                              />
                              <TextInput
                                mode="outlined"
                                label="参数（每行一条）"
                                value={editArgsText}
                                onChangeText={setEditArgsText}
                                multiline
                                numberOfLines={4}
                              />
                              <TextInput
                                mode="outlined"
                                label="安装地址（可选）"
                                value={editInstallUrl}
                                onChangeText={setEditInstallUrl}
                                autoCapitalize="none"
                              />

                              <View style={styles.inlineActions}>
                                <Button
                                  mode="outlined"
                                  disabled={busy}
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
                                  下载并安装
                                </Button>

                                <Button
                                  mode="outlined"
                                  disabled={busy}
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
                                  卸载
                                </Button>
                              </View>
                            </>
                          )}
                        </View>
                      ) : null}
                    </Card.Content>

                    <Card.Actions style={styles.cardActions}>
                      <Button mode="outlined" onPress={() => (isEditing ? stopEdit() : startEdit(s))}>
                        {isEditing ? '取消' : '编辑'}
                      </Button>

                      <Button
                        mode="text"
                        textColor={theme.colors.error}
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
                        删除
                      </Button>

                      {isEditing && editing ? (
                        <Button
                          mode="contained"
                          loading={busy}
                          disabled={busy}
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
                          保存
                        </Button>
                      ) : null}
                    </Card.Actions>
                  </Card>
                );
              })}
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
    maxWidth: Layout.maxWidthForm,
    alignSelf: 'center',
    paddingHorizontal: Spacing.lg,
  },
  header: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: Spacing.xl },
  error: { marginBottom: Spacing.md },
  card: { marginBottom: Spacing.lg },
  formGap: { height: Spacing.md },
  sectionTitle: { marginBottom: Spacing.sm },
  serverCard: { marginBottom: Spacing.md },
  editArea: { marginTop: Spacing.md, gap: Spacing.md },
  inlineActions: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  cardActions: { flexWrap: 'wrap' },
});
