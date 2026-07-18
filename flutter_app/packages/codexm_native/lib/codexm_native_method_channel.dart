import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'codexm_native_platform_interface.dart';
import 'src/models/app_update_app_info.dart';
import 'src/models/git_commit_summary.dart';
import 'src/models/git_commit_result.dart';
import 'src/models/git_merge_result.dart';
import 'src/models/git_repository_info.dart';
import 'src/models/git_status.dart';
import 'src/models/git_worktree_info.dart';
import 'src/models/runtime_line_event.dart';

class MethodChannelCodexmNative extends CodexmNativePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('codexm_native/methods');

  @visibleForTesting
  final runtimeLineChannel = const EventChannel('codexm_native/runtime_lines');

  @override
  Future<String?> getPlatformVersion() async {
    return await methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<AppUpdateAppInfo> getAppUpdateAppInfo() async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'update.getAppInfo',
    );
    return AppUpdateAppInfo.fromMap(result ?? const <Object?, Object?>{});
  }

  @override
  Future<void> startRuntime({
    required String runtimeId,
    required String cwdUri,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  }) async {
    await methodChannel.invokeMethod<void>('runtime.start', {
      'runtimeId': runtimeId,
      'cwdUri': cwdUri,
      'executablePath': executablePath,
      'assetPath': assetPath,
      'args': args,
      'env': env,
    });
  }

  @override
  Future<void> stopRuntime({String? runtimeId}) async {
    await methodChannel.invokeMethod<void>('runtime.stop', {
      'runtimeId': runtimeId,
    });
  }

  @override
  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  }) async {
    await methodChannel.invokeMethod<void>('runtime.sendLine', {
      'runtimeId': runtimeId,
      'line': line,
    });
  }

  @override
  Future<void> chmodPath(String path) async {
    await methodChannel.invokeMethod<void>('runtime.chmodPath', {'path': path});
  }

  @override
  Future<void> extractTarGz({
    required String archivePath,
    required String destDir,
  }) async {
    await methodChannel.invokeMethod<void>('runtime.extractTarGz', {
      'archivePath': archivePath,
      'destDir': destDir,
    });
  }

  @override
  Stream<RuntimeLineEvent> runtimeLineEvents() {
    return runtimeLineChannel.receiveBroadcastStream().map((event) {
      return RuntimeLineEvent.fromMap(Map<Object?, Object?>.from(event as Map));
    });
  }

  @override
  Future<bool> canRequestInstallPackages() async {
    final result = await methodChannel.invokeMethod<bool>(
      'update.canRequestInstallPackages',
    );
    return result ?? false;
  }

  @override
  Future<void> openUnknownSourcesSettings() async {
    await methodChannel.invokeMethod<void>('update.openUnknownSourcesSettings');
  }

  @override
  Future<void> installApk({required String apkPath}) async {
    await methodChannel.invokeMethod<void>('update.installApk', {
      'apkPath': apkPath,
    });
  }

  @override
  Future<void> openUrl({required String url}) async {
    await methodChannel.invokeMethod<void>('update.openUrl', {'url': url});
  }

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
  }) async {
    await methodChannel.invokeMethod<void>('git.clone', {
      'remoteUrl': remoteUrl,
      'localRepoDirUri': localRepoDirUri,
      'branch': branch,
      'username': username,
      'token': token,
      'userName': userName,
      'userEmail': userEmail,
      'allowInsecure': allowInsecure,
    });
  }

  @override
  Future<void> gitCheckout({
    required String localRepoDirUri,
    required String ref,
  }) async {
    await methodChannel.invokeMethod<void>('git.checkout', {
      'localRepoDirUri': localRepoDirUri,
      'ref': ref,
    });
  }

  @override
  Future<void> gitPull({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure = false,
  }) async {
    await methodChannel.invokeMethod<void>('git.pull', {
      'localRepoDirUri': localRepoDirUri,
      'remote': remote,
      'branch': branch,
      'username': username,
      'token': token,
      'allowInsecure': allowInsecure,
    });
  }

  @override
  Future<void> gitPush({
    required String localRepoDirUri,
    String? remote,
    String? branch,
    String? username,
    String? token,
    bool allowInsecure = false,
  }) async {
    await methodChannel.invokeMethod<void>('git.push', {
      'localRepoDirUri': localRepoDirUri,
      'remote': remote,
      'branch': branch,
      'username': username,
      'token': token,
      'allowInsecure': allowInsecure,
    });
  }

  @override
  Future<GitStatus> gitStatus({required String localRepoDirUri}) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'git.status',
      {'localRepoDirUri': localRepoDirUri},
    );
    return GitStatus.fromMap(result ?? const <Object?, Object?>{});
  }

  @override
  Future<String> gitDiff({
    required String localRepoDirUri,
    int maxBytes = 400000,
  }) async {
    final result = await methodChannel.invokeMethod<String>('git.diff', {
      'localRepoDirUri': localRepoDirUri,
      'maxBytes': maxBytes,
    });
    return result ?? '';
  }

  @override
  Future<List<GitCommitSummary>> gitRecentCommits({
    required String localRepoDirUri,
    int limit = 24,
  }) async {
    final result = await methodChannel.invokeListMethod<Object?>(
      'git.recentCommits',
      {'localRepoDirUri': localRepoDirUri, 'limit': limit},
    );
    if (result == null) {
      return const <GitCommitSummary>[];
    }
    return result
        .whereType<Map>()
        .map(
          (item) => GitCommitSummary.fromMap(Map<Object?, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<String> gitShowCommit({
    required String localRepoDirUri,
    required String hash,
    int maxBytes = 120000,
  }) async {
    final result = await methodChannel.invokeMethod<String>('git.showCommit', {
      'localRepoDirUri': localRepoDirUri,
      'hash': hash,
      'maxBytes': maxBytes,
    });
    return result ?? '';
  }

  @override
  Future<GitRepositoryInfo> gitInitRepository({
    required String localRepoDirUri,
    required String initialBranch,
  }) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'git.initRepository',
      {'localRepoDirUri': localRepoDirUri, 'initialBranch': initialBranch},
    );
    return GitRepositoryInfo.fromMap(result ?? const {});
  }

  @override
  Future<GitRepositoryInfo> gitRepositoryInfo({
    required String localRepoDirUri,
  }) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'git.repositoryInfo',
      {'localRepoDirUri': localRepoDirUri},
    );
    return GitRepositoryInfo.fromMap(result ?? const {});
  }

  @override
  Future<GitWorktreeInfo> gitCreateWorktree({
    required String mainRepoDirUri,
    required String worktreeDirUri,
    required String name,
    required String branchName,
    required String startRef,
  }) async {
    final result = await methodChannel
        .invokeMapMethod<Object?, Object?>('git.createWorktree', {
          'mainRepoDirUri': mainRepoDirUri,
          'worktreeDirUri': worktreeDirUri,
          'name': name,
          'branchName': branchName,
          'startRef': startRef,
        });
    return GitWorktreeInfo.fromMap(result ?? const {});
  }

  @override
  Future<List<GitWorktreeInfo>> gitListWorktrees({
    required String mainRepoDirUri,
  }) async {
    final result = await methodChannel.invokeListMethod<Object?>(
      'git.listWorktrees',
      {'mainRepoDirUri': mainRepoDirUri},
    );
    return (result ?? const <Object?>[])
        .whereType<Map>()
        .map(
          (item) => GitWorktreeInfo.fromMap(Map<Object?, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> gitRemoveWorktree({
    required String mainRepoDirUri,
    required String name,
    required bool force,
  }) {
    return methodChannel.invokeMethod<void>('git.removeWorktree', {
      'mainRepoDirUri': mainRepoDirUri,
      'name': name,
      'force': force,
    });
  }

  @override
  Future<GitCommitResult> gitCreateCheckpoint({
    required String localRepoDirUri,
    required String message,
    required String userName,
    required String userEmail,
  }) async {
    final result = await methodChannel
        .invokeMapMethod<Object?, Object?>('git.createCheckpoint', {
          'localRepoDirUri': localRepoDirUri,
          'message': message,
          'userName': userName,
          'userEmail': userEmail,
        });
    return GitCommitResult.fromMap(result ?? const {});
  }

  @override
  Future<bool> gitIsAncestor({
    required String localRepoDirUri,
    required String ancestorRef,
    required String descendantRef,
  }) async {
    return await methodChannel.invokeMethod<bool>('git.isAncestor', {
          'localRepoDirUri': localRepoDirUri,
          'ancestorRef': ancestorRef,
          'descendantRef': descendantRef,
        }) ??
        false;
  }

  @override
  Future<void> gitDeleteBranch({
    required String localRepoDirUri,
    required String branchName,
    required bool force,
  }) {
    return methodChannel.invokeMethod<void>('git.deleteBranch', {
      'localRepoDirUri': localRepoDirUri,
      'branchName': branchName,
      'force': force,
    });
  }

  @override
  Future<GitMergeResult> gitMerge({
    required String targetRepoDirUri,
    required String sourceRef,
    required String message,
    required String userName,
    required String userEmail,
  }) => _mergeResult('git.merge', {
    'targetRepoDirUri': targetRepoDirUri,
    'sourceRef': sourceRef,
    'message': message,
    'userName': userName,
    'userEmail': userEmail,
  });

  @override
  Future<GitMergeResult> gitMergeState({required String targetRepoDirUri}) =>
      _mergeResult('git.mergeState', {'targetRepoDirUri': targetRepoDirUri});

  @override
  Future<GitMergeResult> gitContinueMerge({
    required String targetRepoDirUri,
    required String message,
    required String userName,
    required String userEmail,
  }) => _mergeResult('git.continueMerge', {
    'targetRepoDirUri': targetRepoDirUri,
    'message': message,
    'userName': userName,
    'userEmail': userEmail,
  });

  Future<GitMergeResult> _mergeResult(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      method,
      arguments,
    );
    return GitMergeResult.fromMap(result ?? const {});
  }

  @override
  Future<void> gitAbortMerge({required String targetRepoDirUri}) {
    return methodChannel.invokeMethod<void>('git.abortMerge', {
      'targetRepoDirUri': targetRepoDirUri,
    });
  }
}
