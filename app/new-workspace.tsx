import { useEffect, useMemo, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  ActivityIndicator,
  Button,
  Card,
  Divider,
  List,
  SegmentedButtons,
  Switch,
  Text,
  TextInput,
  useTheme,
} from 'react-native-paper';

import { Stack, useRouter } from 'expo-router';

import { ThemedView } from '@/components/themed-view';
import { Layout, Spacing } from '@/constants/theme';
import { useMcp } from '@/src/mcp/provider';
import { isMcpServerProbablyRunnable } from '@/src/mcp/runnable';
import { saveAuth } from '@/src/auth/authStore';
import type { GitHttpsAuth, WebDavStoredAuth } from '@/src/auth/types';
import { gitClone } from '@/src/git/nativeGit';
import { workspaceRepoPath } from '@/src/workspaces/paths';
import type { Workspace } from '@/src/workspaces/types';
import { createWorkspace, setActiveWorkspace } from '@/src/workspaces/workspaceManager';
import { useWorkspaces } from '@/src/workspaces/provider';

type SourceType = 'empty' | 'git' | 'webdav';

export default function NewWorkspaceScreen() {
  const router = useRouter();
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { refresh } = useWorkspaces();
  const { loading: mcpLoading, error: mcpError, servers: mcpServers } = useMcp();

  const [mcpRunnable, setMcpRunnable] = useState<Record<string, boolean>>({});

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const entries = await Promise.all(
        mcpServers.map(async (s) => [s.id, await isMcpServerProbablyRunnable(s)] as const)
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
  }, [mcpServers]);

  const [sourceType, setSourceType] = useState<SourceType>('empty');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [mcpDefaultEnabledServerIds, setMcpDefaultEnabledServerIds] = useState<string[]>([]);

  // Git
  const [gitRemoteUrl, setGitRemoteUrl] = useState('');
  const [gitBranch, setGitBranch] = useState('');
  const [gitToken, setGitToken] = useState('');
  const [gitAllowInsecure, setGitAllowInsecure] = useState(false);
  const [gitUserName, setGitUserName] = useState('');
  const [gitUserEmail, setGitUserEmail] = useState('');

  // WebDAV
  const [webdavEndpoint, setWebdavEndpoint] = useState('');
  const [webdavBasePath, setWebdavBasePath] = useState('');
  const [webdavRemoteRoot, setWebdavRemoteRoot] = useState('');
  const [webdavAuthType, setWebdavAuthType] = useState<'basic' | 'bearer'>('bearer');
  const [webdavBasicUser, setWebdavBasicUser] = useState('');
  const [webdavBasicPass, setWebdavBasicPass] = useState('');
  const [webdavBearerToken, setWebdavBearerToken] = useState('');

  const canCreate = useMemo(() => {
    if (!name.trim()) return false;
    if (sourceType === 'git' && !gitRemoteUrl.trim()) return false;
    if (sourceType === 'webdav' && !webdavEndpoint.trim()) return false;
    return !loading;
  }, [gitRemoteUrl, loading, name, sourceType, webdavEndpoint]);

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
          <Stack.Screen options={{ title: '新建工作区' }} />

          <View style={styles.header}>
            <Text variant="headlineMedium">新建工作区</Text>
          </View>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="来源" />
            <Card.Content>
              <SegmentedButtons
                value={sourceType}
                onValueChange={(v) => setSourceType(v as SourceType)}
                buttons={[
                  { value: 'empty', label: '空白' },
                  { value: 'git', label: 'Git' },
                  { value: 'webdav', label: 'WebDAV' },
                ]}
              />
            </Card.Content>
          </Card>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="基础信息" />
            <Card.Content>
              <TextInput mode="outlined" label="工作区名称" value={name} onChangeText={setName} />
            </Card.Content>
          </Card>

          {sourceType === 'git' ? (
            <Card style={styles.card} mode="elevated">
              <Card.Title title="Git" />
              <Card.Content>
                <TextInput
                  mode="outlined"
                  label="仓库地址"
                  placeholder="https://…"
                  value={gitRemoteUrl}
                  onChangeText={setGitRemoteUrl}
                  autoCapitalize="none"
                  autoCorrect={false}
                />

                <View style={styles.formGap} />

                <TextInput
                  mode="outlined"
                  label="分支（可选）"
                  placeholder="main"
                  value={gitBranch}
                  onChangeText={setGitBranch}
                  autoCapitalize="none"
                  autoCorrect={false}
                />

                <View style={styles.formGap} />

                <TextInput
                  mode="outlined"
                  label="访问令牌（可选）"
                  placeholder="用于私有仓库"
                  value={gitToken}
                  onChangeText={setGitToken}
                  autoCapitalize="none"
                  autoCorrect={false}
                  secureTextEntry
                />

                <View style={styles.formGap} />

                <Text variant="labelLarge">提交身份（可选）</Text>
                <View style={styles.row2}>
                  <TextInput
                    mode="outlined"
                    label="user.name"
                    value={gitUserName}
                    onChangeText={setGitUserName}
                    autoCapitalize="none"
                    autoCorrect={false}
                    style={styles.half}
                  />
                  <TextInput
                    mode="outlined"
                    label="user.email"
                    value={gitUserEmail}
                    onChangeText={setGitUserEmail}
                    autoCapitalize="none"
                    autoCorrect={false}
                    keyboardType="email-address"
                    style={styles.half}
                  />
                </View>

                <View style={styles.switchRow}>
                  <Text variant="bodyMedium">跳过证书校验（不安全）</Text>
                  <Switch value={gitAllowInsecure} onValueChange={setGitAllowInsecure} />
                </View>
              </Card.Content>
            </Card>
          ) : null}

          {sourceType === 'webdav' ? (
            <Card style={styles.card} mode="elevated">
              <Card.Title title="WebDAV" />
              <Card.Content>
                <TextInput
                  mode="outlined"
                  label="地址"
                  placeholder="https://…"
                  value={webdavEndpoint}
                  onChangeText={setWebdavEndpoint}
                  autoCapitalize="none"
                  autoCorrect={false}
                />

                <View style={styles.formGap} />

                <TextInput
                  mode="outlined"
                  label="基础路径（可选）"
                  placeholder="/"
                  value={webdavBasePath}
                  onChangeText={setWebdavBasePath}
                  autoCapitalize="none"
                  autoCorrect={false}
                />

                <View style={styles.formGap} />

                <TextInput
                  mode="outlined"
                  label="远端目录（可选）"
                  placeholder="repo/"
                  value={webdavRemoteRoot}
                  onChangeText={setWebdavRemoteRoot}
                  autoCapitalize="none"
                  autoCorrect={false}
                />

                <View style={styles.formGap} />

                <Text variant="labelLarge">认证</Text>
                <SegmentedButtons
                  value={webdavAuthType}
                  onValueChange={(v) => setWebdavAuthType(v as 'basic' | 'bearer')}
                  buttons={[
                    { value: 'bearer', label: '令牌' },
                    { value: 'basic', label: '账号密码' },
                  ]}
                />

                <View style={styles.formGap} />

                {webdavAuthType === 'bearer' ? (
                  <TextInput
                    mode="outlined"
                    label="访问令牌（可选）"
                    value={webdavBearerToken}
                    onChangeText={setWebdavBearerToken}
                    autoCapitalize="none"
                    autoCorrect={false}
                    secureTextEntry
                  />
                ) : (
                  <View style={styles.row2}>
                    <TextInput
                      mode="outlined"
                      label="用户名（可选）"
                      value={webdavBasicUser}
                      onChangeText={setWebdavBasicUser}
                      autoCapitalize="none"
                      autoCorrect={false}
                      style={styles.half}
                    />
                    <TextInput
                      mode="outlined"
                      label="密码（可选）"
                      value={webdavBasicPass}
                      onChangeText={setWebdavBasicPass}
                      autoCapitalize="none"
                      autoCorrect={false}
                      secureTextEntry
                      style={styles.half}
                    />
                  </View>
                )}
              </Card.Content>
            </Card>
          ) : null}

          <Card style={styles.card} mode="elevated">
            <Card.Title title="MCP（可选）" />
            <Card.Content>
              <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
                新建会话时将默认启用这些 MCP（也可在新建会话时覆盖）。
              </Text>

              <View style={{ marginTop: Spacing.md }}>
                {mcpLoading ? (
                  <ActivityIndicator />
                ) : (
                  <>
                    {mcpError ? <Text style={{ color: theme.colors.error }}>{mcpError}</Text> : null}
                    {mcpServers.length === 0 ? (
                      <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
                        暂无已登记的 MCP 服务器。你可以先到下方 Tab「MCP」里新增。
                      </Text>
                    ) : (
                      <View style={styles.list}>
                        {mcpServers.map((s, idx) => {
                          const enabled = mcpDefaultEnabledServerIds.includes(s.id);
                          const runnable = mcpRunnable[s.id] ?? true;
                          const disabled = !runnable && !enabled;
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
                                right={() => (
                                  <Switch
                                    value={enabled}
                                    disabled={disabled}
                                    onValueChange={(next) => {
                                      setMcpDefaultEnabledServerIds((prev) =>
                                        next ? Array.from(new Set([...prev, s.id])) : prev.filter((x) => x !== s.id)
                                      );
                                    }}
                                  />
                                )}
                              />
                              {idx < mcpServers.length - 1 ? <Divider /> : null}
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

          {error ? <Text style={{ color: theme.colors.error, marginBottom: Spacing.md }}>{error}</Text> : null}

          <View style={styles.actions}>
            <Button
              mode="contained"
              loading={loading}
              disabled={!canCreate}
              onPress={async () => {
                setLoading(true);
                setError(null);
                try {
                  let webdav: Workspace['webdav'] | undefined;
                  let git: Workspace['git'] | undefined;

                  if (sourceType === 'webdav') {
                    let authRef: string | undefined;
                    if (webdavAuthType === 'bearer' && webdavBearerToken.trim()) {
                      const auth: WebDavStoredAuth = { type: 'webdav_bearer', token: webdavBearerToken.trim() };
                      authRef = await saveAuth(auth);
                    }
                    if (webdavAuthType === 'basic' && (webdavBasicUser.trim() || webdavBasicPass.trim())) {
                      const auth: WebDavStoredAuth = {
                        type: 'webdav_basic',
                        username: webdavBasicUser.trim(),
                        password: webdavBasicPass,
                      };
                      authRef = await saveAuth(auth);
                    }

                    webdav = {
                      endpoint: webdavEndpoint.trim(),
                      basePath: webdavBasePath.trim() || undefined,
                      remoteRoot: webdavRemoteRoot.trim() || undefined,
                      authRef,
                    };
                  }

                  if (sourceType === 'git') {
                    let authRef: string | undefined;
                    if (gitToken.trim()) {
                      const auth: GitHttpsAuth = { type: 'git_https', username: 'oauth2', token: gitToken.trim() };
                      authRef = await saveAuth(auth);
                    }
                    git = {
                      remoteUrl: gitRemoteUrl.trim(),
                      defaultBranch: gitBranch.trim() || undefined,
                      authRef,
                      allowInsecure: gitAllowInsecure,
                      userName: gitUserName.trim() || undefined,
                      userEmail: gitUserEmail.trim() || undefined,
                    };
                  }

                  const ws = await createWorkspace({
                    name: name.trim(),
                    git,
                    webdav,
                    mcpDefaultEnabledServerIds: mcpDefaultEnabledServerIds.filter(Boolean).length
                      ? mcpDefaultEnabledServerIds
                      : undefined,
                  });

                  await setActiveWorkspace(ws.id);
                  if (git) {
                    await gitClone({
                      workspaceId: ws.id,
                      remoteUrl: git.remoteUrl,
                      localRepoDirUri: workspaceRepoPath(ws.id),
                      branch: git.defaultBranch,
                      authRef: git.authRef,
                      allowInsecure: git.allowInsecure,
                      userName: git.userName,
                      userEmail: git.userEmail,
                    });
                  }
                  await refresh();
                  router.replace('/(tabs)/sessions');
                } catch (e) {
                  const message = e instanceof Error ? e.message : String(e);
                  setError(message);
                } finally {
                  setLoading(false);
                }
              }}>
              创建工作区
            </Button>

            <Button mode="outlined" onPress={() => router.back()}>
              取消
            </Button>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    flexGrow: 1,
    width: '100%',
    maxWidth: Layout.maxWidthForm,
    alignSelf: 'center',
    paddingHorizontal: Spacing.lg,
  },
  header: {
    marginBottom: Spacing.lg,
  },
  card: { marginBottom: Spacing.lg },
  formGap: { height: Spacing.md },
  row2: {
    flexDirection: 'row',
    gap: Spacing.md,
    flexWrap: 'wrap',
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: Spacing.md,
  },
  half: {
    flex: 1,
    minWidth: 160,
  },
  list: { marginTop: Spacing.sm, borderRadius: 12, overflow: 'hidden' },
  actions: { gap: Spacing.md },
});
