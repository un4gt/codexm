# 局域网 Web 工作台

CodexM 可以在 Android 手机连接 Wi-Fi 或以太网后启动本地 HTTP 服务，让同一局域网中的浏览器访问手机上的工作区、会话和 Codex Runtime。

## 功能范围

首版 Web 工作台支持：

- 查看手机上的工作区与未归档会话
- 创建和重命名会话
- 查看历史消息和结构化运行信息
- 切换普通 / 计划模式
- 发送消息并接收流式输出
- 停止当前 Codex turn
- 与手机端共享同一个全局 turn 锁和消息存储

首版暂不支持工作区增删、文件树或文件编辑、Git 合并与同步、会话归档或删除、slash commands、skills、`@` 文件和 commit mention。这些能力仍需在手机端使用。

## 开启与配对

1. 让手机连接可信的 Wi-Fi 或以太网。
2. 在 CodexM 打开 `设置 > 局域网访问`。
3. 如需修改端口，先保持服务关闭，再保存 `1024..65535` 范围内的端口。默认端口是 `8765`。
4. 开启“允许浏览器访问”，并允许通知权限。
5. 在同一局域网的浏览器打开手机显示的地址，例如 `http://192.168.1.20:8765`。
6. 输入手机显示的 6 位一次性配对码。

配对码有效期为 5 分钟，成功使用一次后立即失效。需要连接其他浏览器时，在手机上重新生成配对码。

开关与端口会持久化。已开启时，应用重新启动或局域网地址变化后会自动恢复监听；地址或端口变化会撤销已有浏览器会话。CodexM 不注册开机广播，手机重启后需要至少打开一次应用。系统“强行停止”应用后，局域网服务也不会自行恢复。

## 后台行为

开启后，Android 使用 `connectedDevice` 类型的前台服务和常驻通知维持进程。应用退到后台、Activity 销毁或手机锁屏时，Flutter engine、HTTP 服务和正在执行的 Codex turn 不依赖页面继续存在。

不同 Android 厂商仍可能有额外的省电或后台限制。若锁屏后访问中断，请检查：

- CodexM 的通知权限是否开启
- 系统是否对 CodexM 启用了严格省电限制
- Wi-Fi 是否设置为锁屏后断开
- 应用是否被系统或用户“强行停止”

## 安全边界

局域网工作台使用明文 HTTP，不提供 TLS。只应在你信任的局域网中开启；同一网络中具备流量监听能力的设备可能看到传输的项目内容和对话。

实现包含以下限制：

- 只绑定 Android 原生层报告的 Wi-Fi / 以太网 IPv4 地址
- 接受 RFC1918、IPv4 link-local 和 `100.64.0.0/10` 地址
- 不绑定蜂窝网络、VPN、loopback 或 `0.0.0.0`
- 浏览器凭证只保存在内存中；服务停止、IP/端口变化或“全部断开”都会撤销
- 会话 Cookie 使用 256 位随机 token、`HttpOnly` 和 `SameSite=Strict`
- 修改请求还必须携带独立 CSRF token，并通过精确 `Origin` 校验
- 配对尝试按来源 IP 限制为每分钟最多 5 次
- 请求体上限 64 KiB；消息上限 32768 字符；会话标题上限 80 字符
- 响应带 CSP、`nosniff`、禁止 iframe、无 referrer 和受限 Permissions Policy
- API 不返回 API Key、auth ref、Codex thread ID、真实本地路径、runtime stderr 或原生库路径

浏览器端 Markdown 使用随 APK 固定打包的 `marked` 和 DOMPurify，不从 CDN 加载脚本、字体或其他远程资源。危险标签和内联样式会被过滤。

## API 概览

所有接口都位于手机显示的局域网 Origin 下：

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| `GET` | `/health` | 监听器健康检查 |
| `POST` | `/api/v1/auth/pair` | 消费一次性配对码 |
| `GET` | `/api/v1/auth/session` | 恢复浏览器内存会话 |
| `POST` | `/api/v1/auth/logout` | 断开当前浏览器 |
| `GET` | `/api/v1/bootstrap` | 获取脱敏的工作区、会话和全局 turn 状态 |
| `GET` | `/api/v1/workspaces/{wid}/sessions/{sid}/messages` | 分页读取消息，每页最多 100 条 |
| `POST` | `/api/v1/workspaces/{wid}/sessions` | 创建会话 |
| `PATCH` | `/api/v1/workspaces/{wid}/sessions/{sid}` | 重命名或切换模式 |
| `POST` | `/api/v1/workspaces/{wid}/sessions/{sid}/turns` | 启动 Codex turn |
| `DELETE` | `/api/v1/turns/{turnId}` | 停止当前 turn |
| `GET` | `/api/v1/events` | WebSocket 状态与流式事件 |

WebSocket 使用单调递增的 `revision`。浏览器发现 revision 缺口或重新连接后，会重新获取 bootstrap 和当前消息，避免长期依赖可能丢失的增量事件。

## 故障排查

没有显示浏览器地址：确认手机连接的是 Wi-Fi 或以太网，而不是仅有蜂窝或 VPN；然后在设置页点“重试”。

端口监听失败：关闭局域网访问，换一个未被占用的端口后再开启。端口只能在服务关闭时修改。

通知权限被拒绝：设置页会保留错误状态和“通知设置”入口。打开通知权限后重新开启服务。

配对码无效：确认输入的是当前 6 位代码。代码可能已过期或已被另一个浏览器消费，可在手机上重新生成。

网页显示连接中断：确认手机 IP 未变化、前台服务通知仍存在且浏览器仍在同一局域网。IP 变化会按设计撤销旧凭证，需要重新打开新地址并配对。

Codex 启动后立即退出：先检查 `设置 > 连接设置` 中的 API Key 与 Base URL。网络、认证或超时错误也应先确认连接和凭据；详细 runtime stderr 只写入手机日志，不发送到浏览器。

## 开发预览与验证

无需 Android 设备即可预览同一套前端资源：

```bash
cd flutter_app
dart run tool/lan_web_preview.dart --port 4173
```

打开 `http://127.0.0.1:4173`。预览服务只使用内存假数据，支持会话切换、创建、重命名、模式切换、发送、流式回复和停止，不读取真实工作区或凭据。

相关回归命令：

```bash
cd flutter_app
flutter analyze
flutter test test/features/lan_access
flutter test
cd android
./gradlew :app:compileDebugKotlin
```

发布前仍需在 Android `arm64-v8a` 真机上验证：锁屏、切后台、Wi-Fi 断开与重连、IP 变化、多浏览器配对、长时间流式输出和系统回收后的前台服务恢复。
