# Flutter Android 发布与主线切换预案

> 适用阶段：`5.4`  
> 当前状态：已补齐 workflow 与签名接入点，**正式发布仍依赖 `5.2` 真机验证通过**。

## 1. 已落地内容

- 新增 workflow：`.github/workflows/flutter-android-release.yml`
- `flutter_app/android/app/build.gradle.kts` 已支持通过 Gradle Property / 环境变量注入 release keystore
- 未配置签名时，仍保留 debug signing 兜底，便于预发布演练

## 2. CI 输入

建议在 GitHub Secrets 中配置：

- `FLUTTER_ANDROID_KEYSTORE_FILE`
- `FLUTTER_ANDROID_KEYSTORE_PASSWORD`
- `FLUTTER_ANDROID_KEY_ALIAS`
- `FLUTTER_ANDROID_KEY_PASSWORD`

> 说明：当前 workflow 直接透传到 `KEYSTORE_FILE` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`。

## 3. 触发方式

### 手动触发

- GitHub Actions → `Flutter Android Release APK` → `Run workflow`

### Tag 触发

- `flutter-v*`
- `flutter-android-v*`

产物：

- `codexm-flutter-<tag>-arm64-v8a.apk`

## 4. 发布前检查

1. 执行 `scripts/flutter_phase5_regression.sh`
2. 执行 Android `arm64` 真机验证
3. 确认以下阻断项为“已接受”或“已修复”
   - 工作区高级配置缺口
   - MCP 托管安装 UI 缺口
   - 设置高级工具缺口
4. 校验 release keystore 已配置

## 5. 推荐发布流程

1. 创建 Flutter release tag
2. 触发 workflow，生成 arm64 release APK
3. 先做小范围安装验证
4. 再发内测 / 灰度
5. 观察首轮启动、首轮消息、Git、MCP 结果

## 6. 主线切换闸门

只有以下条件同时满足，才将 Flutter 认定为 Android 主线：

- 真机 `arm64` 验证通过
- release APK 可稳定产出
- 首轮灰度未出现 Native Core 阻断问题
- 回滚包（Expo 主线）仍保留可用

## 7. 回滚预案

若 Flutter release 包在灰度期出现阻断：

- 停止继续扩大发布范围
- 恢复 Expo APK 为默认安装包
- 使用 `.helloagents/plan/.../expo-decommission-cutover-plan.md` 中的 Stage B 状态继续并行修复
