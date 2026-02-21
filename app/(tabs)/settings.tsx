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
import { Colors } from '@/constants/theme';
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

      <ThemedView style={styles.card}>
        <ThemedText type="subtitle" style={{ marginBottom: 8 }}>
          Codex
        </ThemedText>

        <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
          启用
        </ThemedText>
        <View style={styles.segments}>
          <Segment label="开启" active={enabled} onPress={() => setEnabled(true)} />
          <Segment label="关闭" active={!enabled} onPress={() => setEnabled(false)} />
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
          模型（可选）
        </ThemedText>
        <TextInput
          value={model}
          onChangeText={setModel}
          placeholder="留空使用默认"
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

        <Pressable
          accessibilityRole="button"
          onPress={() => setShowAdvanced((v) => !v)}
          style={({ pressed }) => [styles.linkButton, { opacity: pressed ? 0.8 : 1 }]}>
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
              确认级别
            </ThemedText>
            <View style={styles.segments}>
              <Segment label="无需确认" active={approvalPolicy === 'never'} onPress={() => setApprovalPolicy('never')} />
              <Segment
                label="按需确认"
                active={approvalPolicy === 'on-request'}
                onPress={() => setApprovalPolicy('on-request')}
              />
            </View>
            <View style={[styles.segments, { marginTop: 10 }]}>
              <Segment
                label="失败后确认"
                active={approvalPolicy === 'on-failure'}
                onPress={() => setApprovalPolicy('on-failure')}
              />
              <Segment
                label="每次确认"
                active={approvalPolicy === 'untrusted'}
                onPress={() => setApprovalPolicy('untrusted')}
              />
            </View>

            <View style={{ height: 12 }} />

            <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
              风格
            </ThemedText>
            <View style={styles.segments}>
              <Segment label="默认" active={personality === 'none'} onPress={() => setPersonality('none')} />
              <Segment label="友好" active={personality === 'friendly'} onPress={() => setPersonality('friendly')} />
              <Segment label="务实" active={personality === 'pragmatic'} onPress={() => setPersonality('pragmatic')} />
            </View>
          </View>
        ) : null}
      </ThemedView>

      <ThemedView style={styles.card}>
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
          />
          <Segment
            label="自定义"
            active={useRawConfigToml}
            onPress={() => {
              setUseRawConfigToml(true);
              if (!rawConfigToml.trim()) setRawConfigToml(generatedToml);
            }}
          />
        </View>

        <View style={{ height: 10 }} />

        {useRawConfigToml ? (
          <>
            <View style={styles.row2}>
              <Pressable
                accessibilityRole="button"
                disabled={busy}
                onPress={() => {
                  setUseRawConfigToml(true);
                  setRawConfigToml(generatedToml);
                }}
                style={({ pressed }) => [styles.smallButton, { opacity: busy ? 0.4 : pressed ? 0.85 : 1 }]}>
                <ThemedText type="defaultSemiBold">从当前设置生成</ThemedText>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                disabled={busy}
                onPress={() => {
                  setUseRawConfigToml(false);
                  setRawConfigToml('');
                }}
                style={({ pressed }) => [styles.smallButton, { opacity: busy ? 0.4 : pressed ? 0.85 : 1 }]}>
                <ThemedText type="defaultSemiBold">恢复默认</ThemedText>
              </Pressable>
            </View>
            <View style={{ height: 10 }} />
            <TextInput
              value={rawConfigToml}
              onChangeText={setRawConfigToml}
              placeholder="在这里编辑配置内容"
              placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
              autoCapitalize="none"
              autoCorrect={false}
              multiline
              textAlignVertical="top"
              style={[
                styles.codeInput,
                {
                  color: Colors[colorScheme].text,
                  borderColor: Colors[colorScheme].icon,
                  backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
                },
              ]}
            />
          </>
        ) : (
          <ThemedView
            style={[
              styles.codeBox,
              {
                borderColor: Colors[colorScheme].icon,
                backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              },
            ]}>
            <ThemedText style={styles.code}>{effectiveToml}</ThemedText>
          </ThemedView>
        )}
      </ThemedView>

      {error ? <ThemedText style={[styles.error, { color: '#ef4444' }]}>{error}</ThemedText> : null}

      <Pressable
        accessibilityRole="button"
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
            await updateCodexSettings({
              enabled,
              model: model.trim() || undefined,
              openaiBaseUrl: openaiBaseUrl.trim() || undefined,
              approvalPolicy,
              personality,
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
            borderColor: Colors[colorScheme].icon,
          },
        ]}>
        <ThemedText style={styles.muted}>删除密钥</ThemedText>
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
    paddingTop: 24,
    paddingHorizontal: 16,
    paddingBottom: 24,
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
  linkButton: {
    paddingVertical: 8,
  },
  row2: {
    flexDirection: 'row',
    gap: 10,
  },
  smallButton: {
    flex: 1,
    minHeight: 40,
    borderWidth: 1,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 10,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  codeBox: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 10,
  },
  codeInput: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 10,
    minHeight: 180,
    fontSize: 12,
    lineHeight: 16,
  },
  code: {
    fontSize: 12,
    lineHeight: 16,
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
    marginTop: 8,
    borderWidth: 1,
  },
  muted: {
    opacity: 0.7,
  },
  error: {
    marginTop: 4,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
