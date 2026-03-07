# CodexM 知识库索引

- kb_version: 2.3.0
- project: `codexm`
- updated_at: `2026-03-07`
- current_focus: `Happy 风格会话 / 工作区 / 设置 tab 重构已完成，转入真机体验验收`

## 目录

- `context.md`：项目现状、技术栈与当前迁移状态
- `CHANGELOG.md`：项目级变更记录
- `modules/_index.md`：模块索引
- `plan/`：迁移方案包与实施任务

## 当前状态

- 仓库已收敛为 `Flutter Android` 主线
- `flutter_app/` 是唯一移动端应用入口
- `flutter_app/packages/codexm_native/` 承接 Android Native Core
- 当前优先级：执行 Android `arm64` 真机体验验收，重点确认新会话输入区、工作区主链路与 clone 真机场景
