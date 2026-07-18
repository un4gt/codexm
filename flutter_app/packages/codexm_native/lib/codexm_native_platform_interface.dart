import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'codexm_native_method_channel.dart';
import 'src/models/app_update_app_info.dart';
import 'src/models/git_commit_summary.dart';
import 'src/models/git_commit_result.dart';
import 'src/models/git_merge_result.dart';
import 'src/models/git_repository_info.dart';
import 'src/models/git_status.dart';
import 'src/models/git_worktree_info.dart';
import 'src/models/runtime_line_event.dart';

abstract class CodexmNativePlatform extends PlatformInterface {
  CodexmNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static CodexmNativePlatform _instance = MethodChannelCodexmNative();

  static CodexmNativePlatform get instance => _instance;

  static set instance(CodexmNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion();

  Future<AppUpdateAppInfo> getAppUpdateAppInfo();

  Future<void> startRuntime({
    required String runtimeId,
    required String cwdUri,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  });

  Future<void> stopRuntime({String? runtimeId});

  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  });

  Future<void> chmodPath(String path);

  Future<void> extractTarGz({
    required String archivePath,
    required String destDir,
  });

  Stream<RuntimeLineEvent> runtimeLineEvents();

  Future<bool> canRequestInstallPackages();

  Future<void> openUnknownSourcesSettings();

  Future<void> installApk({required String apkPath});

  Future<void> openUrl({required String url});

  Future<void> gitClone({
    required String remoteUrl,
    required String localRepoDirUri,
    String? branch,
    String? username,
    String? token,
    String? userName,
    String? userEmail,
    bool allowInsecure,
  });

  Future<void> gitCheckout({
    required String localRepoDirUri,
    required String ref,
  });

  Future<void> gitPull({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure,
  });

  Future<void> gitPush({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure,
  });

  Future<GitStatus> gitStatus({required String localRepoDirUri});

  Future<String> gitDiff({required String localRepoDirUri, int maxBytes});

  Future<List<GitCommitSummary>> gitRecentCommits({
    required String localRepoDirUri,
    int limit,
  });

  Future<String> gitShowCommit({
    required String localRepoDirUri,
    required String hash,
    int maxBytes,
  });

  Future<GitRepositoryInfo> gitInitRepository({
    required String localRepoDirUri,
    required String initialBranch,
  });

  Future<GitRepositoryInfo> gitRepositoryInfo({
    required String localRepoDirUri,
  });

  Future<GitWorktreeInfo> gitCreateWorktree({
    required String mainRepoDirUri,
    required String worktreeDirUri,
    required String name,
    required String branchName,
    required String startRef,
  });

  Future<List<GitWorktreeInfo>> gitListWorktrees({
    required String mainRepoDirUri,
  });

  Future<void> gitRemoveWorktree({
    required String mainRepoDirUri,
    required String name,
    required bool force,
  });

  Future<GitCommitResult> gitCreateCheckpoint({
    required String localRepoDirUri,
    required String message,
    required String userName,
    required String userEmail,
  });

  Future<bool> gitIsAncestor({
    required String localRepoDirUri,
    required String ancestorRef,
    required String descendantRef,
  });

  Future<void> gitDeleteBranch({
    required String localRepoDirUri,
    required String branchName,
    required bool force,
  });

  Future<GitMergeResult> gitMerge({
    required String targetRepoDirUri,
    required String sourceRef,
    required String message,
    required String userName,
    required String userEmail,
  });

  Future<GitMergeResult> gitMergeState({required String targetRepoDirUri});

  Future<GitMergeResult> gitContinueMerge({
    required String targetRepoDirUri,
    required String message,
    required String userName,
    required String userEmail,
  });

  Future<void> gitAbortMerge({required String targetRepoDirUri});
}
