import 'package:flutter_test/flutter_test.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:codexm_native/codexm_native_platform_interface.dart';
import 'package:codexm_native/codexm_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCodexmNativePlatform
    with MockPlatformInterfaceMixin
    implements CodexmNativePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<AppUpdateAppInfo> getAppUpdateAppInfo() async {
    return const AppUpdateAppInfo(
      packageName: 'com.example.app',
      versionName: '1.2.3',
      versionCode: 123,
    );
  }

  @override
  Future<void> chmodPath(String path) async {}

  @override
  Future<void> extractTarGz({
    required String archivePath,
    required String destDir,
  }) async {}

  @override
  Future<void> gitCheckout({
    required String localRepoDirUri,
    required String ref,
  }) async {}

  @override
  Future<void> gitClone({
    required String remoteUrl,
    required String localRepoDirUri,
    String? branch,
    String? username,
    String? token,
    String? userName,
    String? userEmail,
    bool allowInsecure = false,
  }) async {}

  @override
  Future<String> gitDiff({
    required String localRepoDirUri,
    int maxBytes = 400000,
  }) async {
    return '';
  }

  @override
  Future<List<GitCommitSummary>> gitRecentCommits({
    required String localRepoDirUri,
    int limit = 24,
  }) async {
    return const <GitCommitSummary>[];
  }

  @override
  Future<String> gitShowCommit({
    required String localRepoDirUri,
    required String hash,
    int maxBytes = 120000,
  }) async {
    return '';
  }

  @override
  Future<void> gitPull({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure = false,
  }) async {}

  @override
  Future<void> gitPush({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure = false,
  }) async {}

  @override
  Future<GitStatus> gitStatus({required String localRepoDirUri}) async {
    return const GitStatus(staged: [], unstaged: [], untracked: []);
  }

  @override
  Future<void> installApk({required String apkPath}) async {}

  @override
  Future<bool> canRequestInstallPackages() async => true;

  @override
  Future<void> openUnknownSourcesSettings() async {}

  @override
  Future<void> openUrl({required String url}) async {}

  @override
  Stream<RuntimeLineEvent> runtimeLineEvents() {
    return const Stream<RuntimeLineEvent>.empty();
  }

  @override
  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  }) async {}

  @override
  Future<void> startRuntime({
    required String runtimeId,
    required String cwdUri,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  }) async {}

  @override
  Future<void> stopRuntime({String? runtimeId}) async {}
}

void main() {
  final CodexmNativePlatform initialPlatform = CodexmNativePlatform.instance;

  test('$MethodChannelCodexmNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCodexmNative>());
  });

  test('getPlatformVersion', () async {
    const CodexmNative codexmNativePlugin = CodexmNative();
    final MockCodexmNativePlatform fakePlatform = MockCodexmNativePlatform();
    CodexmNativePlatform.instance = fakePlatform;

    expect(await codexmNativePlugin.getPlatformVersion(), '42');
  });

  test('getAppUpdateAppInfo', () async {
    const CodexmNative codexmNativePlugin = CodexmNative();
    final MockCodexmNativePlatform fakePlatform = MockCodexmNativePlatform();
    CodexmNativePlatform.instance = fakePlatform;

    final info = await codexmNativePlugin.getAppUpdateAppInfo();
    expect(info.versionName, '1.2.3');
    expect(info.versionCode, 123);
  });
}
