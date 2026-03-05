import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  View,
} from 'react-native';
import { Button, Card, Divider, List, SegmentedButtons, TextInput as PaperTextInput, useTheme } from 'react-native-paper';

import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import * as Clipboard from 'expo-clipboard';
import * as FileSystem from 'expo-file-system/legacy';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors, Fonts, Layout, Spacing } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { readLatestDebugLogTail } from '@/src/codex/debugLog';
import { deleteSkill, listInstalledSkills, normalizeSkillName, skillFileUri, writeSkill } from '@/src/codex/skills';
import {
  defaultCodexSettings,
  generateCodexConfigToml,
  getCodexApiKey,
  getCodexSettings,
  hasCodexApiKey,
  materializeCodexConfigFiles,
  setCodexApiKey,
  updateCodexSettings,
  type CodexPersonality,
} from '@/src/codex/settings';
import { useWorkspaces } from '@/src/workspaces/provider';

export default function SettingsScreen() {
  const colorScheme = useColorScheme() ?? 'light';
  const theme = useTheme();
  const { activeWorkspaceId } = useWorkspaces();
  const insets = useSafeAreaInsets();

  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [model, setModel] = useState('');
  const [openaiBaseUrl, setOpenaiBaseUrl] = useState('');
  const [models, setModels] = useState<string[]>([]);
  const [modelsLoading, setModelsLoading] = useState(false);
  const [modelsError, setModelsError] = useState<string | null>(null);
  const [modelPickerOpen, setModelPickerOpen] = useState(false);
  const [modelQuery, setModelQuery] = useState('');

  const [skills, setSkills] = useState<string[]>([]);
  const [skillsLoading, setSkillsLoading] = useState(false);
  const [skillsError, setSkillsError] = useState<string | null>(null);
  const [skillNameDraft, setSkillNameDraft] = useState('');
  const [skillContentDraft, setSkillContentDraft] = useState('');
  const [personality, setPersonality] = useState<CodexPersonality>(defaultCodexSettings().personality);
  const [uiShowThinking, setUiShowThinking] = useState(Boolean(defaultCodexSettings().uiShowThinking));

  const [debugLogToFile, setDebugLogToFile] = useState(Boolean(defaultCodexSettings().debugLogToFile));
  const [debugLogRetentionDays, setDebugLogRetentionDays] = useState(
    String(defaultCodexSettings().debugLogRetentionDays ?? 7)
  );

  const [apiKeyConfigured, setApiKeyConfigured] = useState(false);
  const [newApiKey, setNewApiKey] = useState('');

  const [showAdvanced, setShowAdvanced] = useState(false);
  const [useRawConfigToml, setUseRawConfigToml] = useState(false);
  const [rawConfigToml, setRawConfigToml] = useState('');

  function validateApiKeyInput(v: string): string | null {
    const t = v.trim();
    if (!t) return null;
    if (/\s/.test(t)) return '密钥中包含空白字符，请重新复制粘贴。';
    // OpenAI API key 常见前缀为 sk- / sk-proj-；这里做保守校验，避免用户误填。
    if (!t.startsWith('sk-') || t.length < 20) return '密钥格式看起来不正确（应以 sk- 开头）。';
    return null;
  }

  async function getRecentDebugLogTextOrAlert() {
    if (!debugLogToFile) {
      Alert.alert('未开启调试日志', '请先在高级选项中开启并保存，然后复现问题后再导出。');
      return null;
    }
    if (!activeWorkspaceId) {
      Alert.alert('未选择工作区', '请先创建或选择一个工作区后重试。');
      return null;
    }
    const text = await readLatestDebugLogTail({ workspaceId: activeWorkspaceId, maxChars: 200_000 });
    if (!text.trim()) {
      Alert.alert('暂无日志', '还没有可导出的诊断信息。');
      return null;
    }
    return text;
  }

  function formatStampForFileName(d: Date) {
    const pad2 = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}-${pad2(d.getHours())}${pad2(
      d.getMinutes()
    )}${pad2(d.getSeconds())}`;
  }

  async function copyRecentDebugLog() {
    try {
      const text = await getRecentDebugLogTextOrAlert();
      if (!text) return;
      await Clipboard.setStringAsync(text);
      Alert.alert('已复制', '诊断信息已复制到剪贴板。');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      Alert.alert('复制失败', msg);
    }
  }

  async function exportRecentDebugLog() {
    const text = await getRecentDebugLogTextOrAlert();
    if (!text) return;

    if (Platform.OS === 'android' && FileSystem.StorageAccessFramework) {
      try {
        const perms = await FileSystem.StorageAccessFramework.requestDirectoryPermissionsAsync();
        if (perms.granted) {
          const fileName = `codexm-诊断日志-${formatStampForFileName(new Date())}`;
          const fileUri = await FileSystem.StorageAccessFramework.createFileAsync(perms.directoryUri, fileName, 'text/plain');
          await FileSystem.writeAsStringAsync(fileUri, text);
          Alert.alert('已导出', '诊断信息已保存到你选择的目录。');
          return;
        }
      } catch {
        // ignore and fall back
      }
    }

    try {
      await Share.share({ title: '诊断信息', message: text });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      Alert.alert('导出失败', msg);
    }
  }

  function openDiagnosticsActions() {
    Alert.alert('诊断信息', '用于排查连接超时、卡住等问题。', [
      { text: '复制到剪贴板', onPress: () => void copyRecentDebugLog() },
      { text: Platform.OS === 'android' ? '导出为文件' : '分享', onPress: () => void exportRecentDebugLog() },
      { text: '取消', style: 'cancel' },
    ]);
  }

  function resolveModelsListUrl() {
    const raw = openaiBaseUrl.trim();
    const baseInput = raw || 'https://api.openai.com/v1';
    const base = baseInput.replace(/\/+$/, '');
    if (raw && !(base.startsWith('http://') || base.startsWith('https://'))) {
      throw new Error('服务器地址格式不正确（需以 http:// 或 https:// 开头）。');
    }
    if (base.endsWith('/models')) return base;
    if (base.endsWith('/v1')) return `${base}/models`;
    return `${base}/v1/models`;
  }

  async function refreshModels(opts?: { openPicker?: boolean }) {
    setModelsError(null);
    setModelsLoading(true);
    try {
      const apiKey = newApiKey.trim() || (await getCodexApiKey());
      if (!apiKey) throw new Error('请先设置密钥。');

      const url = resolveModelsListUrl();
      const res = await fetch(url, {
        method: 'GET',
        headers: {
          Accept: 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
      });
      if (!res.ok) throw new Error('无法获取模型列表：请检查服务器地址与密钥。');

      const json = (await res.json()) as any;
      const data = Array.isArray(json?.data) ? (json.data as any[]) : [];
      const ids = data
        .map((x) => (x && typeof x === 'object' && typeof x.id === 'string' ? x.id : null))
        .filter((x): x is string => Boolean(x));
      setModels(Array.from(new Set(ids)).sort((a, b) => a.localeCompare(b)));
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setModelsError(msg);
      setModels([]);
    } finally {
      setModelsLoading(false);
      if (opts?.openPicker) setModelPickerOpen(true);
    }
  }

  async function refreshSkills() {
    setSkillsError(null);
    setSkillsLoading(true);
    try {
      const list = await listInstalledSkills();
      setSkills(list);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setSkillsError(msg || '无法获取技能列表。');
      setSkills([]);
    } finally {
      setSkillsLoading(false);
    }
  }

  async function loadSkillIntoDraft(name: string) {
    const n = normalizeSkillName(name);
    if (!n) return;
    setSkillsError(null);
    try {
      const content = await FileSystem.readAsStringAsync(skillFileUri(n));
      setSkillNameDraft(n);
      setSkillContentDraft(content.trimEnd());
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      Alert.alert('无法读取技能', msg || '读取失败。');
    }
  }

  async function saveSkillDraft() {
    const name = normalizeSkillName(skillNameDraft);
    const content = skillContentDraft.trim();
    if (!name) {
      Alert.alert('名称无效', '请输入技能名称。');
      return;
    }
    if (!content) {
      Alert.alert('内容为空', '请输入技能内容。');
      return;
    }
    setSkillsError(null);
    setSkillsLoading(true);
    try {
      const res = await writeSkill({ name, content });
      setSkillNameDraft(res.name);
      const list = await listInstalledSkills();
      setSkills(list);
      Alert.alert('已保存', `技能「${res.name}」已保存。`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setSkillsError(msg);
      Alert.alert('保存失败', msg || '保存失败。');
    } finally {
      setSkillsLoading(false);
    }
  }

  function deleteSkillDraft() {
    const name = normalizeSkillName(skillNameDraft);
    if (!name) {
      Alert.alert('名称无效', '请输入技能名称。');
      return;
    }
    Alert.alert('删除技能', `确认删除技能「${name}」吗？`, [
      { text: '取消', style: 'cancel' },
      {
        text: '删除',
        style: 'destructive',
        onPress: () => {
          void (async () => {
            setSkillsError(null);
            setSkillsLoading(true);
            try {
              await deleteSkill(name);
              const list = await listInstalledSkills();
              setSkills(list);
              setSkillNameDraft('');
              setSkillContentDraft('');
            } catch (e) {
              const msg = e instanceof Error ? e.message : String(e);
              setSkillsError(msg);
              Alert.alert('删除失败', msg || '删除失败。');
            } finally {
              setSkillsLoading(false);
            }
          })();
        },
      },
    ]);
  }

  useEffect(() => {
    if (!showAdvanced) return;
    void refreshSkills();
  }, [showAdvanced]);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      setLoading(true);
      setError(null);
      try {
        const s = await getCodexSettings();
        const hasKey = await hasCodexApiKey();
        if (cancelled) return;
        setModel(s.model ?? '');
        setOpenaiBaseUrl(s.openaiBaseUrl ?? '');
        setPersonality(s.personality);
        setUiShowThinking(Boolean(s.uiShowThinking));
        setDebugLogToFile(Boolean(s.debugLogToFile));
        setDebugLogRetentionDays(String(s.debugLogRetentionDays ?? defaultCodexSettings().debugLogRetentionDays ?? 7));
        setUseRawConfigToml(Boolean(s.useRawConfigToml));
        setRawConfigToml(s.rawConfigToml ?? '');
        setApiKeyConfigured(hasKey);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        if (!cancelled) setError(msg);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    run();
    return () => {
      cancelled = true;
    };
  }, []);

  const filteredModels = useMemo(() => {
    const q = modelQuery.trim().toLowerCase();
    if (!q) return models;
    return models.filter((m) => m.toLowerCase().includes(q));
  }, [modelQuery, models]);

  const generatedToml = useMemo(() => {
    return generateCodexConfigToml({
      version: 1,
      enabled: true,
      model: model.trim() || undefined,
      openaiBaseUrl: openaiBaseUrl.trim() || undefined,
      approvalPolicy: 'never',
      personality,
      useRawConfigToml,
      rawConfigToml,
    });
  }, [model, openaiBaseUrl, personality, rawConfigToml, useRawConfigToml]);

  const effectiveToml = useMemo(() => {
    if (useRawConfigToml && rawConfigToml.trim()) return rawConfigToml;
    return generatedToml;
  }, [generatedToml, rawConfigToml, useRawConfigToml]);

  const rippleColor = useMemo(
    () => (colorScheme === 'dark' ? 'rgba(255,255,255,0.14)' : 'rgba(2,6,23,0.08)'),
    [colorScheme]
  );

  if (loading) {
    return (
      <ThemedView style={styles.screen}>
        <View style={styles.center}>
          <ActivityIndicator />
        </View>
      </ThemedView>
    );
  }

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
            <ThemedText type="title">设置</ThemedText>
            <ThemedText style={styles.muted}>全局设置（所有工作区共用）。</ThemedText>
          </View>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="Codex" />
            <Card.Content>

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              密钥
            </ThemedText>
            <ThemedText style={[styles.muted, { marginBottom: 8 }]}>状态：{apiKeyConfigured ? '已保存' : '未保存'}</ThemedText>
            <PaperTextInput
              mode="outlined"
              value={newApiKey}
              onChangeText={setNewApiKey}
              placeholder={apiKeyConfigured ? '留空保持不变' : '粘贴你的密钥'}
              autoCapitalize="none"
              autoCorrect={false}
              secureTextEntry
              style={styles.input}
            />

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              服务器地址（可选）
            </ThemedText>
            <PaperTextInput
              mode="outlined"
              value={openaiBaseUrl}
              onChangeText={(v) => {
                setOpenaiBaseUrl(v);
                setModels([]);
                setModelsError(null);
                setModelPickerOpen(false);
                setModelQuery('');
              }}
              placeholder="留空使用默认"
              autoCapitalize="none"
              autoCorrect={false}
              style={styles.input}
            />

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              模型
            </ThemedText>
            <View style={[styles.modelPicker, { borderColor: Colors[colorScheme].outline, backgroundColor: Colors[colorScheme].surface2 }]}>
              <List.Item
                title={model || '使用默认模型'}
                description="点击选择模型"
                onPress={() => {
                  setModelQuery('');
                  setModelPickerOpen(true);
                  if (!models.length && !modelsLoading) void refreshModels();
                }}
                right={(props) => <MaterialIcons name="chevron-right" size={22} color={props.color} />}
              />
            </View>
            <View style={styles.row2}>
              <Button mode="outlined" loading={modelsLoading} disabled={modelsLoading} onPress={() => void refreshModels({ openPicker: true })}>
                刷新列表
              </Button>
              <Button mode="outlined" disabled={!model} onPress={() => setModel('')}>
                使用默认
              </Button>
            </View>
            {modelsError ? (
              <ThemedText style={[styles.error, { color: Colors[colorScheme].danger }]}>{modelsError}</ThemedText>
            ) : null}

            <View style={styles.row2}>
              <Button mode="text" onPress={() => setShowAdvanced((v) => !v)}>
                {showAdvanced ? '收起高级选项' : '展开高级选项'}
              </Button>
              <Button mode="text" onPress={openDiagnosticsActions}>
                导出日志
              </Button>
            </View>

            {showAdvanced ? (
              <View style={{ marginTop: 10 }}>
                <View style={{ height: 12 }} />

                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  风格
                </ThemedText>
                <SegmentedButtons
                  value={personality}
                  onValueChange={(v) => setPersonality(v as CodexPersonality)}
                  buttons={[
                    { value: 'none', label: '默认' },
                    { value: 'friendly', label: '友好' },
                    { value: 'pragmatic', label: '务实' },
                  ]}
                />

                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  思考内容
                </ThemedText>
                <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
                  默认隐藏，避免占用屏幕。
                </ThemedText>
                <SegmentedButtons
                  value={uiShowThinking ? 'show' : 'hide'}
                  onValueChange={(v) => setUiShowThinking(v === 'show')}
                  buttons={[
                    { value: 'hide', label: '隐藏' },
                    { value: 'show', label: '显示' },
                  ]}
                />

                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  调试日志
                </ThemedText>
                <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
                  默认关闭。开启后会在本机记录错误与关键事件，用于排查问题。
                </ThemedText>
                <SegmentedButtons
                  value={debugLogToFile ? 'on' : 'off'}
                  onValueChange={(v) => setDebugLogToFile(v === 'on')}
                  buttons={[
                    { value: 'off', label: '关闭' },
                    { value: 'on', label: '开启' },
                  ]}
                />
                <Button
                  mode="outlined"
                  style={{ marginTop: Spacing.md }}
                  disabled={!debugLogToFile || !activeWorkspaceId}
                  onPress={copyRecentDebugLog}>
                  复制最近日志
                </Button>
                <ThemedText style={styles.muted}>
                  复制到剪贴板后，可粘贴到问题反馈中帮助排查。
                </ThemedText>
                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  保留天数
                </ThemedText>
                <PaperTextInput
                  mode="outlined"
                  value={debugLogRetentionDays}
                  onChangeText={(v) => setDebugLogRetentionDays(v.replace(/[^0-9]/g, ''))}
                  placeholder="7"
                  keyboardType="number-pad"
                  style={styles.input}
                />
                <ThemedText style={styles.muted}>范围：1–90 天。</ThemedText>

                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  技能
                </ThemedText>
                <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
                  在会话中输入 $技能名 可启用。
                </ThemedText>

                <View style={styles.row2}>
                  <Button mode="outlined" disabled={skillsLoading} onPress={() => void refreshSkills()}>
                    刷新列表
                  </Button>
                  <Button
                    mode="outlined"
                    disabled={skillsLoading}
                    onPress={() => {
                      setSkillNameDraft('');
                      setSkillContentDraft('');
                    }}>
                    清空编辑
                  </Button>
                </View>

                {skillsError ? (
                  <ThemedText style={[styles.error, { color: Colors[colorScheme].danger }]}>{skillsError}</ThemedText>
                ) : null}

                {skillsLoading ? (
                  <View style={{ paddingVertical: 10, alignItems: 'center' }}>
                    <ActivityIndicator />
                  </View>
                ) : skills.length ? (
                  <View
                    style={{
                      borderRadius: 12,
                      overflow: 'hidden',
                      borderWidth: StyleSheet.hairlineWidth,
                      borderColor: Colors[colorScheme].outline,
                      backgroundColor: Colors[colorScheme].surface2,
                    }}>
                    {skills.map((name, idx) => (
                      <View key={name}>
                        <List.Item
                          title={`$${name}`}
                          titleNumberOfLines={1}
                          onPress={() => void loadSkillIntoDraft(name)}
                          right={(props) => <MaterialIcons name="edit" size={18} color={props.color} />}
                        />
                        {idx < skills.length - 1 ? <Divider /> : null}
                      </View>
                    ))}
                  </View>
                ) : (
                  <ThemedText style={styles.muted}>还没有技能。</ThemedText>
                )}

                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  编辑技能
                </ThemedText>
                <PaperTextInput
                  mode="outlined"
                  value={skillNameDraft}
                  onChangeText={setSkillNameDraft}
                  placeholder="名称（例如 ui-ux-pro-max）"
                  autoCapitalize="none"
                  autoCorrect={false}
                  style={styles.input}
                />
                <View style={{ height: 8 }} />
                <PaperTextInput
                  mode="outlined"
                  value={skillContentDraft}
                  onChangeText={setSkillContentDraft}
                  placeholder="内容（支持 Markdown）"
                  autoCapitalize="none"
                  autoCorrect={false}
                  style={[styles.codeInput, { minHeight: 140 }]}
                  contentStyle={{ fontFamily: Fonts.mono, fontSize: 12, lineHeight: 16 }}
                  multiline
                />
                <View style={styles.row2}>
                  <Button mode="contained" disabled={skillsLoading} onPress={saveSkillDraft}>
                    保存技能
                  </Button>
                  <Button
                    mode="outlined"
                    disabled={!normalizeSkillName(skillNameDraft) || skillsLoading}
                    onPress={deleteSkillDraft}>
                    删除
                  </Button>
                </View>
              </View>
            ) : null}
            </Card.Content>
          </Card>

          <Card style={styles.card} mode="elevated">
            <Card.Title title="配置文件" />
            <Card.Content>
        <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
          提示：不要在配置文件中粘贴密钥，密钥请在上方单独设置。
        </ThemedText>

        <SegmentedButtons
          value={useRawConfigToml ? 'custom' : 'auto'}
          onValueChange={(v) => {
            if (v === 'auto') {
              setUseRawConfigToml(false);
              return;
            }
            setUseRawConfigToml(true);
            if (!rawConfigToml.trim()) setRawConfigToml(generatedToml);
          }}
          buttons={[
            { value: 'auto', label: '自动生成' },
            { value: 'custom', label: '自定义' },
          ]}
        />

        <View style={{ height: 10 }} />

        {useRawConfigToml ? (
          <>
            <View style={styles.row2}>
              <Button
                mode="outlined"
                disabled={busy}
                onPress={() => {
                  setUseRawConfigToml(true);
                  setRawConfigToml(generatedToml);
                }}>
                从当前设置生成
              </Button>
              <Button
                mode="outlined"
                disabled={busy}
                onPress={() => {
                  setUseRawConfigToml(false);
                  setRawConfigToml('');
                }}>
                恢复默认
              </Button>
            </View>
            <View style={{ height: 10 }} />
            <PaperTextInput
              mode="outlined"
              value={rawConfigToml}
              onChangeText={setRawConfigToml}
              placeholder="在这里编辑配置内容"
              autoCapitalize="none"
              autoCorrect={false}
              multiline
              style={styles.codeInput}
              contentStyle={{ fontFamily: Fonts.mono, fontSize: 12, lineHeight: 16, minHeight: 180 }}
            />
          </>
        ) : (
          <ThemedView
            style={[
              styles.codeBox,
              {
                borderColor: Colors[colorScheme].outline,
                backgroundColor: Colors[colorScheme].surface2,
              },
            ]}>
            <ThemedText style={styles.code}>{effectiveToml}</ThemedText>
          </ThemedView>
        )}
            </Card.Content>
          </Card>

      {error ? <ThemedText style={[styles.error, { color: Colors[colorScheme].danger }]}>{error}</ThemedText> : null}

      <Button
        mode="contained"
        loading={busy}
        disabled={busy}
        onPress={async () => {
          setBusy(true);
          setError(null);
          try {
            const apiKeyToSave = newApiKey.trim();
            if (apiKeyToSave) {
              const keyErr = validateApiKeyInput(apiKeyToSave);
              if (keyErr) throw new Error(keyErr);
            }
            if (useRawConfigToml && !rawConfigToml.trim()) {
              throw new Error('自定义配置不能为空，请填写或切换到“自动生成”。');
            }
            const daysText = debugLogRetentionDays.trim();
            const daysRaw = daysText ? Number(daysText) : defaultCodexSettings().debugLogRetentionDays ?? 7;
            const days = Math.floor(daysRaw);
            if (!Number.isFinite(days) || days < 1 || days > 90) {
              throw new Error('保留天数需要是 1–90 的整数。');
            }
            await updateCodexSettings({
              enabled: true,
              model: model.trim() || undefined,
              openaiBaseUrl: openaiBaseUrl.trim() || undefined,
              approvalPolicy: 'never',
              personality,
              uiShowThinking,
              debugLogToFile,
              debugLogRetentionDays: days,
              useRawConfigToml,
              rawConfigToml: rawConfigToml || undefined,
            });
            if (apiKeyToSave) {
              await setCodexApiKey(apiKeyToSave);
              setNewApiKey('');
              setApiKeyConfigured(true);
            }
            await materializeCodexConfigFiles();
            Alert.alert('已保存', '设置已更新。');
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            setError(msg);
          } finally {
            setBusy(false);
          }
        }}>
        保存
      </Button>

      <Button
        mode="outlined"
        disabled={busy || !apiKeyConfigured}
        textColor={theme.colors.error}
        onPress={async () => {
          setBusy(true);
          setError(null);
          try {
            await setCodexApiKey(null);
            setApiKeyConfigured(false);
            setNewApiKey('');
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            setError(msg);
          } finally {
            setBusy(false);
          }
        }}>
        删除密钥
      </Button>
        </ScrollView>

        <Modal
          visible={modelPickerOpen}
          transparent
          animationType="slide"
          onRequestClose={() => setModelPickerOpen(false)}>
          <Pressable style={styles.modalBackdrop} onPress={() => setModelPickerOpen(false)}>
            <Pressable
              accessibilityRole="none"
              onPress={() => {}}
              style={[
                styles.modalSheet,
                {
                  backgroundColor: Colors[colorScheme].surface,
                  borderColor: Colors[colorScheme].outline,
                  paddingBottom: 12 + insets.bottom,
                },
              ]}>
              <View style={styles.modalHeader}>
                <ThemedText type="defaultSemiBold" style={styles.modalTitle}>
                  选择模型
                </ThemedText>
                <Pressable
                  accessibilityRole="button"
                  android_ripple={{ color: rippleColor }}
                  onPress={() => setModelPickerOpen(false)}
                  style={styles.modalClose}>
                  <MaterialIcons name="close" size={22} color={Colors[colorScheme].text} />
                </Pressable>
              </View>

              <PaperTextInput
                mode="outlined"
                value={modelQuery}
                onChangeText={setModelQuery}
                placeholder="搜索模型"
                autoCapitalize="none"
                autoCorrect={false}
                style={{ marginBottom: Spacing.md }}
                autoFocus
              />

              {modelsError ? (
                <ThemedText style={[styles.error, { color: Colors[colorScheme].danger }]}>{modelsError}</ThemedText>
              ) : null}

              <FlatList
                data={filteredModels}
                keyExtractor={(it) => it}
                keyboardShouldPersistTaps="handled"
                style={{ maxHeight: 360 }}
                renderItem={({ item }) => {
                  const selected = item === model;
                  return (
                    <Pressable
                      accessibilityRole="button"
                      android_ripple={{ color: rippleColor }}
                      onPress={() => {
                        setModel(item);
                        setModelPickerOpen(false);
                      }}
                      style={({ pressed }) => [
                        styles.modelRow,
                        {
                          borderColor: Colors[colorScheme].outlineMuted,
                          backgroundColor: pressed
                            ? colorScheme === 'dark'
                              ? 'rgba(255,255,255,0.08)'
                              : 'rgba(0,0,0,0.06)'
                            : 'transparent',
                        },
                      ]}>
                      <ThemedText numberOfLines={1} style={{ flex: 1 }}>
                        {item}
                      </ThemedText>
                      {selected ? (
                        <MaterialIcons name="check" size={20} color={Colors[colorScheme].tint} />
                      ) : null}
                    </Pressable>
                  );
                }}
                ListHeaderComponent={
                  modelsLoading ? (
                    <View style={styles.modalLoading}>
                      <ActivityIndicator />
                    </View>
                  ) : null
                }
                ListEmptyComponent={
                  <View style={styles.modalEmpty}>
                    <ThemedText style={styles.muted}>{modelsLoading ? '正在获取…' : '未找到匹配的模型。'}</ThemedText>
                  </View>
                }
              />
            </Pressable>
          </Pressable>
        </Modal>
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
  card: {
    marginBottom: Spacing.lg,
  },
  input: {
    marginBottom: Spacing.md,
  },
  row2: {
    flexDirection: 'row',
    gap: Spacing.md,
    flexWrap: 'wrap',
  },
  modelPicker: {
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    marginBottom: Spacing.md,
  },
  modelRow: {
    alignItems: 'center',
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    marginBottom: 8,
    overflow: 'hidden',
    paddingHorizontal: 10,
    paddingVertical: 10,
  },
  modalBackdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.35)',
  },
  modalSheet: {
    borderTopLeftRadius: 22,
    borderTopRightRadius: 22,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 14,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  modalTitle: {
    fontSize: 16,
  },
  modalClose: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  modalLoading: {
    paddingVertical: 10,
  },
  modalEmpty: {
    paddingVertical: 18,
  },
  codeBox: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
    padding: 12,
  },
  codeInput: {
    marginBottom: Spacing.md,
  },
  code: {
    fontSize: 12,
    lineHeight: 16,
    fontFamily: Fonts.mono,
  },
  muted: {
    opacity: 0.7,
  },
  error: {
    marginBottom: Spacing.md,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
