import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Switch, TextInput, View } from 'react-native';

import { Stack, useRouter } from 'expo-router';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
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

function Segment({
  label,
  active,
  onPress,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.segment,
        {
          opacity: pressed ? 0.85 : 1,
          backgroundColor: active ? 'rgba(59,130,246,0.18)' : 'transparent',
          borderColor: active ? 'rgba(59,130,246,0.55)' : 'rgba(255,255,255,0.12)',
        },
      ]}>
      <ThemedText type="defaultSemiBold">{label}</ThemedText>
    </Pressable>
  );
}

export default function NewWorkspaceScreen() {
  const router = useRouter();
  const colorScheme = useColorScheme() ?? 'light';
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
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: '新建工作区' }} />

      <View style={styles.header}>
        <ThemedText type="title">新建工作区</ThemedText>
      </View>

      <ThemedView style={styles.card}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          来源
        </ThemedText>
        <View style={styles.segments}>
          <Segment label="空白" active={sourceType === 'empty'} onPress={() => setSourceType('empty')} />
          <Segment label="Git" active={sourceType === 'git'} onPress={() => setSourceType('git')} />
          <Segment label="WebDAV" active={sourceType === 'webdav'} onPress={() => setSourceType('webdav')} />
        </View>
      </ThemedView>

      <ThemedView style={styles.card}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          基础信息
        </ThemedText>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="工作区名称"
          placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
          style={[
            styles.input,
            {
              color: Colors[colorScheme].text,
              borderColor: Colors[colorScheme].icon,
              backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
            },
          ]}
        />
      </ThemedView>

      {sourceType === 'git' ? (
        <ThemedView style={styles.card}>
          <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
            Git
          </ThemedText>

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            仓库地址
          </ThemedText>
          <TextInput
            value={gitRemoteUrl}
            onChangeText={setGitRemoteUrl}
            placeholder="https://github.com/user/repo.git"
            placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
            autoCapitalize="none"
            autoCorrect={false}
            style={[
              styles.input,
              {
                color: Colors[colorScheme].text,
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}
          />

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            分支（可选）
          </ThemedText>
          <TextInput
            value={gitBranch}
            onChangeText={setGitBranch}
            placeholder="main"
            placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
            autoCapitalize="none"
            autoCorrect={false}
            style={[
              styles.input,
              {
                color: Colors[colorScheme].text,
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}
          />

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            访问令牌（可选）
          </ThemedText>
          <TextInput
            value={gitToken}
            onChangeText={setGitToken}
            placeholder="用于私有仓库"
            placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
            autoCapitalize="none"
            autoCorrect={false}
            secureTextEntry
            style={[
              styles.input,
              {
                color: Colors[colorScheme].text,
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}
          />

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            提交身份（可选）
          </ThemedText>
          <View style={styles.row2}>
            <TextInput
              value={gitUserName}
              onChangeText={setGitUserName}
              placeholder="user.name"
              placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
              autoCapitalize="none"
              autoCorrect={false}
              style={[
                styles.input,
                styles.half,
                {
                  color: Colors[colorScheme].text,
                  borderColor: Colors[colorScheme].icon,
                  backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
                },
              ]}
            />
            <TextInput
              value={gitUserEmail}
              onChangeText={setGitUserEmail}
              placeholder="user.email"
              placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="email-address"
              style={[
                styles.input,
                styles.half,
                {
                  color: Colors[colorScheme].text,
                  borderColor: Colors[colorScheme].icon,
                  backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
                },
              ]}
            />
          </View>

          <View style={styles.switchRow}>
            <ThemedText type="defaultSemiBold">跳过证书校验（不安全）</ThemedText>
            <Switch value={gitAllowInsecure} onValueChange={setGitAllowInsecure} />
          </View>
        </ThemedView>
      ) : null}

      {sourceType === 'webdav' ? (
        <ThemedView style={styles.card}>
          <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
            WebDAV
          </ThemedText>

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            地址
          </ThemedText>
          <TextInput
            value={webdavEndpoint}
            onChangeText={setWebdavEndpoint}
            placeholder="https://example.com/dav/"
            placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
            autoCapitalize="none"
            autoCorrect={false}
            style={[
              styles.input,
              {
                color: Colors[colorScheme].text,
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}
          />

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            基础路径（可选）
          </ThemedText>
          <TextInput
            value={webdavBasePath}
            onChangeText={setWebdavBasePath}
            placeholder="/"
            placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
            autoCapitalize="none"
            autoCorrect={false}
            style={[
              styles.input,
              {
                color: Colors[colorScheme].text,
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}
          />

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            远端目录（可选）
          </ThemedText>
          <TextInput
            value={webdavRemoteRoot}
            onChangeText={setWebdavRemoteRoot}
            placeholder="repo/"
            placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
            autoCapitalize="none"
            autoCorrect={false}
            style={[
              styles.input,
              {
                color: Colors[colorScheme].text,
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}
          />

          <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
            认证
          </ThemedText>
          <View style={styles.segments}>
            <Segment label="令牌" active={webdavAuthType === 'bearer'} onPress={() => setWebdavAuthType('bearer')} />
            <Segment label="账号密码" active={webdavAuthType === 'basic'} onPress={() => setWebdavAuthType('basic')} />
          </View>

          <View style={{ height: 10 }} />

          {webdavAuthType === 'bearer' ? (
            <TextInput
              value={webdavBearerToken}
              onChangeText={setWebdavBearerToken}
              placeholder="访问令牌（可选）"
              placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
              autoCapitalize="none"
              autoCorrect={false}
              secureTextEntry
              style={[
                styles.input,
                {
                  color: Colors[colorScheme].text,
                  borderColor: Colors[colorScheme].icon,
                  backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
                },
              ]}
            />
          ) : (
            <View style={styles.row2}>
              <TextInput
                value={webdavBasicUser}
                onChangeText={setWebdavBasicUser}
                placeholder="用户名（可选）"
                placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
                autoCapitalize="none"
                autoCorrect={false}
                style={[
                  styles.input,
                  styles.half,
                  {
                    color: Colors[colorScheme].text,
                    borderColor: Colors[colorScheme].icon,
                    backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
                  },
                ]}
              />
              <TextInput
                value={webdavBasicPass}
                onChangeText={setWebdavBasicPass}
                placeholder="密码（可选）"
                placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
                autoCapitalize="none"
                autoCorrect={false}
                secureTextEntry
                style={[
                  styles.input,
                  styles.half,
                  {
                    color: Colors[colorScheme].text,
                    borderColor: Colors[colorScheme].icon,
                    backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
                  },
                ]}
              />
            </View>
          )}
        </ThemedView>
      ) : null}

      <ThemedView style={styles.card}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          MCP（可选）
        </ThemedText>
        <ThemedText style={styles.muted}>新建会话时将默认启用这些 MCP（也可在新建会话时覆盖）。</ThemedText>

        {mcpLoading ? (
          <ActivityIndicator style={{ marginTop: 12 }} />
        ) : (
          <>
            {mcpError ? <ThemedText style={[styles.error, { color: '#ef4444' }]}>{mcpError}</ThemedText> : null}
            {mcpServers.length === 0 ? (
              <ThemedText style={styles.muted}>暂无已登记的 MCP Server。你可以先到下方 Tab「MCP」里新增。</ThemedText>
            ) : (
              <View style={{ marginTop: 10 }}>
                {mcpServers.map((s) => {
                  const enabled = mcpDefaultEnabledServerIds.includes(s.id);
                  const runnable = mcpRunnable[s.id] ?? true;
                  return (
                    <View key={s.id} style={styles.switchRow}>
                      <View style={{ flex: 1 }}>
                        <ThemedText type="defaultSemiBold">{s.name}</ThemedText>
                        <ThemedText style={styles.muted}>
                          {s.transport === 'url' ? `url: ${s.url ?? ''}` : `command: ${s.command ?? ''}`}
                        </ThemedText>
                        {!runnable ? (
                          <ThemedText style={[styles.muted, { color: '#ef4444' }]}>
                            未安装/不可执行（请先在底部「MCP」里安装或修正 command）
                          </ThemedText>
                        ) : null}
                      </View>
                      <Switch
                        value={enabled}
                        disabled={!runnable && !enabled}
                        onValueChange={(next) => {
                          setMcpDefaultEnabledServerIds((prev) =>
                            next ? Array.from(new Set([...prev, s.id])) : prev.filter((x) => x !== s.id)
                          );
                        }}
                      />
                    </View>
                  );
                })}
              </View>
            )}
          </>
        )}
      </ThemedView>

      {error ? <ThemedText style={[styles.error, { color: '#ef4444' }]}>{error}</ThemedText> : null}

      <Pressable
        accessibilityRole="button"
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
              mcpDefaultEnabledServerIds: mcpDefaultEnabledServerIds.filter(Boolean).length ? mcpDefaultEnabledServerIds : undefined,
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
        }}
        style={({ pressed }) => [
          styles.primaryButton,
          {
            opacity: !canCreate ? 0.4 : pressed ? 0.85 : 1,
            backgroundColor: Colors[colorScheme].tint,
          },
        ]}>
        {loading ? (
          <ActivityIndicator />
        ) : (
          <ThemedText type="defaultSemiBold" style={{ color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }}>
            创建工作区
          </ThemedText>
        )}
      </Pressable>

      <Pressable accessibilityRole="button" style={styles.secondaryButton} onPress={() => router.back()}>
        <ThemedText style={styles.muted}>取消</ThemedText>
      </Pressable>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 16,
    paddingHorizontal: 16,
  },
  header: {
    marginBottom: 12,
  },
  card: {
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    borderRadius: 14,
    padding: 12,
    marginBottom: 12,
  },
  segments: {
    flexDirection: 'row',
    gap: 10,
  },
  segment: {
    flex: 1,
    minHeight: 44,
    borderWidth: 1,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 10,
  },
  input: {
    borderWidth: 1,
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 12,
    fontSize: 16,
    marginBottom: 10,
  },
  row2: {
    flexDirection: 'row',
    gap: 10,
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  half: {
    flex: 1,
  },
  primaryButton: {
    minHeight: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    marginTop: 4,
  },
  secondaryButton: {
    minHeight: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    marginTop: 6,
  },
  muted: {
    opacity: 0.7,
  },
  error: {
    marginTop: 4,
  },
});
