export type CodexSlashCommand = {
  command: string;
  purpose: string;
  when: string;
};

// 来源（内置命令清单）：https://developers.openai.com/codex/cli/slash-commands/
export const CODEX_SLASH_COMMANDS: CodexSlashCommand[] = [
  {
    command: '/permissions',
    purpose: '设置 Codex 无需确认即可执行的权限范围',
    when: '在会话中途放宽或收紧审批要求（例如 Auto / Read Only）。',
  },
  {
    command: '/sandbox-add-read-dir',
    purpose: '为 sandbox 额外授予一个可读目录（仅 Windows）',
    when: '需要读取当前可读根之外的绝对路径目录时。',
  },
  {
    command: '/agent',
    purpose: '切换当前激活的 Agent 线程',
    when: '查看或继续某个子 Agent 的工作线程。',
  },
  {
    command: '/apps',
    purpose: '浏览可用 App（connector）并插入到提示词',
    when: '需要在提问前用 $app-slug 绑定一个外部 App。',
  },
  {
    command: '/compact',
    purpose: '压缩/总结当前可见对话以释放上下文',
    when: '对话过长导致上下文紧张时。',
  },
  {
    command: '/diff',
    purpose: '展示 Git diff（包含未跟踪文件）',
    when: '提交前快速审查 Codex 的改动。',
  },
  {
    command: '/exit',
    purpose: '退出 CLI（同 /quit）',
    when: '需要立刻退出会话时。',
  },
  {
    command: '/experimental',
    purpose: '切换/启用实验性功能',
    when: '需要开启可选功能（例如多 Agent）时。',
  },
  {
    command: '/feedback',
    purpose: '向 Codex 维护者发送反馈并附带日志',
    when: '遇到问题需要上报诊断信息时。',
  },
  {
    command: '/init',
    purpose: '在当前目录生成 AGENTS.md 脚手架',
    when: '需要固化仓库约定与持久化指令时。',
  },
  {
    command: '/logout',
    purpose: '退出登录并清理本地凭据',
    when: '共享设备或需要切换账号时。',
  },
  {
    command: '/mcp',
    purpose: '列出已配置的 MCP 工具',
    when: '确认本会话可调用哪些外部工具/服务。',
  },
  {
    command: '/mention',
    purpose: '把文件/目录附加进对话（让 Codex 重点关注）',
    when: '想让 Codex 直接查看某个路径内容时。',
  },
  {
    command: '/model',
    purpose: '选择当前使用的模型（及推理强度，如支持）',
    when: '任务开始前切换更快或更强的模型。',
  },
  {
    command: '/plan',
    purpose: '切换到 Plan 模式（可选：直接附带一段提示）',
    when: '希望先产出执行计划，再进入实现阶段。',
  },
  {
    command: '/personality',
    purpose: '设置回复风格（更简洁/更解释/更协作等）',
    when: '不改提示词，仅调整沟通风格时。',
  },
  {
    command: '/ps',
    purpose: '查看实验性的后台终端及其近期输出',
    when: '想检查长时间运行命令的进度与输出时。',
  },
  {
    command: '/fork',
    purpose: '把当前对话 Fork 到新的线程',
    when: '需要并行探索另一种方案且保留现有对话轨迹。',
  },
  {
    command: '/resume',
    purpose: '从会话列表中恢复一个已保存的对话',
    when: '继续之前的 CLI 会话，不从零开始。',
  },
  {
    command: '/new',
    purpose: '在同一 CLI 会话里开启新对话',
    when: '想在同一仓库里切换到全新上下文。',
  },
  {
    command: '/quit',
    purpose: '退出 CLI',
    when: '需要立刻结束当前会话时。',
  },
  {
    command: '/review',
    purpose: '让 Codex 评审当前工作树',
    when: '完成改动后做一次代码审查/质量检查。',
  },
  {
    command: '/status',
    purpose: '显示会话配置与 token 使用情况',
    when: '确认当前模型、审批策略、可写根与上下文余量。',
  },
  {
    command: '/debug-config',
    purpose: '输出配置层级与要求诊断信息',
    when: '排查 config.toml / 规则等为何未生效。',
  },
  {
    command: '/statusline',
    purpose: '交互式配置 TUI 状态栏字段',
    when: '自定义底部状态栏显示内容并持久化到 config.toml。',
  },
];
