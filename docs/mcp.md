# MCP 支持说明（Flutter Android）

本项目通过 `config.toml` 配置对接 MCP（Model Context Protocol）。当前 Flutter 主线已经收敛为 **全局 MCP 管理**，不再按 workspace 单独维护一套服务器配置。

## 当前支持类型

### 1. Streamable HTTP / HTTP

适用于远程 MCP 服务。

配置形态：

```toml
[mcp_servers.<name>]
url = "https://example.com/mcp"
```

说明：

- 支持公网地址，也支持局域网 / 回环地址
- 只要 Android 设备上的 Codex Runtime 能访问该地址即可

### 2. Rust stdio（aarch64 build）

适用于 Android `arm64` 可执行 MCP 服务。

配置形态：

```toml
[mcp_servers.<name>]
command = "/absolute/path/to/server"
args = ["--flag"]
```

说明：

- 仅支持可直接在 Android `arm64` 环境执行的 Rust 二进制
- 设置页支持“托管安装”模式，可下载并安装 release 包，再把可执行路径写回配置

## 当前不支持

- Node.js MCP
- Python MCP
- 非 Android `aarch64` 本地 stdio 可执行
- workspace 级 MCP 选择

## 注意事项

- MCP 与 skills 现在都属于全局作用域
- 运行时若设备限制私有目录 ELF 执行，优先改用远程 MCP
- 真机验证前，建议先通过设置页的配置预览确认最终写出的 `config.toml`
