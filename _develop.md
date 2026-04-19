# CodexM 开发与发布

## 环境要求

- Flutter `3.41.4`
- Dart `3.11.1`
- Android SDK `36`
- Android NDK `28.2.13676358`
- Python 3（用于下载 Android `codex` 依赖）

## 开发命令

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

## 下载 Android Runtime 依赖

`codexm_native` 不直接提交 `codex` 二进制；首次构建前请执行：

```bash
python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a
```

脚本会把以下产物放到 Flutter 插件运行时输入目录，随后由插件构建任务转换成 `jniLibs`：

- `codex`
- `codex-exec`
- `rg`
- `libcodex_z.so`
- `libcodex_lzma.so`

## 本地验证

```bash
./scripts/flutter_phase5_regression.sh
```

该脚本会自动执行：

1. 下载 Android Runtime 依赖
2. `flutter analyze`
3. `flutter test`
4. `./gradlew :app:assembleDebug`

## Android Release 构建

发布 APK 必须使用固定的 release keystore。否则 Android 会把新 APK 视为“同包名、不同签名”的另一个应用，覆盖安装和应用内更新都会失败。

先按 Flutter 官方常见方式在 `flutter_app/android/key.properties` 中配置签名信息：

```properties
storeFile=../release.keystore.jks
storePassword=your-store-password
keyAlias=your-key-alias
keyPassword=your-key-password
```

```bash
cd flutter_app
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

## GitHub Actions

`/.github/workflows/flutter-android-release.yml` 会：

1. 安装 Java / Flutter / Android SDK / NDK / CMake
2. 下载 Flutter 插件所需的 `codex` Android 依赖
3. 执行 `flutter analyze` 与 `flutter test`
4. 校验 Android release signing 配置并构建 `arm64-v8a` release APK
5. 上传 Artifact，并在 tag 发布时附加到 GitHub Release

发布到 GitHub Release 前，需要在仓库的 GitHub Secrets 中配置以下 4 个值：

1. `FLUTTER_ANDROID_KEYSTORE_FILE`
2. `FLUTTER_ANDROID_KEYSTORE_PASSWORD`
3. `FLUTTER_ANDROID_KEY_ALIAS`
4. `FLUTTER_ANDROID_KEY_PASSWORD`

建议将 `keystore` 文件内容转成单行 base64 后写入 `FLUTTER_ANDROID_KEYSTORE_FILE`：

```bash
base64 -w 0 "flutter_app/android/release.keystore.jks"
```

对应关系如下：

1. `FLUTTER_ANDROID_KEYSTORE_FILE`：`flutter_app/android/release.keystore.jks` 的 base64 内容
2. `FLUTTER_ANDROID_KEYSTORE_PASSWORD`：`keystore` 密码
3. `FLUTTER_ANDROID_KEY_ALIAS`：生成 `keystore` 时使用的别名，例如 `codexm_release`
4. `FLUTTER_ANDROID_KEY_PASSWORD`：`key` 密码

工作流会在发布前强制校验这 4 个 secrets，并拒绝发布 debug-signed APK。
