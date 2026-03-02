export type CodexSlashCommand = {
  command: string;
  purpose: string;
  when: string;
};

// 来源（内置命令清单）：https://developers.openai.com/codex/cli/slash-commands/
export const CODEX_SLASH_COMMANDS: CodexSlashCommand[] = [
  {
    command: '/help',
    purpose: '查看可用命令与用法',
    when: '不知道有哪些命令、或想快速回忆用法时。',
  },
  {
    command: '/permissions',
    purpose: '设置 Codex 无需确认即可执行的权限范围',
    when: '在会话中途放宽或收紧审批要求。',
  },
  {
    command: '/sandbox-add-read-dir',
    purpose: '扩展可读取的目录（仅桌面端）',
    when: '移动端不适用；桌面端需要读取额外目录时使用。',
  },
  {
    command: '/agent',
    purpose: '查看/切换线程',
    when: '并行任务较多，需要切换工作线程时。',
  },
  {
    command: '/apps',
    purpose: '列出可用扩展并插入到输入框',
    when: '想在提问前快速插入一个扩展能力时。',
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
    purpose: '退出当前会话（同 /quit）',
    when: '回到上一个页面或会话列表。',
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
    purpose: '查看后台任务与输出',
    when: '想检查耗时操作的进度与输出时。',
  },
  {
    command: '/fork',
    purpose: '把当前对话 Fork 到新的线程',
    when: '需要并行探索另一种方案且保留现有对话轨迹。',
  },
  {
    command: '/resume',
    purpose: '从会话列表中恢复一个已保存的对话',
    when: '继续之前保存的会话，不从零开始。',
  },
  {
    command: '/new',
    purpose: '新建会话',
    when: '想在同一工作区里开启全新对话。',
  },
  {
    command: '/quit',
    purpose: '退出当前会话',
    when: '回到上一个页面或会话列表。',
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
    purpose: '导出配置与诊断信息',
    when: '排查设置未生效或行为异常时。',
  },
  {
    command: '/statusline',
    purpose: '配置状态栏（仅桌面端）',
    when: '移动端不适用。',
  },
];
