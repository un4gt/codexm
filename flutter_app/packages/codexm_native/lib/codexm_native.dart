import 'codexm_native_platform_interface.dart';
import 'src/models/app_update_app_info.dart';
import 'src/models/git_commit_summary.dart';
import 'src/models/git_status.dart';
import 'src/models/runtime_line_event.dart';

export 'src/models/app_update_app_info.dart';
export 'src/models/git_commit_summary.dart';
export 'src/models/git_status.dart';
export 'src/models/runtime_line_event.dart';

class CodexmNative {
  const CodexmNative();

  Future<String?> getPlatformVersion() {
    return CodexmNativePlatform.instance.getPlatformVersion();
  }

  Future<AppUpdateAppInfo> getAppUpdateAppInfo() {
    return CodexmNativePlatform.instance.getAppUpdateAppInfo();
  }

  Future<void> startRuntime({
    required String runtimeId,
    required String cwdUri,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  }) {
    return CodexmNativePlatform.instance.startRuntime(
      runtimeId: runtimeId,
      cwdUri: cwdUri,
      executablePath: executablePath,
      assetPath: assetPath,
      args: args,
      env: env,
    );
  }

  Future<void> stopRuntime({String? runtimeId}) {
    return CodexmNativePlatform.instance.stopRuntime(runtimeId: runtimeId);
  }

  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  }) {
    return CodexmNativePlatform.instance.sendRuntimeLine(
      runtimeId: runtimeId,
      line: line,
    );
  }

  Future<void> chmodPath(String path) {
    return CodexmNativePlatform.instance.chmodPath(path);
  }

  Future<void> extractTarGz({
    required String archivePath,
    required String destDir,
  }) {
    return CodexmNativePlatform.instance.extractTarGz(
      archivePath: archivePath,
      destDir: destDir,
    );
  }

  Stream<RuntimeLineEvent> runtimeLineEvents() {
    return CodexmNativePlatform.instance.runtimeLineEvents();
  }

  Future<bool> canRequestInstallPackages() {
    return CodexmNativePlatform.instance.canRequestInstallPackages();
  }

  Future<void> openUnknownSourcesSettings() {
    return CodexmNativePlatform.instance.openUnknownSourcesSettings();
  }

  Future<void> installApk({required String apkPath}) {
    return CodexmNativePlatform.instance.installApk(apkPath: apkPath);
  }

  Future<void> openUrl({required String url}) {
    return CodexmNativePlatform.instance.openUrl(url: url);
  }

  Future<void> gitClone({
    required String remoteUrl,
    required String localRepoDirUri,
    String? branch,
    String? username,
    String? token,
    String? userName,
    String? userEmail,
    bool allowInsecure = false,
  }) {
    return CodexmNativePlatform.instance.gitClone(
      remoteUrl: remoteUrl,
      localRepoDirUri: localRepoDirUri,
      branch: branch,
      username: username,
      token: token,
      userName: userName,
      userEmail: userEmail,
      allowInsecure: allowInsecure,
    );
  }

  Future<void> gitCheckout({
    required String localRepoDirUri,
    required String ref,
  }) {
    return CodexmNativePlatform.instance.gitCheckout(
      localRepoDirUri: localRepoDirUri,
      ref: ref,
    );
  }

  Future<void> gitPull({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure = false,
  }) {
    return CodexmNativePlatform.instance.gitPull(
      localRepoDirUri: localRepoDirUri,
      remote: remote,
      branch: branch,
      username: username,
      token: token,
      allowInsecure: allowInsecure,
    );
  }

  Future<void> gitPush({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure = false,
  }) {
    return CodexmNativePlatform.instance.gitPush(
      localRepoDirUri: localRepoDirUri,
      remote: remote,
      branch: branch,
      username: username,
      token: token,
      allowInsecure: allowInsecure,
    );
  }

  Future<GitStatus> gitStatus({required String localRepoDirUri}) {
    return CodexmNativePlatform.instance.gitStatus(
      localRepoDirUri: localRepoDirUri,
    );
  }

  Future<String> gitDiff({
    required String localRepoDirUri,
    int maxBytes = 400000,
  }) {
    return CodexmNativePlatform.instance.gitDiff(
      localRepoDirUri: localRepoDirUri,
      maxBytes: maxBytes,
    );
  }

  Future<List<GitCommitSummary>> gitRecentCommits({
    required String localRepoDirUri,
    int limit = 24,
  }) {
    return CodexmNativePlatform.instance.gitRecentCommits(
      localRepoDirUri: localRepoDirUri,
      limit: limit,
    );
  }

  Future<String> gitShowCommit({
    required String localRepoDirUri,
    required String hash,
    int maxBytes = 120000,
  }) {
    return CodexmNativePlatform.instance.gitShowCommit(
      localRepoDirUri: localRepoDirUri,
      hash: hash,
      maxBytes: maxBytes,
    );
  }
}
