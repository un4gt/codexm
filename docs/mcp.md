# MCP 支持说明（远程 / 本地 Rust 可执行）

本项目通过 **Codex app-server** 的 `config.toml` 配置来对接 MCP（Model Context Protocol）。

## 1) 远程 MCP（HTTP URL）

在 App 的 `MCP` Tab 里新增一个 `URL` 类型 Server，然后在新建会话时勾选启用即可。

底层会写入：

```toml
[mcp_servers.<name>]
url = "https://example.com/mcp"
```

> 远程 MCP 可以部署在公网，也可以部署在同一台设备上（例如 `http://127.0.0.1:xxxx`），只要 Codex 进程能访问到即可。

## 2) 本地 MCP（Rust 可执行文件，stdio）

本地 MCP 需要 Codex 以子进程方式启动 Server（stdio）。

在 `MCP` Tab 新增 `stdio` 类型 Server：

- `command`: 指向本地可执行文件（绝对路径或 `PATH` 可找到的命令名）
- `args`: 由该 MCP server 决定（每行一个参数，可选）

### 2.1 运行时安装（Rust release 包）

本项目提供“运行时安装”的链路：在 App 内下载并安装 Rust-based MCP server（支持直接二进制、以及 `.tar.gz`/`.tgz` 发布包），安装后会自动把 `command` 写成已安装可执行文件的路径。

然后在新建 workspace / 新建 session 时选择启用。

## 3) 限制与注意事项

- 当前仅考虑 **Rust/可执行式 MCP**（rmcp 生态）；不提供 Node.js / Python runtime 以运行对应 MCP server。
- 在部分 Android 设备/系统策略下，可能会限制从 app 私有可写目录执行下载的 ELF（常见表现为 `Permission denied` / `execute_no_trans`）。如遇该问题，请改用远程 MCP，或在你的运行环境中放开该限制。
