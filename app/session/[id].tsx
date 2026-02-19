import { useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, StyleSheet, TextInput, View } from 'react-native';

import { Stack, useLocalSearchParams, useRouter } from 'expo-router';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { runCodexTurn } from '@/src/codex/sessionRunner';
import { appendMessage, listMessages, listSessions, renameSession } from '@/src/sessions/store';
import type { ChatMessage, Session } from '@/src/sessions/types';
import { useWorkspaces } from '@/src/workspaces/provider';
import { uuidV4 } from '@/src/utils/uuid';

export default function SessionDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const sessionId = typeof id === 'string' ? id : '';

  const colorScheme = useColorScheme() ?? 'light';
  const { workspaces, activeWorkspaceId } = useWorkspaces();

  const active = useMemo(
    () => workspaces.find((w) => w.id === activeWorkspaceId) ?? null,
    [activeWorkspaceId, workspaces]
  );

  const listRef = useRef<FlatList<ChatMessage>>(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);

  const [draftTitle, setDraftTitle] = useState('');
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function run() {
      if (!active || !sessionId) {
        setLoading(false);
        setError('未选择工作区，或会话不存在。');
        return;
      }

      setLoading(true);
      setError(null);
      try {
        const [allSessions, msgs] = await Promise.all([listSessions(active.id), listMessages(active.id, sessionId)]);
        const s = allSessions.find((x) => x.id === sessionId) ?? null;
        if (!cancelled) {
          setSession(s);
          setDraftTitle(s?.title ?? '');
          setMessages(msgs);
        }
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        if (!cancelled) setError(message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    run();
    return () => {
      cancelled = true;
    };
  }, [active, sessionId]);

  async function onSend() {
    if (!active || !sessionId) return;
    const text = input.trim();
    if (!text || sending) return;

    setSending(true);
    setError(null);
    setInput('');

    const now = Date.now();
    const userMsg: ChatMessage = {
      id: uuidV4(),
      sessionId,
      workspaceId: active.id,
      role: 'user',
      createdAt: now,
      content: text,
    };

    const assistantId = uuidV4();
    const assistantCreatedAt = Date.now();
    const assistantMsg: ChatMessage = {
      id: assistantId,
      sessionId,
      workspaceId: active.id,
      role: 'assistant',
      createdAt: assistantCreatedAt,
      content: '',
    };

    setMessages((prev) => [...prev, userMsg, assistantMsg]);
    requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));

    let assistantText = '';
    try {
      for await (const ev of runCodexTurn({ workspace: active, sessionId, input: text })) {
        if (ev.type === 'text') {
          assistantText += ev.text;
          setMessages((prev) =>
            prev.map((m) => (m.id === assistantId ? { ...m, content: assistantText } : m))
          );
        }
        if (ev.type === 'error') {
          assistantText = assistantText ? assistantText : ev.message;
          setMessages((prev) =>
            prev.map((m) => (m.id === assistantId ? { ...m, content: assistantText } : m))
          );
        }
      }

      // Persist only final messages (avoid excessive writes during streaming).
      await appendMessage(active.id, sessionId, {
        sessionId,
        workspaceId: active.id,
        role: 'user',
        createdAt: now,
        content: text,
      });
      await appendMessage(active.id, sessionId, {
        sessionId,
        workspaceId: active.id,
        role: 'assistant',
        createdAt: assistantCreatedAt,
        content: assistantText,
      });
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      setError(message);
      setMessages((prev) =>
        prev.map((m) => (m.id === assistantId ? { ...m, content: message } : m))
      );
    } finally {
      setSending(false);
    }
  }

  if (!active) {
    return (
      <ThemedView style={styles.container}>
        <Stack.Screen options={{ title: '会话' }} />
        <ThemedText type="title">会话</ThemedText>
        <ThemedText style={styles.muted}>请先选择一个工作区。</ThemedText>
      </ThemedView>
    );
  }

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen
        options={{
          title: session?.title ?? '会话',
          headerRight: () => (
            <Pressable accessibilityRole="button" onPress={() => router.back()} style={{ paddingHorizontal: 12 }}>
              <ThemedText type="defaultSemiBold">关闭</ThemedText>
            </Pressable>
          ),
        }}
      />

      <ThemedView style={styles.topCard}>
        <ThemedText style={styles.muted}>
          工作区：<ThemedText type="defaultSemiBold">{active.name}</ThemedText>
        </ThemedText>

        <TextInput
          value={draftTitle}
          onChangeText={setDraftTitle}
          placeholder="会话标题"
          placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
          style={[
            styles.titleInput,
            {
              color: Colors[colorScheme].text,
              borderColor: Colors[colorScheme].icon,
              backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
            },
          ]}
          onBlur={async () => {
            if (!session) return;
            const next = draftTitle.trim();
            if (next && next !== session.title) {
              await renameSession(active.id, session.id, next);
              const allSessions = await listSessions(active.id);
              const s = allSessions.find((x) => x.id === session.id) ?? null;
              setSession(s);
            }
          }}
        />
      </ThemedView>

      {error ? (
        <ThemedText style={[styles.error, { color: '#ef4444' }]}>{error}</ThemedText>
      ) : null}

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator />
        </View>
      ) : (
        <FlatList
          ref={listRef}
          data={messages}
          keyExtractor={(m) => m.id}
          contentContainerStyle={{ paddingBottom: 16 }}
          renderItem={({ item }) => (
            <ThemedView
              style={[
                styles.msg,
                item.role === 'user' ? styles.msgUser : styles.msgAssistant,
                {
                  borderColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.10)',
                },
              ]}>
              <ThemedText type="defaultSemiBold" style={{ marginBottom: 6 }}>
                {item.role === 'user' ? '你' : item.role === 'assistant' ? 'Codex' : '系统'}
              </ThemedText>
              <ThemedText>{item.content}</ThemedText>
            </ThemedView>
          )}
          ListEmptyComponent={<ThemedText style={styles.muted}>还没有消息。</ThemedText>}
        />
      )}

      <View
        style={[
          styles.composer,
          { borderColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.12)' },
        ]}>
        <TextInput
          value={input}
          onChangeText={setInput}
          placeholder="输入你的问题…"
          placeholderTextColor={colorScheme === 'dark' ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'}
          style={[
            styles.composerInput,
            {
              color: Colors[colorScheme].text,
              backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
            },
          ]}
          multiline
        />
        <Pressable
          accessibilityRole="button"
          disabled={sending || !input.trim()}
          onPress={onSend}
          style={({ pressed }) => [
            styles.sendButton,
            {
              opacity: sending || !input.trim() ? 0.4 : pressed ? 0.85 : 1,
              backgroundColor: Colors[colorScheme].tint,
            },
          ]}>
          <ThemedText type="defaultSemiBold" style={{ color: colorScheme === 'dark' ? '#0b1220' : '#ffffff' }}>
            发送
          </ThemedText>
        </Pressable>
      </View>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 12,
    paddingHorizontal: 12,
  },
  topCard: {
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    borderRadius: 14,
    padding: 12,
    marginBottom: 10,
  },
  titleInput: {
    borderWidth: 1,
    borderRadius: 12,
    paddingVertical: 8,
    paddingHorizontal: 10,
    fontSize: 16,
    marginTop: 8,
  },
  msg: {
    borderWidth: 1,
    borderRadius: 14,
    padding: 12,
    marginBottom: 10,
  },
  msgUser: {
    backgroundColor: 'rgba(59,130,246,0.10)',
  },
  msgAssistant: {
    backgroundColor: 'rgba(0,0,0,0.02)',
  },
  composer: {
    borderTopWidth: 1,
    paddingTop: 10,
    paddingBottom: 6,
    gap: 10,
  },
  composerInput: {
    minHeight: 44,
    maxHeight: 140,
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 12,
    fontSize: 16,
  },
  sendButton: {
    minHeight: 44,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  muted: {
    opacity: 0.7,
  },
  error: {
    marginBottom: 8,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
