import { useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, Pressable, StyleSheet, TextInput, View } from 'react-native';

import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import * as FileSystem from 'expo-file-system/legacy';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { CODEX_SLASH_COMMANDS } from '@/src/codex/slashCommands';
import { getCodexSettings, materializeCodexConfigFiles, setCodexApiKey, updateCodexSettings } from '@/src/codex/settings';
import { runCodexTurn } from '@/src/codex/sessionRunner';
import { gitDiff } from '@/src/git/nativeGit';
import {
  appendMessage,
  cloneSessionMessages,
  createSession,
  listMessages,
  listSessions,
  renameSession,
  setSessionCodexCollaborationMode,
  setSessionCodexThreadId,
} from '@/src/sessions/store';
import type { ChatMessage, Session } from '@/src/sessions/types';
import { ensureWorkspaceDirs, workspaceRepoPath } from '@/src/workspaces/paths';
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
  const pendingMentionsRef = useRef<string[]>([]);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);

  const [draftTitle, setDraftTitle] = useState('');
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [waitingFirstToken, setWaitingFirstToken] = useState(false);
  const [pendingAssistantId, setPendingAssistantId] = useState<string | null>(null);
  const [collaborationMode, setCollaborationMode] = useState<Session['codexCollaborationMode']>('code');

  const slashToken = useMemo(() => {
    const trimmed = input.trimStart();
    if (!trimmed.startsWith('/')) return null;
    // 仅在“命令输入阶段”显示（出现空白字符后视为已进入参数阶段，关闭联想面板）
    if (/\s/.test(trimmed)) return null;
    return trimmed;
  }, [input]);

  const slashMatches = useMemo(() => {
    if (slashToken === null) return [];
    const query = slashToken.slice(1).toLowerCase();
    if (!query) return CODEX_SLASH_COMMANDS;
    return CODEX_SLASH_COMMANDS.filter((c) => c.command.slice(1).toLowerCase().startsWith(query));
  }, [slashToken]);

  function applySlashCommand(command: string) {
    setInput((prev) => {
      const leadingWhitespace = prev.match(/^\s*/)?.[0] ?? '';
      const trimmed = prev.slice(leadingWhitespace.length);
      if (!trimmed.startsWith('/')) return `${leadingWhitespace}${command} `;
      const firstWhitespaceIdx = trimmed.search(/\s/);
      if (firstWhitespaceIdx === -1) return `${leadingWhitespace}${command} `;
      return `${leadingWhitespace}${command}${trimmed.slice(firstWhitespaceIdx)}`;
    });
  }

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
          setCollaborationMode(s?.codexCollaborationMode ?? 'code');
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

    const firstToken = text.split(/\s+/, 1)[0] ?? '';
    const isSlashCommand = CODEX_SLASH_COMMANDS.some((c) => c.command === firstToken);
    const slashArgs = text.slice(firstToken.length).trim();

    // 导航类命令：不进入消息流（避免卸载后 setState）
    if (isSlashCommand && (firstToken === '/exit' || firstToken === '/quit')) {
      setInput('');
      router.back();
      return;
    }
    if (isSlashCommand && firstToken === '/new') {
      setInput('');
      const next = await createSession(active.id, undefined, {
        mcpEnabledServerIds: active.mcpDefaultEnabledServerIds ?? [],
      });
      router.replace(`/session/${next.id}`);
      return;
    }
    if (isSlashCommand && firstToken === '/resume' && slashArgs) {
      const target = (slashArgs.split(/\s+/, 1)[0] ?? '').trim();
      if (target) {
        setInput('');
        router.replace(`/session/${target}`);
        return;
      }
    }

    const isSlashPlanToggle =
      isSlashCommand && firstToken === '/plan' && (!slashArgs || slashArgs === 'on' || slashArgs === 'off');
    const isSlashPlanTurn = isSlashCommand && firstToken === '/plan' && !isSlashPlanToggle;
    const isSlashReview = isSlashCommand && firstToken === '/review';
    const isSlashRpc =
      isSlashCommand &&
      (firstToken === '/compact' ||
        firstToken === '/debug-config' ||
        firstToken === '/mcp' ||
        firstToken === '/apps' ||
        firstToken === '/ps' ||
        firstToken === '/fork' ||
        firstToken === '/agent');

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
    const assistantRole: ChatMessage['role'] =
      !isSlashCommand || isSlashPlanTurn || isSlashReview ? 'assistant' : 'system';

    const assistantMsg: ChatMessage = {
      id: assistantId,
      sessionId,
      workspaceId: active.id,
      role: assistantRole,
      createdAt: assistantCreatedAt,
      content: assistantRole === 'system' ? `正在执行 ${firstToken}…` : '',
    };

    let assistantText = '';
    let sawFirstDelta = false;
    let forkedThreadId: string | null = null;
    let didNavigate = false;

    try {
      setMessages((prev) => [...prev, userMsg, assistantMsg]);
      requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));

      const finishLocal = async (opts: { role: ChatMessage['role']; content: string }) => {
        assistantText = opts.content;
        setMessages((prev) =>
          prev.length && prev[prev.length - 1]?.id === assistantId
            ? [...prev.slice(0, -1), { ...prev[prev.length - 1], role: opts.role, content: assistantText }]
            : prev.map((m) => (m.id === assistantId ? { ...m, role: opts.role, content: assistantText } : m))
        );
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
          role: opts.role,
          createdAt: assistantCreatedAt,
          content: assistantText,
        });
      };

      if (isSlashCommand) {
        // 本地命令（不发给 Codex）
        if (firstToken === '/init') {
          await ensureWorkspaceDirs(active.id);
          const path = `${workspaceRepoPath(active.id)}AGENTS.md`;
          const exists = await FileSystem.getInfoAsync(path);
          if (exists.exists) {
            await finishLocal({ role: 'system', content: 'AGENTS.md 已存在（未覆盖）。' });
          } else {
            /*
            const scaffold = `# Repository Guidelines\n\n在这里记录本仓库的协作约定，让 Codex 与贡献者遵循一致的结构、命令与风格。\n\n## Project Structure\n- 源码：例如 \\`src/\\`、\\`app/\\`、\\`packages/\\`\n- 资源：例如 \\`assets/\\`\n- 文档：例如 \\`docs/\\`\n\n## Build & Dev Commands\n- \\`npm install\\`：安装依赖\n- \\`npm run lint\\`：代码检查\n- \\`npx tsc --noEmit\\`：类型检查\n\n## Coding Style\n- 语言/框架：在此填写（TypeScript/React/…）\n- 缩进：2 或 4 空格（按项目实际情况）\n- 命名：文件/组件/函数命名约定\n\n## Testing\n- 测试框架：在此填写（Jest/Vitest/…）\n- 运行方式：例如 \\`npm test\\`\n\n## PR Checklist\n- 描述清晰、关联 Issue\n- 关键改动附截图（UI）或日志（后端）\n- 覆盖必要测试与手动验证步骤\n`;
            */
            const scaffold =
              [
                '# Repository Guidelines',
                '',
                '在这里记录本仓库的协作约定，让 Codex 与贡献者遵循一致的结构、命令与风格。',
                '',
                '## Project Structure',
                '- 源码：例如 `src/`、`app/`、`packages/`',
                '- 资源：例如 `assets/`',
                '- 文档：例如 `docs/`',
                '',
                '## Build & Dev Commands',
                '- `npm install`：安装依赖',
                '- `npm run lint`：代码检查',
                '- `npx tsc --noEmit`：类型检查',
                '',
                '## Coding Style',
                '- 语言/框架：在此填写（TypeScript/React/…）',
                '- 缩进：2 或 4 空格（按项目实际情况）',
                '- 命名：文件/组件/函数命名约定',
                '',
                '## Testing',
                '- 测试框架：在此填写（Jest/Vitest/…）',
                '- 运行方式：例如 `npm test`',
                '',
                '## PR Checklist',
                '- 描述清晰、关联 Issue',
                '- 关键改动附截图（UI）或日志（后端）',
                '- 覆盖必要测试与手动验证步骤',
                '',
              ].join('\n') + '\n';
            await FileSystem.writeAsStringAsync(path, scaffold);
            await finishLocal({ role: 'system', content: '已生成 AGENTS.md（请根据仓库实际情况补充/修改）。' });
          }
          return;
        }

        if (isSlashPlanToggle) {
          const nextMode =
            slashArgs === 'on'
              ? 'plan'
              : slashArgs === 'off'
                ? 'code'
                : collaborationMode === 'plan'
                  ? 'code'
                  : 'plan';
          setCollaborationMode(nextMode);
          await setSessionCodexCollaborationMode(active.id, sessionId, nextMode);
          await finishLocal({
            role: 'system',
            content: nextMode === 'plan' ? '已切换到计划模式。' : '已切换回代码模式。',
          });
          return;
        }

        if (firstToken === '/diff') {
          try {
            const patch = await gitDiff({ localRepoDirUri: workspaceRepoPath(active.id), maxBytes: 200_000 });
            const content = patch.trim()
              ? patch.length >= 200_000
                ? `${patch}\n\n（已截断：输出超过 200KB）`
                : patch
              : '当前工作区没有 Git diff。';
            await finishLocal({ role: 'system', content });
          } catch (e) {
            const message = e instanceof Error ? e.message : String(e);
            await finishLocal({ role: 'system', content: `获取 diff 失败：\n${message}` });
          }
          return;
        }

        if (firstToken === '/status') {
          const s = await getCodexSettings();
          const lines = [
            `工作区：${active.name} (${active.id})`,
            `会话：${session?.title ?? sessionId} (${sessionId})`,
            `线程：${session?.codexThreadId ?? '（未创建）'}`,
            `模式：${collaborationMode === 'plan' ? '计划' : '代码'}`,
            `模型：${s.model ?? '（默认）'}`,
            `权限：${s.approvalPolicy}`,
            `风格：${s.personality}`,
            `Repo：${workspaceRepoPath(active.id)}`,
          ];
          await finishLocal({ role: 'system', content: lines.join('\n') });
          return;
        }

        if (firstToken === '/permissions') {
          type Policy = 'untrusted' | 'on-request' | 'on-failure' | 'never';
          const isPolicy = (v: string): v is Policy =>
            v === 'untrusted' || v === 'on-request' || v === 'on-failure' || v === 'never';

          const s = await getCodexSettings();
          const raw = (slashArgs.split(/\s+/, 1)[0] ?? '').trim().toLowerCase();
          const mapped = raw === 'auto' ? 'never' : raw;

          if (!mapped || !isPolicy(mapped)) {
            await finishLocal({
              role: 'system',
              content:
                `当前权限策略：${s.approvalPolicy}\n\n` +
                `用法：/permissions <policy>\n` +
                `可选：untrusted | on-request | on-failure | never\n` +
                `提示：/permissions auto 等价于 /permissions never`,
            });
            return;
          }

          await updateCodexSettings({ approvalPolicy: mapped });
          await materializeCodexConfigFiles();
          await finishLocal({ role: 'system', content: `已更新权限策略为：${mapped}` });
          return;
        }

        if (firstToken === '/personality') {
          type P = 'friendly' | 'pragmatic' | 'none';
          const isP = (v: string): v is P => v === 'friendly' || v === 'pragmatic' || v === 'none';

          const s = await getCodexSettings();
          const raw = (slashArgs.split(/\s+/, 1)[0] ?? '').trim().toLowerCase();
          if (!raw || !isP(raw)) {
            await finishLocal({
              role: 'system',
              content:
                `当前风格：${s.personality}\n\n` +
                `用法：/personality <style>\n` +
                `可选：friendly | pragmatic | none`,
            });
            return;
          }

          await updateCodexSettings({ personality: raw });
          await materializeCodexConfigFiles();
          await finishLocal({ role: 'system', content: `已更新风格为：${raw}` });
          return;
        }

        if (firstToken === '/model') {
          const s = await getCodexSettings();
          const raw = (slashArgs.split(/\s+/, 1)[0] ?? '').trim();
          if (!raw) {
            await finishLocal({
              role: 'system',
              content: `当前模型：${s.model ?? '（默认）'}\n\n用法：/model <model-id>`,
            });
            return;
          }
          await updateCodexSettings({ model: raw });
          await materializeCodexConfigFiles();
          await finishLocal({ role: 'system', content: `已更新模型为：${raw}` });
          return;
        }

        if (firstToken === '/experimental') {
          const parts = slashArgs.split(/\s+/).filter(Boolean);
          const feature = (parts[0] ?? '').toLowerCase();
          const value = (parts[1] ?? '').toLowerCase();
          const s = await getCodexSettings();

          if (!feature) {
            await finishLocal({
              role: 'system',
              content:
                `当前实验特性：\n- multi_agent = ${s.featuresMultiAgent ? 'on' : 'off'}\n\n` +
                `用法：/experimental multi_agent on|off`,
            });
            return;
          }

          if (feature !== 'multi_agent' && feature !== 'multi-agent') {
            await finishLocal({ role: 'system', content: `未知实验特性：${feature}\n\n用法：/experimental multi_agent on|off` });
            return;
          }

          const enable = value === 'on' || value === 'true' || value === '1';
          const disable = value === 'off' || value === 'false' || value === '0';
          if (!enable && !disable) {
            await finishLocal({ role: 'system', content: `用法：/experimental multi_agent on|off` });
            return;
          }

          await updateCodexSettings({ featuresMultiAgent: enable });
          await materializeCodexConfigFiles();
          await finishLocal({
            role: 'system',
            content: `已更新 experimental multi_agent = ${enable ? 'on' : 'off'}（下一次 turn 生效）`,
          });
          return;
        }

        if (firstToken === '/logout') {
          await setCodexApiKey(null);
          await materializeCodexConfigFiles();
          await finishLocal({ role: 'system', content: '已清除本地密钥（已退出）。' });
          return;
        }

        if (firstToken === '/resume' && !slashArgs) {
          const all = await listSessions(active.id);
          const top = all.slice(0, 12);
          const lines = ['可恢复的会话（最近 12 条）：', ...top.map((s) => `- ${s.id}  ${s.title}`), '', '用法：/resume <sessionId>'];
          await finishLocal({ role: 'system', content: lines.join('\n') });
          return;
        }

        if (firstToken === '/mention') {
          const raw = slashArgs.trim();
          if (!raw) {
            const pending = pendingMentionsRef.current;
            await finishLocal({
              role: 'system',
              content:
                `用法：/mention <path>\n` +
                `清空：/mention clear\n\n` +
                (pending.length ? `已标记（待下次发送）：\n${pending.map((p) => `- ${p}`).join('\n')}` : '当前没有待发送的标记路径。'),
            });
            return;
          }
          if (raw === 'clear' || raw === '--clear') {
            pendingMentionsRef.current = [];
            await finishLocal({ role: 'system', content: '已清空待发送的标记路径。' });
            return;
          }

          const cleaned = raw.replace(/^['\"]|['\"]$/g, '').trim();
          if (!cleaned) {
            await finishLocal({ role: 'system', content: '路径为空：用法 /mention <path>' });
            return;
          }

          if (!pendingMentionsRef.current.includes(cleaned)) pendingMentionsRef.current.push(cleaned);
          await finishLocal({
            role: 'system',
            content: `已标记：${cleaned}\n（下一条消息会自动附带“请重点关注该路径”的提示）`,
          });
          return;
        }

        if (firstToken === '/apps' && slashArgs) {
          const slug = slashArgs.trim().replace(/^\$+/, '');
          if (slug) {
            setInput(`$${slug} `);
            await finishLocal({ role: 'system', content: `已插入：$${slug}` });
            return;
          }
        }

        if (firstToken === '/statusline') {
          await finishLocal({ role: 'system', content: '移动端没有 CLI 状态栏：/statusline 在本应用中不适用。' });
          return;
        }

        if (firstToken === '/sandbox-add-read-dir') {
          await finishLocal({
            role: 'system',
            content: '该命令仅适用于 Windows 原生 CLI 的 sandbox。本应用在 Android 上不支持 /sandbox-add-read-dir。',
          });
          return;
        }

        if (firstToken === '/feedback') {
          await finishLocal({
            role: 'system',
            content:
              '本应用暂未实现自动打包日志并上报。\n' +
              '请在 GitHub issue 中附上：Codex 版本、机型/系统版本、复现步骤、以及相关 logcat 片段。',
          });
          return;
        }
      }

      // Codex-backed：turn / review / rpc
      setPendingAssistantId(assistantId);
      setWaitingFirstToken(true);

      const PLAN_PREFIX =
        '你处于计划模式。请先输出一个可执行的计划（步骤、依赖、风险、验证方式），在我确认前不要执行命令/不要修改文件。\n\n任务：';

      const pendingMentions = pendingMentionsRef.current;
      const mentionPrefix = pendingMentions.length
        ? `请重点关注以下路径：\n${pendingMentions.map((p) => `- ${p}`).join('\n')}\n\n`
        : '';
      if (pendingMentions.length && !isSlashRpc && !isSlashReview) pendingMentionsRef.current = [];

      const turnKind: 'turn' | 'review' | 'rpc' = isSlashReview ? 'review' : isSlashRpc ? 'rpc' : 'turn';
      const turnInputBase = isSlashPlanTurn
        ? `${PLAN_PREFIX}${slashArgs}`
        : collaborationMode === 'plan'
          ? `${PLAN_PREFIX}${text}`
          : text;
      const turnInput = mentionPrefix ? `${mentionPrefix}${turnInputBase}` : turnInputBase;

      const turnCollabMode: 'code' | 'plan' = isSlashPlanTurn ? 'plan' : collaborationMode === 'plan' ? 'plan' : 'code';

      if (isSlashPlanTurn) {
        setCollaborationMode('plan');
        await setSessionCodexCollaborationMode(active.id, sessionId, 'plan');
      }

      const rpcCalls =
        turnKind !== 'rpc'
          ? undefined
          : firstToken === '/compact'
            ? [{ method: 'thread/compact/start', requiresThread: true, emitText: false, title: 'thread/compact/start' }]
            : firstToken === '/debug-config'
              ? [
                  { method: 'config/read', params: { includeLayers: true }, emitText: true, title: 'config/read' },
                  { method: 'configRequirements/read', emitText: true, title: 'configRequirements/read' },
                ]
              : firstToken === '/mcp'
                ? [{ method: 'mcpServerStatus/list', emitText: true, title: 'mcpServerStatus/list' }]
                : firstToken === '/apps'
                  ? [{ method: 'app/list', emitText: true, title: 'app/list' }]
                  : firstToken === '/ps'
                    ? [
                        {
                          method: 'thread/backgroundTerminals/list',
                          requiresThread: true,
                          emitText: true,
                          title: 'thread/backgroundTerminals/list',
                        },
                      ]
                    : firstToken === '/fork'
                      ? [{ method: 'thread/fork', requiresThread: true, emitText: false, title: 'thread/fork' }]
                      : firstToken === '/agent'
                        ? [{ method: 'thread/loaded/list', emitText: true, title: 'thread/loaded/list' }]
                        : undefined;

      for await (const ev of runCodexTurn({
        workspace: active,
        sessionId,
        kind: turnKind,
        input: turnKind === 'turn' ? turnInput : undefined,
        collaborationMode: turnKind === 'turn' ? turnCollabMode : undefined,
        rpcCalls,
      })) {
        if (ev.type === 'text') {
          if (!sawFirstDelta) {
            sawFirstDelta = true;
            setWaitingFirstToken(false);
          }
          assistantText += ev.text;
          setMessages((prev) =>
            prev.length && prev[prev.length - 1]?.id === assistantId
              ? [...prev.slice(0, -1), { ...prev[prev.length - 1], content: assistantText }]
              : prev.map((m) => (m.id === assistantId ? { ...m, content: assistantText } : m))
          );
          requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: false }));
          // 让出 JS 线程，避免大量 delta 堵塞导致“看起来不流式”。
          await new Promise<void>((resolve) => setTimeout(resolve, 0));
        }
        if (ev.type === 'rpc_result' && ev.method === 'thread/fork') {
          const id = ev.result?.thread?.id;
          if (typeof id === 'string' && id.trim()) forkedThreadId = id.trim();
        }
        if (ev.type === 'error') {
          setError(ev.message);
          if (!sawFirstDelta) {
            sawFirstDelta = true;
            setWaitingFirstToken(false);
          }
          if (!assistantText) {
            assistantText = ev.message;
            setMessages((prev) =>
              prev.length && prev[prev.length - 1]?.id === assistantId
                ? [...prev.slice(0, -1), { ...prev[prev.length - 1], content: assistantText }]
                : prev.map((m) => (m.id === assistantId ? { ...m, content: assistantText } : m))
            );
          }
        }
      }

      if (turnKind === 'rpc' && firstToken === '/compact' && !assistantText.trim()) {
        assistantText = '已完成 compact（对话上下文已压缩）。';
        setMessages((prev) =>
          prev.length && prev[prev.length - 1]?.id === assistantId
            ? [...prev.slice(0, -1), { ...prev[prev.length - 1], content: assistantText }]
            : prev.map((m) => (m.id === assistantId ? { ...m, content: assistantText } : m))
        );
      }
      if (turnKind === 'rpc' && firstToken === '/fork' && forkedThreadId && !assistantText.trim()) {
        assistantText = `已 fork 到新线程：${forkedThreadId}`;
        setMessages((prev) =>
          prev.length && prev[prev.length - 1]?.id === assistantId
            ? [...prev.slice(0, -1), { ...prev[prev.length - 1], content: assistantText }]
            : prev.map((m) => (m.id === assistantId ? { ...m, content: assistantText } : m))
        );
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
        role: assistantRole,
        createdAt: assistantCreatedAt,
        content: assistantText,
      });

      if (isSlashCommand && firstToken === '/fork' && forkedThreadId) {
        const next = await createSession(active.id, `${session?.title ?? '会话'}（Fork）`, {
          mcpEnabledServerIds: session?.mcpEnabledServerIds ?? active.mcpDefaultEnabledServerIds ?? [],
        });
        await cloneSessionMessages(active.id, sessionId, next.id);
        await setSessionCodexThreadId(active.id, next.id, forkedThreadId);
        await setSessionCodexCollaborationMode(active.id, next.id, session?.codexCollaborationMode ?? collaborationMode);
        didNavigate = true;
        router.replace(`/session/${next.id}`);
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      setError(message);
      setMessages((prev) =>
        prev.length && prev[prev.length - 1]?.id === assistantId
          ? [...prev.slice(0, -1), { ...prev[prev.length - 1], content: message }]
          : prev.map((m) => (m.id === assistantId ? { ...m, content: message } : m))
      );
    } finally {
      if (didNavigate) return;
      setSending(false);
      setWaitingFirstToken(false);
      setPendingAssistantId(null);
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
              {item.id === pendingAssistantId && waitingFirstToken ? (
                <View style={styles.thinkingRow}>
                  <ActivityIndicator />
                  <ThemedText style={styles.muted}>正在等待 Codex 返回…</ThemedText>
                </View>
              ) : (
                <ThemedText>{item.content}</ThemedText>
              )}
            </ThemedView>
          )}
          ListEmptyComponent={<ThemedText style={styles.muted}>还没有消息。</ThemedText>}
        />
      )}

      {slashToken !== null && slashMatches.length > 0 ? (
        <View
          style={[
            styles.slashPopup,
            {
              backgroundColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)',
              borderColor: colorScheme === 'dark' ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.12)',
            },
          ]}>
          <FlatList
            data={slashMatches}
            keyExtractor={(c) => c.command}
            keyboardShouldPersistTaps="handled"
            style={{ maxHeight: 220 }}
            renderItem={({ item }) => (
              <Pressable
                accessibilityRole="button"
                onPress={() => applySlashCommand(item.command)}
                style={({ pressed }) => [
                  styles.slashRow,
                  pressed && {
                    backgroundColor:
                      colorScheme === 'dark' ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)',
                  },
                ]}>
                <ThemedText type="defaultSemiBold" style={styles.slashCommand} numberOfLines={2}>
                  {item.command}
                </ThemedText>
                <View style={{ flex: 1 }}>
                  <ThemedText style={styles.slashPurpose} numberOfLines={2}>
                    {item.purpose}
                  </ThemedText>
                  <ThemedText style={[styles.slashWhen, styles.muted]} numberOfLines={2}>
                    {item.when}
                  </ThemedText>
                </View>
              </Pressable>
            )}
          />
        </View>
      ) : null}

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
  thinkingRow: {
    paddingVertical: 6,
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
  slashPopup: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 6,
    marginBottom: 8,
  },
  slashRow: {
    flexDirection: 'row',
    gap: 10,
    paddingVertical: 10,
    paddingHorizontal: 10,
    borderRadius: 10,
  },
  slashCommand: {
    width: 150,
    fontSize: 13,
  },
  slashPurpose: {
    fontSize: 14,
  },
  slashWhen: {
    marginTop: 2,
    fontSize: 12,
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
