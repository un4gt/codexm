import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  Share,
  StyleSheet,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Button, TextInput, useTheme } from 'react-native-paper';

import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import Constants from 'expo-constants';
import * as Clipboard from 'expo-clipboard';
import * as FileSystem from 'expo-file-system/legacy';

import { MarkdownView } from '@/components/markdown/MarkdownView';
import { ThinkingBlock } from '@/components/markdown/ThinkingBlock';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Layout, Spacing } from '@/constants/theme';
import { readSessionDebugLogTail } from '@/src/codex/debugLog';
import { CODEX_SLASH_COMMANDS } from '@/src/codex/slashCommands';
import { getCodexSettings, materializeCodexConfigFiles, setCodexApiKey, updateCodexSettings } from '@/src/codex/settings';
import { listInstalledSkills, normalizeSkillName, skillFilePath } from '@/src/codex/skills';
import { runCodexTurn } from '@/src/codex/sessionRunner';
import { gitDiff } from '@/src/git/nativeGit';
import { listMcpServers } from '@/src/mcp/store';
import { splitThinking } from '@/src/markdown/thinking';
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

  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const manualAndroidKeyboardInset =
    Platform.OS === 'android' && (Constants.expoConfig?.android?.softwareKeyboardLayoutMode ?? 'resize') === 'pan';
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
  const [androidKeyboardHeight, setAndroidKeyboardHeight] = useState(0);
  const [pendingAssistantId, setPendingAssistantId] = useState<string | null>(null);
  const [collaborationMode, setCollaborationMode] = useState<Session['codexCollaborationMode']>('default');
  const [uiShowThinking, setUiShowThinking] = useState(false);
  const [installedSkills, setInstalledSkills] = useState<string[]>([]);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      const skills = await listInstalledSkills();
      if (!cancelled) setInstalledSkills(skills);
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, []);

  const slashToken = useMemo(() => {
    const trimmed = input.trimStart();
    if (!trimmed.startsWith('/')) return null;
    // 仅在“命令输入阶段”显示（出现空白字符后视为已进入参数阶段，关闭联想面板）
    if (/\s/.test(trimmed)) return null;
    return trimmed;
  }, [input]);

  const dollarToken = useMemo(() => {
    const trimmed = input.trimStart();
    if (!trimmed.startsWith('$')) return null;
    if (/\s/.test(trimmed)) return null;
    return trimmed;
  }, [input]);

  const slashMatches = useMemo(() => {
    if (slashToken === null) return [];
    const query = slashToken.slice(1).toLowerCase();
    if (!query) return CODEX_SLASH_COMMANDS;
    return CODEX_SLASH_COMMANDS.filter((c) => c.command.slice(1).toLowerCase().startsWith(query));
  }, [slashToken]);

  const skillMatches = useMemo(() => {
    if (dollarToken === null) return [];
    const query = dollarToken.slice(1).toLowerCase();
    const list = query ? installedSkills.filter((s) => s.toLowerCase().startsWith(query)) : installedSkills;
    return list.slice(0, 20);
  }, [dollarToken, installedSkills]);

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

  function applySkillToken(name: string) {
    const normalized = normalizeSkillName(name);
    if (!normalized) return;
    setInput((prev) => {
      const leadingWhitespace = prev.match(/^\s*/)?.[0] ?? '';
      const trimmed = prev.slice(leadingWhitespace.length);
      const token = `$${normalized}`;
      if (!trimmed.startsWith('$')) return `${leadingWhitespace}${token} `;
      const firstWhitespaceIdx = trimmed.search(/\s/);
      if (firstWhitespaceIdx === -1) return `${leadingWhitespace}${token} `;
      return `${leadingWhitespace}${token}${trimmed.slice(firstWhitespaceIdx)}`;
    });
  }

  async function getSessionDiagnosticsTextOrAlert() {
    if (!active || !sessionId) return null;
    const s = await getCodexSettings();
    if (!s.debugLogToFile) {
      Alert.alert('未开启调试日志', '请先到「设置」的高级选项中开启并保存，然后复现问题后再导出。');
      return null;
    }
    const text = await readSessionDebugLogTail({ workspaceId: active.id, sessionId, maxChars: 200_000 });
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

  async function copySessionDiagnostics() {
    try {
      const text = await getSessionDiagnosticsTextOrAlert();
      if (!text) return;
      await Clipboard.setStringAsync(text);
      Alert.alert('已复制', '诊断信息已复制到剪贴板。');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      Alert.alert('复制失败', msg);
    }
  }

  async function exportSessionDiagnostics() {
    try {
      const text = await getSessionDiagnosticsTextOrAlert();
      if (!text) return;

      if (Platform.OS === 'android' && FileSystem.StorageAccessFramework) {
        try {
          const perms = await FileSystem.StorageAccessFramework.requestDirectoryPermissionsAsync();
          if (perms.granted) {
            const fileName = `codexm-会话诊断-${formatStampForFileName(new Date())}`;
            const fileUri = await FileSystem.StorageAccessFramework.createFileAsync(perms.directoryUri, fileName, 'text/plain');
            await FileSystem.writeAsStringAsync(fileUri, text);
            Alert.alert('已导出', '诊断信息已保存到你选择的目录。');
            return;
          }
        } catch {
          // ignore and fall back
        }
      }

      await Share.share({ title: '诊断信息', message: text });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      Alert.alert('导出失败', msg);
    }
  }

  function openDiagnosticsActions() {
    Alert.alert('诊断信息', '选择操作：', [
      { text: '复制到剪贴板', onPress: () => void copySessionDiagnostics() },
      { text: Platform.OS === 'android' ? '导出为文件' : '分享', onPress: () => void exportSessionDiagnostics() },
      { text: '取消', style: 'cancel' },
    ]);
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
          setCollaborationMode(s?.codexCollaborationMode === 'plan' ? 'plan' : 'default');
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

  useEffect(() => {
    let cancelled = false;
    async function run() {
      try {
        const s = await getCodexSettings();
        if (!cancelled) setUiShowThinking(Boolean(s.uiShowThinking));
      } catch {
        // ignore
      }
    }
    run();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (Platform.OS !== 'android') return;
    const onShow = Keyboard.addListener('keyboardDidShow', (event) => {
      if (manualAndroidKeyboardInset) {
        const height = event.endCoordinates?.height ?? 0;
        setAndroidKeyboardHeight(Math.max(0, height));
      }
      requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
    });
    const onHide = Keyboard.addListener('keyboardDidHide', () => {
      if (manualAndroidKeyboardInset) setAndroidKeyboardHeight(0);
    });
    return () => {
      onShow.remove();
      onHide.remove();
    };
  }, [manualAndroidKeyboardInset]);

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
      content: assistantRole === 'system' ? '正在处理…' : '',
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
        if (firstToken === '/help') {
          const lines = [
            '可用命令（移动端）',
            '',
            '**常用**',
            '- /plan：切换计划模式（/plan on | /plan off）',
            '- /review：评审当前改动',
            '- /diff：查看当前工作区改动',
            '- /mcp：查看已配置的 MCP 工具',
            '- /status：查看当前会话状态',
            '- /new：新建会话',
            '- /resume <id>：切换到历史会话',
            '',
            '**设置**',
            '- /model <id>：设置模型（也可在「设置」里选择）',
            '- /permissions <policy>：设置审批策略',
            '- /personality <style>：设置风格',
            '- /experimental multi_agent on|off：实验特性',
            '- /logout：清除本地密钥',
            '',
            '**技巧**',
            "- 输入 '/' 或 '$' 可查看建议列表。",
            '- 技能：先在「设置」→「高级选项」中创建/导入，然后在消息中输入 $技能名。',
            '',
            '**不适用**',
            '- /sandbox-add-read-dir、/statusline：仅桌面端。',
          ];
          await finishLocal({ role: 'system', content: lines.join('\n') });
          return;
        }

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

        if (firstToken === '/mcp') {
          const servers = await listMcpServers();
          if (!servers.length) {
            await finishLocal({ role: 'system', content: '还没有配置 MCP 工具。你可以在「MCP」标签页添加。' });
            return;
          }

          const enabledIds = new Set(
            (session?.mcpEnabledServerIds ?? active.mcpDefaultEnabledServerIds ?? []).filter(Boolean)
          );
          const lines: string[] = [`已配置 MCP 工具（${servers.length}）`, ''];
          for (const s of servers) {
            const enabled = enabledIds.has(s.id);
            const typeLabel = s.transport === 'url' ? '网络服务' : '本地启动';
            lines.push(`- ${s.name}：${enabled ? '已启用' : '未启用'}（${typeLabel}）`);
          }
          lines.push('', '提示：可在「MCP」标签页编辑；可在新建会话/工作区里设置默认启用项。');
          await finishLocal({ role: 'system', content: lines.join('\n') });
          return;
        }

        if (isSlashPlanToggle) {
          const nextMode =
            slashArgs === 'on'
              ? 'plan'
            : slashArgs === 'off'
                ? 'default'
              : collaborationMode === 'plan'
                  ? 'default'
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
                ? `\`\`\`diff\n${patch}\n\`\`\`\n\n（已截断：输出超过 200KB）`
                : `\`\`\`diff\n${patch}\n\`\`\``
              : '当前工作区没有改动。';
            await finishLocal({ role: 'system', content });
          } catch (e) {
            const message = e instanceof Error ? e.message : String(e);
            await finishLocal({ role: 'system', content: `获取 diff 失败：\n\n\`\`\`\n${message}\n\`\`\`` });
          }
          return;
        }

        if (firstToken === '/status') {
          const s = await getCodexSettings();
          const approvalLabel =
            s.approvalPolicy === 'never'
              ? '无需确认'
              : s.approvalPolicy === 'on-request'
                ? '手动确认'
                : s.approvalPolicy === 'on-failure'
                  ? '失败时确认'
                  : s.approvalPolicy === 'untrusted'
                    ? '严格'
                    : s.approvalPolicy;
          const personalityLabel =
            s.personality === 'friendly' ? '友好' : s.personality === 'pragmatic' ? '务实' : '默认';
          const modelLabel = s.model?.trim() ? s.model.trim() : '使用默认模型';
          const servers = await listMcpServers();
          const enabledIds = new Set(
            (session?.mcpEnabledServerIds ?? active.mcpDefaultEnabledServerIds ?? []).filter(Boolean)
          );
          const enabledCount = servers.filter((x) => enabledIds.has(x.id)).length;

          const lines = [
            '当前状态',
            `- 工作区：${active.name}`,
            `- 会话：${session?.title ?? sessionId}`,
            `- 线程：${session?.codexThreadId ? '已建立' : '未建立'}`,
            `- 模式：${collaborationMode === 'plan' ? '计划' : '默认'}`,
            `- 模型：${modelLabel}`,
            `- 权限：${approvalLabel}`,
            `- 风格：${personalityLabel}`,
            `- MCP：启用 ${enabledCount}/${servers.length}`,
            `- 调试日志：${s.debugLogToFile ? '开启' : '关闭'}`,
            '',
            '提示：需要更多信息可点击「复制诊断信息」。',
          ];

          const wantRaw = /\b(raw|debug|diag)\b/i.test(slashArgs);
          if (wantRaw) {
            const raw = {
              workspaceId: active.id,
              sessionId,
              threadId: session?.codexThreadId ?? null,
              repoUri: workspaceRepoPath(active.id),
            };
            lines.push('', '```json', JSON.stringify(raw, null, 2), '```');
          }

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
            content: `已标记：${cleaned}\n（下一条消息会附加该路径供 Codex 参考）`,
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
          await finishLocal({ role: 'system', content: '该命令仅适用于桌面端：移动端不支持。' });
          return;
        }

        if (firstToken === '/sandbox-add-read-dir') {
          await finishLocal({
            role: 'system',
            content: '该命令仅适用于桌面端：移动端不支持。',
          });
          return;
        }

        if (firstToken === '/feedback') {
          openDiagnosticsActions();
          await finishLocal({
            role: 'system',
            content: '已打开诊断信息导出。请在弹窗中选择复制或导出，然后把内容粘贴到反馈里。',
          });
          return;
        }
      }

      // Codex-backed：turn / review / rpc
      setPendingAssistantId(assistantId);
      setWaitingFirstToken(true);

      const PLAN_PREFIX =
        '你处于计划模式。请先输出一个可执行的计划（步骤、依赖、风险、验证方式），在我确认前不要执行命令/不要修改文件。\n\n任务：';

      const turnKind: 'turn' | 'review' | 'rpc' = isSlashReview ? 'review' : isSlashRpc ? 'rpc' : 'turn';
      const turnInputBase = isSlashPlanTurn
        ? `${PLAN_PREFIX}${slashArgs}`
        : collaborationMode === 'plan'
          ? `${PLAN_PREFIX}${text}`
          : text;
      const pendingMentions = pendingMentionsRef.current;
      if (pendingMentions.length && turnKind === 'turn') pendingMentionsRef.current = [];

      const turnCollabMode: 'default' | 'plan' =
        isSlashPlanTurn ? 'plan' : collaborationMode === 'plan' ? 'plan' : 'default';

      if (isSlashPlanTurn) {
        setCollaborationMode('plan');
        await setSessionCodexCollaborationMode(active.id, sessionId, 'plan');
      }

      const rpcCalls =
        turnKind !== 'rpc'
          ? undefined
          : firstToken === '/compact'
            ? [{ method: 'thread/compact/start', requiresThread: true, emitText: false }]
              : firstToken === '/debug-config'
                ? [
                    { method: 'config/read', params: { includeLayers: true }, emitText: true, title: '配置详情' },
                    { method: 'configRequirements/read', emitText: true, title: '配置要求' },
                  ]
                : firstToken === '/apps'
                  ? [{ method: 'app/list', emitText: true, title: '可用扩展' }]
                  : firstToken === '/ps'
                    ? [
                        {
                          method: 'thread/backgroundTerminals/list',
                          requiresThread: true,
                          emitText: true,
                          title: '后台任务',
                        },
                      ]
                    : firstToken === '/fork'
                      ? [{ method: 'thread/fork', requiresThread: true, emitText: false }]
                      : firstToken === '/agent'
                        ? [{ method: 'thread/loaded/list', emitText: true, title: '线程列表' }]
                        : undefined;

      const repoUri = workspaceRepoPath(active.id);
      const repoPath = repoUri.startsWith('file://') ? repoUri.replace('file://', '') : repoUri;
      const repoBase = repoPath.endsWith('/') ? repoPath : `${repoPath}/`;

      const mentionInputs =
        turnKind !== 'turn' || pendingMentions.length === 0
          ? []
          : pendingMentions
              .map((p) => (p ?? '').trim())
              .filter(Boolean)
              .map((p) => {
                const cleaned = p.replace(/^file:\/\//, '').replace(/^\.\/+/, '');
                const absPath = cleaned.startsWith('/') ? cleaned : `${repoBase}${cleaned}`;
                return { type: 'mention', name: p, path: absPath } as const;
              });

      const skillInputs =
        turnKind !== 'turn'
          ? []
          : await (async () => {
              const skills = await listInstalledSkills();
              if (!skills.length) return [];
              const known = new Set(skills);
              const tokens = Array.from(text.matchAll(/\B\$([a-zA-Z0-9_-]{2,})\b/g))
                .map((m) => normalizeSkillName(m[1] ?? ''))
                .filter(Boolean);
              const uniq = Array.from(new Set(tokens)).filter((n) => known.has(n));
              return uniq.map((n) => ({ type: 'skill', name: n, path: skillFilePath(n) }) as const);
            })();

      const turnInputElems =
        turnKind === 'turn'
          ? ([...skillInputs, ...mentionInputs, { type: 'text', text: turnInputBase }] as {
              type: string;
              [key: string]: any;
            }[])
          : undefined;

      for await (const ev of runCodexTurn({
        workspace: active,
        sessionId,
        kind: turnKind,
        input: turnKind === 'turn' ? turnInputElems : undefined,
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
      <ThemedView style={styles.screen}>
        <Stack.Screen options={{ title: '会话' }} />
        <View style={styles.container}>
          <ThemedText type="title">会话</ThemedText>
          <ThemedText style={styles.muted}>请先选择一个工作区。</ThemedText>
        </View>
      </ThemedView>
    );
  }

  return (
    <ThemedView style={styles.screen}>
      <Stack.Screen
        options={{
          title: session?.title ?? '会话',
          headerRight: () => (
            <Button compact mode="text" onPress={() => router.back()}>
              关闭
            </Button>
          ),
        }}
      />

      <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.container}>
          <ThemedView
            style={[
              styles.topCard,
              { backgroundColor: theme.colors.surface, borderColor: theme.colors.outlineVariant },
            ]}>
            <ThemedText style={styles.muted}>
              工作区：<ThemedText type="defaultSemiBold">{active.name}</ThemedText>
            </ThemedText>

            <TextInput
              mode="outlined"
              label="会话标题"
              value={draftTitle}
              onChangeText={setDraftTitle}
              style={styles.titleInput}
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
        <View>
          <ThemedText style={[styles.error, { color: theme.colors.error }]}>{error}</ThemedText>
          <Button mode="outlined" onPress={openDiagnosticsActions} style={styles.copyDiagButton}>
            复制诊断信息
          </Button>
          <ThemedText style={styles.muted}>提示：可在「设置」的高级选项中开启调试日志。</ThemedText>
        </View>
      ) : null}

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator />
        </View>
      ) : (
        <FlatList
          ref={listRef}
          style={{ flex: 1 }}
          data={messages}
          keyExtractor={(m) => m.id}
          keyboardDismissMode="on-drag"
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={{
            paddingBottom: 16 + (manualAndroidKeyboardInset ? Math.min(androidKeyboardHeight, 120) : 0),
          }}
          renderItem={({ item }) => {
            const { visible, thinking } = splitThinking(item.content);
            const roleLabel = item.role === 'user' ? '你' : item.role === 'assistant' ? 'Codex' : '系统';
            const showHiddenThinkingPlaceholder = !uiShowThinking && !visible && Boolean(thinking);

            return (
              <ThemedView
                style={[
                  styles.msg,
                  {
                    borderColor: theme.colors.outlineVariant,
                    backgroundColor:
                      item.role === 'user'
                        ? theme.colors.primaryContainer
                        : theme.colors.surface,
                  },
                ]}>
                <View style={styles.msgHeader}>
                  <ThemedText type="defaultSemiBold" style={{ flex: 1 }}>
                    {roleLabel}
                  </ThemedText>
                  {item.id === pendingAssistantId && waitingFirstToken ? (
                    <ActivityIndicator size="small" />
                  ) : null}
                </View>

                {item.id === pendingAssistantId && waitingFirstToken ? (
                  <View>
                    <Button mode="outlined" onPress={openDiagnosticsActions} style={styles.copyDiagButton}>
                      复制诊断信息
                    </Button>
                  </View>
                ) : (
                  <>
                    {visible ? <MarkdownView markdown={visible} selectable /> : null}
                    {showHiddenThinkingPlaceholder ? (
                      <ThemedText style={styles.muted}>思考内容已隐藏</ThemedText>
                    ) : null}
                    {uiShowThinking && thinking ? (
                      <View style={{ marginTop: 10 }}>
                        <ThinkingBlock thinking={thinking} />
                      </View>
                    ) : null}
                  </>
                )}
              </ThemedView>
            );
          }}
          ListEmptyComponent={<ThemedText style={styles.muted}>还没有消息。</ThemedText>}
        />
      )}

      {slashToken !== null && slashMatches.length > 0 ? (
        <View
          style={[
            styles.slashPopup,
            {
              backgroundColor: theme.colors.surface,
              borderColor: theme.colors.outlineVariant,
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
                        theme.dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)',
                    },
                  ]}>
                <ThemedText type="defaultSemiBold" style={styles.slashCommand} numberOfLines={1}>
                  {item.command}
                </ThemedText>
                <View style={{ flex: 1 }}>
                  <ThemedText style={styles.slashPurpose} numberOfLines={1}>
                    {item.purpose}
                  </ThemedText>
                </View>
              </Pressable>
            )}
          />
        </View>
      ) : null}

      {dollarToken !== null ? (
        skillMatches.length > 0 ? (
          <View
            style={[
              styles.slashPopup,
              {
                backgroundColor: theme.colors.surface,
                borderColor: theme.colors.outlineVariant,
              },
            ]}>
            <FlatList
              data={skillMatches}
              keyExtractor={(c) => c}
              keyboardShouldPersistTaps="handled"
              style={{ maxHeight: 220 }}
              renderItem={({ item }) => (
                <Pressable
                  accessibilityRole="button"
                  onPress={() => applySkillToken(item)}
                  style={({ pressed }) => [
                    styles.slashRow,
                    pressed && {
                      backgroundColor: theme.dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)',
                    },
                  ]}>
                  <ThemedText type="defaultSemiBold" style={styles.slashCommand} numberOfLines={1}>
                    {`$${item}`}
                  </ThemedText>
                  <View style={{ flex: 1 }}>
                    <ThemedText style={styles.slashPurpose} numberOfLines={1}>
                      技能
                    </ThemedText>
                  </View>
                </Pressable>
              )}
            />
          </View>
        ) : (
          <View
            style={[
              styles.slashPopup,
              {
                backgroundColor: theme.colors.surface,
                borderColor: theme.colors.outlineVariant,
              },
            ]}>
            <ThemedText style={styles.muted}>
              {installedSkills.length ? '未找到匹配的技能。' : '还没有安装技能。请到「设置」→「高级选项」中添加。'}
            </ThemedText>
          </View>
        )
      ) : null}

      <View
        style={[
          styles.composer,
          {
            borderColor: theme.colors.outlineVariant,
            paddingBottom: Spacing.sm + insets.bottom + (manualAndroidKeyboardInset ? androidKeyboardHeight : 0),
          },
        ]}>
        <TextInput
          mode="outlined"
          value={input}
          onChangeText={setInput}
          placeholder="输入你的问题…"
          style={[
            styles.composerInput,
          ]}
          onFocus={() => requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }))}
          multiline
        />
        <Button
          mode="contained"
          disabled={sending || !input.trim()}
          onPress={onSend}
          style={styles.sendButton}
          contentStyle={styles.sendButtonContent}
          loading={sending}>
          发送
        </Button>
      </View>
        </View>
      </KeyboardAvoidingView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    flex: 1,
    paddingTop: Spacing.md,
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.md,
    width: '100%',
    maxWidth: Layout.maxWidthWide,
    alignSelf: 'center',
  },
  topCard: {
    borderWidth: 1,
    borderRadius: 14,
    padding: 12,
    marginBottom: 10,
  },
  titleInput: {
    marginTop: 8,
  },
  msg: {
    borderWidth: 1,
    borderRadius: 14,
    padding: 12,
    marginBottom: 10,
  },
  msgHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 8,
  },
  copyDiagButton: {
    alignSelf: 'flex-start',
    marginTop: 6,
  },
  composer: {
    borderTopWidth: 1,
    paddingTop: 10,
    paddingBottom: 10,
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 10,
  },
  composerInput: {
    flex: 1,
    minHeight: 44,
    maxHeight: 140,
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
    alignSelf: 'flex-end',
  },
  sendButtonContent: {
    minHeight: 44,
    paddingHorizontal: 14,
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
