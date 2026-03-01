import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
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
import { Colors, Fonts } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import {
  defaultCodexSettings,
  generateCodexConfigToml,
  getCodexSettings,
  hasCodexApiKey,
  materializeCodexConfigFiles,
  setCodexApiKey,
  updateCodexSettings,
  type CodexApprovalPolicy,
  type CodexPersonality,
} from '@/src/codex/settings';

function Segment({
  label,
  active,
  onPress,
  colorScheme,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
  colorScheme: 'light' | 'dark';
}) {
  const tint = Colors[colorScheme].tint;
  const activeBg = colorScheme === 'dark' ? 'rgba(34,211,238,0.16)' : 'rgba(10,126,164,0.12)';
  const rippleColor = colorScheme === 'dark' ? 'rgba(255,255,255,0.14)' : 'rgba(2,6,23,0.08)';
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      android_ripple={{ color: rippleColor }}
      style={({ pressed }) => [
        styles.segment,
        {
          opacity: pressed ? 0.92 : 1,
          backgroundColor: active ? activeBg : 'transparent',
          borderColor: active ? tint : Colors[colorScheme].outline,
        },
      ]}>
      <ThemedText type="defaultSemiBold">{label}</ThemedText>
    </Pressable>
  );
}

export default function SettingsScreen() {
  const colorScheme = useColorScheme() ?? 'light';

  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [enabled, setEnabled] = useState(defaultCodexSettings().enabled);
  const [model, setModel] = useState('');
  const [openaiBaseUrl, setOpenaiBaseUrl] = useState('');
  const [approvalPolicy, setApprovalPolicy] = useState<CodexApprovalPolicy>(defaultCodexSettings().approvalPolicy);
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

  useEffect(() => {
    let cancelled = false;
    async function run() {
      setLoading(true);
      setError(null);
      try {
        const s = await getCodexSettings();
        const hasKey = await hasCodexApiKey();
        if (cancelled) return;
        setEnabled(s.enabled);
        setModel(s.model ?? '');
        setOpenaiBaseUrl(s.openaiBaseUrl ?? '');
        setApprovalPolicy(s.approvalPolicy);
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

  const generatedToml = useMemo(() => {
    return generateCodexConfigToml({
      version: 1,
      enabled,
      model: model.trim() || undefined,
      openaiBaseUrl: openaiBaseUrl.trim() || undefined,
      approvalPolicy,
      personality,
      useRawConfigToml,
      rawConfigToml,
    });
  }, [approvalPolicy, enabled, model, openaiBaseUrl, personality, rawConfigToml, useRawConfigToml]);

  const effectiveToml = useMemo(() => {
    if (useRawConfigToml && rawConfigToml.trim()) return rawConfigToml;
    return generatedToml;
  }, [generatedToml, rawConfigToml, useRawConfigToml]);

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
      <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
        <ScrollView
          contentContainerStyle={styles.container}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag">
          <View style={styles.header}>
            <ThemedText type="title">设置</ThemedText>
            <ThemedText style={styles.muted}>全局设置（所有工作区共用）。</ThemedText>
          </View>

          <ThemedView style={[styles.card, cardStyle]}>
            <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
              Codex
            </ThemedText>

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              启用
            </ThemedText>
            <View style={styles.segments}>
              <Segment label="开启" active={enabled} onPress={() => setEnabled(true)} colorScheme={colorScheme} />
              <Segment label="关闭" active={!enabled} onPress={() => setEnabled(false)} colorScheme={colorScheme} />
            </View>

            <View style={{ height: 12 }} />

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              密钥
            </ThemedText>
            <ThemedText style={[styles.muted, { marginBottom: 8 }]}>状态：{apiKeyConfigured ? '已保存' : '未保存'}</ThemedText>
            <TextInput
              value={newApiKey}
              onChangeText={setNewApiKey}
              placeholder={apiKeyConfigured ? '留空保持不变' : '粘贴你的密钥'}
              placeholderTextColor={placeholderTextColor}
              autoCapitalize="none"
              autoCorrect={false}
              secureTextEntry
              selectionColor={Colors[colorScheme].tint}
              style={[styles.input, inputStyle]}
            />

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              模型（可选）
            </ThemedText>
            <TextInput
              value={model}
              onChangeText={setModel}
              placeholder="留空使用默认"
              placeholderTextColor={placeholderTextColor}
              autoCapitalize="none"
              autoCorrect={false}
              selectionColor={Colors[colorScheme].tint}
              style={[styles.input, inputStyle]}
            />

            <Pressable
              accessibilityRole="button"
              android_ripple={{ color: rippleColor }}
              onPress={() => setShowAdvanced((v) => !v)}
              style={({ pressed }) => [styles.linkButton, { opacity: pressed ? 0.86 : 1 }]}>
              <ThemedText style={styles.muted}>{showAdvanced ? '收起高级选项' : '展开高级选项'}</ThemedText>
            </Pressable>

            {showAdvanced ? (
              <View style={{ marginTop: 10 }}>
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  服务地址（可选）
                </ThemedText>
                <TextInput
                  value={openaiBaseUrl}
                  onChangeText={setOpenaiBaseUrl}
                  placeholder="留空使用默认"
                  placeholderTextColor={placeholderTextColor}
                  autoCapitalize="none"
                  autoCorrect={false}
                  selectionColor={Colors[colorScheme].tint}
                  style={[styles.input, inputStyle]}
                />

                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  确认级别
                </ThemedText>
                <View style={styles.segments}>
                  <Segment
                    label="无需确认"
                    active={approvalPolicy === 'never'}
                    onPress={() => setApprovalPolicy('never')}
                    colorScheme={colorScheme}
                  />
                  <Segment
                    label="按需确认"
                    active={approvalPolicy === 'on-request'}
                    onPress={() => setApprovalPolicy('on-request')}
                    colorScheme={colorScheme}
                  />
                </View>
                <View style={[styles.segments, { marginTop: 10 }]}>
                  <Segment
                    label="失败后确认"
                    active={approvalPolicy === 'on-failure'}
                    onPress={() => setApprovalPolicy('on-failure')}
                    colorScheme={colorScheme}
                  />
                  <Segment
                    label="每次确认"
                    active={approvalPolicy === 'untrusted'}
                    onPress={() => setApprovalPolicy('untrusted')}
                    colorScheme={colorScheme}
                  />
                </View>

                <View style={{ height: 12 }} />

                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  风格
                </ThemedText>
                <View style={styles.segments}>
                  <Segment
                    label="默认"
                    active={personality === 'none'}
                    onPress={() => setPersonality('none')}
                    colorScheme={colorScheme}
                  />
                  <Segment
                    label="友好"
                    active={personality === 'friendly'}
                    onPress={() => setPersonality('friendly')}
                    colorScheme={colorScheme}
                  />
                  <Segment
                    label="务实"
                    active={personality === 'pragmatic'}
                    onPress={() => setPersonality('pragmatic')}
                    colorScheme={colorScheme}
                  />
                </View>

                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  思考内容
                </ThemedText>
                <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
                  默认隐藏，避免占用屏幕。
                </ThemedText>
                <View style={styles.segments}>
                  <Segment
                    label="隐藏"
                    active={!uiShowThinking}
                    onPress={() => setUiShowThinking(false)}
                    colorScheme={colorScheme}
                  />
                  <Segment
                    label="显示"
                    active={uiShowThinking}
                    onPress={() => setUiShowThinking(true)}
                    colorScheme={colorScheme}
                  />
                </View>

                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  调试日志
                </ThemedText>
                <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
                  默认关闭。开启后会在本机记录错误与关键事件，用于排查问题。
                </ThemedText>
                <View style={styles.segments}>
                  <Segment
                    label="关闭"
                    active={!debugLogToFile}
                    onPress={() => setDebugLogToFile(false)}
                    colorScheme={colorScheme}
                  />
                  <Segment
                    label="开启"
                    active={debugLogToFile}
                    onPress={() => setDebugLogToFile(true)}
                    colorScheme={colorScheme}
                  />
                </View>
                <View style={{ height: 12 }} />
                <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                  保留天数
                </ThemedText>
                <TextInput
                  value={debugLogRetentionDays}
                  onChangeText={(v) => setDebugLogRetentionDays(v.replace(/[^0-9]/g, ''))}
                  placeholder="7"
                  placeholderTextColor={placeholderTextColor}
                  keyboardType="number-pad"
                  selectionColor={Colors[colorScheme].tint}
                  style={[styles.input, inputStyle]}
                />
                <ThemedText style={styles.muted}>范围：1–90 天。</ThemedText>
              </View>
            ) : null}
          </ThemedView>

      <ThemedView style={[styles.card, cardStyle]}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          配置文件
        </ThemedText>
        <ThemedText style={[styles.muted, { marginBottom: 8 }]}>
          提示：不要在配置文件中粘贴密钥，密钥请在上方单独设置。
        </ThemedText>

        <View style={styles.segments}>
          <Segment
            label="自动生成"
            active={!useRawConfigToml}
            onPress={() => {
              setUseRawConfigToml(false);
            }}
            colorScheme={colorScheme}
          />
          <Segment
            label="自定义"
            active={useRawConfigToml}
            onPress={() => {
              setUseRawConfigToml(true);
              if (!rawConfigToml.trim()) setRawConfigToml(generatedToml);
            }}
            colorScheme={colorScheme}
          />
        </View>

        <View style={{ height: 10 }} />

        {useRawConfigToml ? (
          <>
            <View style={styles.row2}>
              <Pressable
                accessibilityRole="button"
                android_ripple={{ color: rippleColor }}
                disabled={busy}
                onPress={() => {
                  setUseRawConfigToml(true);
                  setRawConfigToml(generatedToml);
                }}
                style={({ pressed }) => [
                  styles.smallButton,
                  {
                    opacity: busy ? 0.4 : pressed ? 0.92 : 1,
                    borderColor: Colors[colorScheme].outline,
                    backgroundColor: Colors[colorScheme].surface2,
                  },
                ]}>
                <ThemedText type="defaultSemiBold">从当前设置生成</ThemedText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                android_ripple={{ color: rippleColor }}
                disabled={busy}
                onPress={() => {
                  setUseRawConfigToml(false);
                  setRawConfigToml('');
                }}
                style={({ pressed }) => [
                  styles.smallButton,
                  {
                    opacity: busy ? 0.4 : pressed ? 0.92 : 1,
                    borderColor: Colors[colorScheme].outline,
                    backgroundColor: Colors[colorScheme].surface2,
                  },
                ]}>
                <ThemedText type="defaultSemiBold">恢复默认</ThemedText>
              </Pressable>
            </View>
            <View style={{ height: 10 }} />
            <TextInput
              value={rawConfigToml}
              onChangeText={setRawConfigToml}
              placeholder="在这里编辑配置内容"
              placeholderTextColor={placeholderTextColor}
              autoCapitalize="none"
              autoCorrect={false}
              multiline
              textAlignVertical="top"
              selectionColor={Colors[colorScheme].tint}
              style={[styles.codeInput, inputStyle]}
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
      </ThemedView>

      {error ? <ThemedText style={[styles.error, { color: Colors[colorScheme].danger }]}>{error}</ThemedText> : null}

      <Pressable
        accessibilityRole="button"
        android_ripple={{ color: rippleColor }}
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
              enabled,
              model: model.trim() || undefined,
              openaiBaseUrl: openaiBaseUrl.trim() || undefined,
              approvalPolicy,
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
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            setError(msg);
          } finally {
            setBusy(false);
          }
        }}
        style={({ pressed }) => [
          styles.primaryButton,
          { opacity: busy ? 0.5 : pressed ? 0.85 : 1, backgroundColor: Colors[colorScheme].tint },
        ]}>
        {busy ? (
          <ActivityIndicator />
        ) : (
          <ThemedText type="defaultSemiBold" style={{ color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }}>
            保存
          </ThemedText>
        )}
      </Pressable>

      <Pressable
        accessibilityRole="button"
        android_ripple={{ color: rippleColor }}
        disabled={busy || !apiKeyConfigured}
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
        }}
        style={({ pressed }) => [
          styles.secondaryButton,
          {
            opacity: busy || !apiKeyConfigured ? 0.4 : pressed ? 0.85 : 1,
            borderColor: Colors[colorScheme].danger,
            backgroundColor: Colors[colorScheme].surface,
          },
        ]}>
        <ThemedText type="defaultSemiBold" style={{ color: Colors[colorScheme].danger }}>
          删除密钥
        </ThemedText>
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
    paddingTop: 20,
    paddingHorizontal: 16,
    paddingBottom: 32,
  },
  header: {
    marginBottom: 16,
  },
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
  segments: {
    flexDirection: 'row',
    gap: 10,
    flexWrap: 'wrap',
  },
  segment: {
    flex: 1,
    minHeight: 44,
    borderWidth: 1,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 10,
    overflow: 'hidden',
  },
  input: {
    borderWidth: 1,
    borderRadius: 12,
    minHeight: 48,
    paddingVertical: 12,
    paddingHorizontal: 14,
    fontSize: 16,
    lineHeight: 20,
    marginBottom: 12,
  },
  linkButton: {
    alignSelf: 'flex-start',
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 10,
    overflow: 'hidden',
  },
  row2: {
    flexDirection: 'row',
    gap: 10,
    flexWrap: 'wrap',
  },
  smallButton: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 12,
    minWidth: 160,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    overflow: 'hidden',
  },
  codeBox: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
    padding: 12,
  },
  codeInput: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 12,
    minHeight: 180,
    fontSize: 12,
    lineHeight: 16,
    fontFamily: Fonts.mono,
  },
  code: {
    fontSize: 12,
    lineHeight: 16,
    fontFamily: Fonts.mono,
  },
  primaryButton: {
    minHeight: 48,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
    marginTop: 8,
    overflow: 'hidden',
  },
  secondaryButton: {
    minHeight: 48,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
    marginTop: 8,
    borderWidth: 1,
    overflow: 'hidden',
  },
  muted: {
    opacity: 0.7,
  },
  error: {
    marginBottom: 12,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
