import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Button, Card, Switch, Text, TextInput, useTheme } from 'react-native-paper';

import { Stack, useLocalSearchParams, useRouter } from 'expo-router';

import { ThemedView } from '@/components/themed-view';
import { Layout, Spacing } from '@/constants/theme';
import { deleteAuth, saveAuth } from '@/src/auth/authStore';
import type { GitHttpsAuth } from '@/src/auth/types';
import { workspaceRepoPath } from '@/src/workspaces/paths';
import { updateWorkspace } from '@/src/workspaces/workspaceManager';
import type { Workspace } from '@/src/workspaces/types';
import { useWorkspaces } from '@/src/workspaces/provider';

export default function WorkspaceSettingsScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const workspaceId = typeof id === 'string' ? id : '';

  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { workspaces, activeWorkspaceId, refresh, setActive, remove } = useWorkspaces();

  const ws = useMemo(
    () => workspaces.find((w) => w.id === workspaceId) ?? null,
    [workspaceId, workspaces]
  );

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState('');

  const [gitRemoteUrl, setGitRemoteUrl] = useState('');
  const [gitBranch, setGitBranch] = useState('');
  const [gitToken, setGitToken] = useState('');
  const [gitAllowInsecure, setGitAllowInsecure] = useState(false);
  const [gitUserName, setGitUserName] = useState('');
  const [gitUserEmail, setGitUserEmail] = useState('');

  const [webdavEndpoint, setWebdavEndpoint] = useState('');
  const [webdavBasePath, setWebdavBasePath] = useState('');
  const [webdavRemoteRoot, setWebdavRemoteRoot] = useState('');

  useEffect(() => {
    setError(null);
    setGitToken('');
    setGitAllowInsecure(false);
    setGitUserName('');
    setGitUserEmail('');
    if (!ws) return;
    setName(ws.name ?? '');
    setGitRemoteUrl(ws.git?.remoteUrl ?? '');
    setGitBranch(ws.git?.defaultBranch ?? '');
    setGitAllowInsecure(ws.git?.allowInsecure ?? false);
    setGitUserName(ws.git?.userName ?? '');
    setGitUserEmail(ws.git?.userEmail ?? '');
    setWebdavEndpoint(ws.webdav?.endpoint ?? '');
    setWebdavBasePath(ws.webdav?.basePath ?? '');
    setWebdavRemoteRoot(ws.webdav?.remoteRoot ?? '');
  }, [ws]);

  const canSave = useMemo(() => {
    if (!ws) return false;
    if (!name.trim()) return false;
    if (busy) return false;
    return true;
  }, [busy, name, ws]);

  async function onSave() {
    if (!ws) return;
    const trimmedName = name.trim();
    if (!trimmedName) return;

    setBusy(true);
    setError(null);
    try {
      const patch: Partial<Omit<Workspace, 'id'>> = { name: trimmedName };

      // Git（可选）
      const trimmedRemote = gitRemoteUrl.trim();
      if (trimmedRemote) {
        const nextGit: NonNullable<Workspace['git']> = {
          remoteUrl: trimmedRemote,
          defaultBranch: gitBranch.trim() || undefined,
          authRef: ws.git?.authRef,
          allowInsecure: gitAllowInsecure,
          userName: gitUserName.trim() || undefined,
          userEmail: gitUserEmail.trim() || undefined,
        };
        if (gitToken.trim()) {
          const auth: GitHttpsAuth = { type: 'git_https', username: 'oauth2', token: gitToken.trim() };
          const nextAuthRef = await saveAuth(auth);
          if (ws.git?.authRef) {
            try {
              await deleteAuth(ws.git.authRef);
            } catch {
              // ignore
            }
          }
          nextGit.authRef = nextAuthRef;
        }
        patch.git = nextGit;
      } else {
        patch.git = undefined;
      }

      // WebDAV（可选）
      const trimmedEndpoint = webdavEndpoint.trim();
      if (trimmedEndpoint) {
        patch.webdav = {
          endpoint: trimmedEndpoint,
          basePath: webdavBasePath.trim() || undefined,
          remoteRoot: webdavRemoteRoot.trim() || undefined,
          authRef: ws.webdav?.authRef,
        };
      } else {
        patch.webdav = undefined;
      }

      await updateWorkspace(ws.id, patch);
      await refresh();
      router.back();
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  if (!ws) {
    return (
      <ThemedView style={[styles.screen, styles.container]}>
        <Stack.Screen options={{ title: '工作区设置' }} />
        <Text variant="headlineMedium">工作区设置</Text>
        <Text variant="bodyMedium" style={{ color: theme.colors.onSurfaceVariant }}>
          未找到该工作区。
        </Text>
      </ThemedView>
    );
  }

  const repoUri = workspaceRepoPath(ws.id);

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
          <Stack.Screen
            options={{
              title: '工作区设置',
              headerRight: () => (
                <Button compact mode="text" onPress={() => router.back()}>
                  关闭
                </Button>
              ),
            }}
          />

          <Card style={styles.card} mode="elevated">
            <Card.Title title="基础信息" />
            <Card.Content>
              <TextInput mode="outlined" label="工作区名称" value={name} onChangeText={setName} />

              <View style={{ marginTop: Spacing.sm, gap: 4 }}>
                <Text variant="bodySmall" style={{ color: theme.colors.onSurfaceVariant }}>
                  代码目录：<Text variant="bodySmall" style={{ fontWeight: '600' }}>{repoUri}</Text>
                </Text>
                <Text variant="bodySmall" style={{ color: theme.colors.onSurfaceVariant }}>
                  当前状态：<Text variant="bodySmall" style={{ fontWeight: '600' }}>{ws.id === activeWorkspaceId ? '当前工作区' : '未选中'}</Text>
                </Text>
              </View>

              <View style={styles.row2}>
                <Button
                  mode="outlined"
                  disabled={busy || ws.id === activeWorkspaceId}
                  onPress={async () => {
                    await setActive(ws.id);
                    await refresh();
                  }}>
                  设为当前
                </Button>

                <Button
                  mode="text"
                  textColor={theme.colors.error}
                  disabled={busy}
                  onPress={() => {
                    Alert.alert('删除工作区？', ws.name, [
                      { text: '取消', style: 'cancel' },
                      {
                        text: '删除',
                        style: 'destructive',
                        onPress: async () => {
                          await remove(ws.id);
                          router.back();
                        },
                      },
                    ]);
                  }}>
                  删除
                </Button>
              </View>
            </Card.Content>
          </Card>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="Git（可选）" />
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
                label="默认分支（可选）"
                placeholder="main"
                value={gitBranch}
                onChangeText={setGitBranch}
                autoCapitalize="none"
                autoCorrect={false}
              />

              <View style={styles.formGap} />

              <TextInput
                mode="outlined"
                label="访问令牌（留空保持不变）"
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

          <Card style={styles.card} mode="elevated">
            <Card.Title title="WebDAV（可选）" />
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

              <View style={styles.row2}>
                <TextInput
                  mode="outlined"
                  label="基础路径（可选）"
                  placeholder="/"
                  value={webdavBasePath}
                  onChangeText={setWebdavBasePath}
                  autoCapitalize="none"
                  autoCorrect={false}
                  style={styles.half}
                />
                <TextInput
                  mode="outlined"
                  label="远端目录（可选）"
                  placeholder="repo/"
                  value={webdavRemoteRoot}
                  onChangeText={setWebdavRemoteRoot}
                  autoCapitalize="none"
                  autoCorrect={false}
                  style={styles.half}
                />
              </View>

              <Text variant="bodySmall" style={{ color: theme.colors.onSurfaceVariant }}>
                认证信息在创建工作区时设置（后续会单独补齐编辑入口）。
              </Text>
            </Card.Content>
          </Card>

          {error ? <Text style={[styles.error, { color: theme.colors.error }]}>{error}</Text> : null}

          <View style={styles.actions}>
            <Button mode="contained" loading={busy} disabled={!canSave} onPress={onSave}>
              保存
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
  actions: { gap: Spacing.md, marginBottom: Spacing.xl },
  error: { marginBottom: Spacing.md },
});
