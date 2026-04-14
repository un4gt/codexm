import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'codexm_native_platform_interface.dart';
import 'src/models/app_update_app_info.dart';
import 'src/models/git_commit_summary.dart';
import 'src/models/git_status.dart';
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
    await methodChannel.invokeMethod<void>('runtime.chmodPath', {
      'path': path,
    });
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
    await methodChannel.invokeMethod<void>('update.openUrl', {
      'url': url,
    });
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
      {
        'localRepoDirUri': localRepoDirUri,
        'limit': limit,
      },
    );
    if (result == null) {
      return const <GitCommitSummary>[];
    }
    return result
        .whereType<Map>()
        .map(
          (item) =>
              GitCommitSummary.fromMap(Map<Object?, Object?>.from(item)),
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
}
