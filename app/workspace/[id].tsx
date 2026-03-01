import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  TextInput,
  View,
} from 'react-native';

import { Stack, useLocalSearchParams, useRouter } from 'expo-router';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
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

  const colorScheme = useColorScheme() ?? 'light';
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
        <ThemedText type="title">工作区设置</ThemedText>
        <ThemedText style={styles.muted}>未找到该工作区。</ThemedText>
      </ThemedView>
    );
  }

  const repoUri = workspaceRepoPath(ws.id);

  return (
    <ThemedView style={styles.screen}>
      <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
        <ScrollView
          contentContainerStyle={styles.container}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag">
          <Stack.Screen
            options={{
              title: '工作区设置',
              headerRight: () => (
                <Pressable
                  accessibilityRole="button"
                  android_ripple={{ color: rippleColor }}
                  onPress={() => router.back()}
                  style={{ paddingHorizontal: 12 }}>
                  <ThemedText type="defaultSemiBold">关闭</ThemedText>
                </Pressable>
              ),
            }}
          />

      <ThemedView style={[styles.card, cardStyle]}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          基础信息
        </ThemedText>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="工作区名称"
          placeholderTextColor={placeholderTextColor}
          selectionColor={Colors[colorScheme].tint}
          style={[styles.input, inputStyle]}
        />
        <ThemedText style={styles.muted}>
          代码目录：<ThemedText type="defaultSemiBold">{repoUri}</ThemedText>
        </ThemedText>
        <ThemedText style={styles.muted}>
          当前状态：<ThemedText type="defaultSemiBold">{ws.id === activeWorkspaceId ? '当前工作区' : '未选中'}</ThemedText>
        </ThemedText>
        <View style={{ height: 10 }} />
        <View style={styles.row2}>
          <Pressable
            accessibilityRole="button"
            disabled={busy || ws.id === activeWorkspaceId}
            android_ripple={{ color: rippleColor }}
            onPress={async () => {
              await setActive(ws.id);
              await refresh();
            }}
            style={({ pressed }) => [
              styles.secondaryButton,
              {
                opacity: busy || ws.id === activeWorkspaceId ? 0.5 : pressed ? 0.92 : 1,
                borderColor: Colors[colorScheme].outline,
                backgroundColor: Colors[colorScheme].surface,
              },
            ]}>
            <ThemedText type="defaultSemiBold">设为当前</ThemedText>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            disabled={busy}
            android_ripple={{ color: rippleColor }}
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
            }}
            style={({ pressed }) => [
              styles.secondaryButton,
              {
                opacity: busy ? 0.5 : pressed ? 0.92 : 1,
                borderColor: Colors[colorScheme].danger,
                backgroundColor: Colors[colorScheme].surface,
              },
            ]}>
            <ThemedText type="defaultSemiBold" style={{ color: Colors[colorScheme].danger }}>
              删除
            </ThemedText>
          </Pressable>
        </View>
      </ThemedView>

      <ThemedView style={[styles.card, cardStyle]}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          Git（可选）
        </ThemedText>
        <TextInput
          value={gitRemoteUrl}
          onChangeText={setGitRemoteUrl}
          placeholder="https://github.com/user/repo.git"
          placeholderTextColor={placeholderTextColor}
          selectionColor={Colors[colorScheme].tint}
          autoCapitalize="none"
          autoCorrect={false}
          style={[styles.input, inputStyle]}
        />
        <TextInput
          value={gitBranch}
          onChangeText={setGitBranch}
          placeholder="默认分支（可选）"
          placeholderTextColor={placeholderTextColor}
          selectionColor={Colors[colorScheme].tint}
          autoCapitalize="none"
          autoCorrect={false}
          style={[styles.input, inputStyle]}
        />
        <TextInput
          value={gitToken}
          onChangeText={setGitToken}
          placeholder="访问令牌（留空保持不变）"
          placeholderTextColor={placeholderTextColor}
          selectionColor={Colors[colorScheme].tint}
          autoCapitalize="none"
          autoCorrect={false}
          secureTextEntry
          style={[styles.input, inputStyle]}
        />

        <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
          提交身份（可选）
        </ThemedText>
        <View style={styles.row2}>
          <TextInput
            value={gitUserName}
            onChangeText={setGitUserName}
            placeholder="user.name"
            placeholderTextColor={placeholderTextColor}
            selectionColor={Colors[colorScheme].tint}
            autoCapitalize="none"
            autoCorrect={false}
            style={[styles.input, styles.half, inputStyle]}
          />
          <TextInput
            value={gitUserEmail}
            onChangeText={setGitUserEmail}
            placeholder="user.email"
            placeholderTextColor={placeholderTextColor}
            selectionColor={Colors[colorScheme].tint}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="email-address"
            style={[styles.input, styles.half, inputStyle]}
          />
        </View>

        <View style={styles.switchRow}>
          <ThemedText type="defaultSemiBold">跳过证书校验（不安全）</ThemedText>
          <Switch value={gitAllowInsecure} onValueChange={setGitAllowInsecure} />
        </View>
      </ThemedView>

      <ThemedView style={[styles.card, cardStyle]}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          WebDAV（可选）
        </ThemedText>
        <TextInput
          value={webdavEndpoint}
          onChangeText={setWebdavEndpoint}
          placeholder="https://example.com/dav/"
          placeholderTextColor={placeholderTextColor}
          selectionColor={Colors[colorScheme].tint}
          autoCapitalize="none"
          autoCorrect={false}
          style={[styles.input, inputStyle]}
        />
        <View style={styles.row2}>
          <TextInput
            value={webdavBasePath}
            onChangeText={setWebdavBasePath}
            placeholder="基础路径（可选）"
            placeholderTextColor={placeholderTextColor}
            selectionColor={Colors[colorScheme].tint}
            autoCapitalize="none"
            autoCorrect={false}
            style={[styles.input, styles.half, inputStyle]}
          />
          <TextInput
            value={webdavRemoteRoot}
            onChangeText={setWebdavRemoteRoot}
            placeholder="远端目录（可选）"
            placeholderTextColor={placeholderTextColor}
            selectionColor={Colors[colorScheme].tint}
            autoCapitalize="none"
            autoCorrect={false}
            style={[styles.input, styles.half, inputStyle]}
          />
        </View>
        <ThemedText style={styles.muted}>认证信息在创建工作区时设置（后续会单独补齐编辑入口）。</ThemedText>
      </ThemedView>

      {error ? (
        <ThemedText type="default" style={[styles.error, { color: Colors[colorScheme].danger }]}>
          {error}
        </ThemedText>
      ) : null}

      <Pressable
        accessibilityRole="button"
        disabled={!canSave}
        android_ripple={{ color: rippleColor }}
        onPress={onSave}
        style={({ pressed }) => [
          styles.primaryButton,
          {
            opacity: !canSave ? 0.5 : pressed ? 0.92 : 1,
            backgroundColor: Colors[colorScheme].tint,
          },
        ]}>
        {busy ? (
          <ActivityIndicator color={colorScheme === 'dark' ? '#0b1220' : '#ffffff'} />
        ) : (
          <ThemedText
            type="defaultSemiBold"
            style={[styles.primaryButtonText, { color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }]}>
            保存
          </ThemedText>
        )}
      </Pressable>
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
    maxWidth: 720,
    alignSelf: 'center',
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 32,
  },
  card: {
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 16,
    marginBottom: 14,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  input: {
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    minHeight: 48,
    fontSize: 16,
    lineHeight: 20,
    marginBottom: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  muted: {
    opacity: 0.7,
  },
  row2: {
    flexDirection: 'row',
    gap: 10,
    flexWrap: 'wrap',
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  half: {
    flex: 1,
    minWidth: 160,
  },
  primaryButton: {
    alignItems: 'center',
    borderRadius: 12,
    justifyContent: 'center',
    minHeight: 48,
    paddingHorizontal: 16,
    marginBottom: 18,
    overflow: 'hidden',
  },
  primaryButtonText: {
    color: '#ffffff',
  },
  secondaryButton: {
    flex: 1,
    alignItems: 'center',
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    justifyContent: 'center',
    minHeight: 48,
    paddingHorizontal: 16,
    overflow: 'hidden',
  },
  error: {
    marginBottom: 10,
  },
});
