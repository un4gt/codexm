import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codexm_native/codexm_native_method_channel.dart';
import 'package:codexm_native/codexm_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCodexmNative platform = MethodChannelCodexmNative();
  const MethodChannel channel = MethodChannel('codexm_native/methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return '42';
            case 'update.getAppInfo':
              return {
                'packageName': 'com.example.app',
                'versionName': '1.2.3',
                'versionCode': 123,
              };
            case 'git.repositoryInfo':
              return {
                'branch': 'main',
                'headOid': 'abc123',
                'isClean': true,
                'isMerging': false,
              };
            case 'git.createWorktree':
              final args = methodCall.arguments as Map;
              return {
                'name': args['name'],
                'path': args['worktreeDirUri'],
                'valid': true,
                'locked': false,
              };
            case 'git.merge':
              return {
                'outcome': 'conflicts',
                'headOid': 'def456',
                'conflictPaths': ['lib/main.dart'],
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('getAppUpdateAppInfo', () async {
    final info = await platform.getAppUpdateAppInfo();

    expect(info.packageName, 'com.example.app');
    expect(info.versionName, '1.2.3');
    expect(info.versionCode, 123);
  });

  test('parses repository and worktree results', () async {
    final repository = await platform.gitRepositoryInfo(
      localRepoDirUri: '/repo',
    );
    final worktree = await platform.gitCreateWorktree(
      mainRepoDirUri: '/repo',
      worktreeDirUri: '/worktrees/session',
      name: 'session-1',
      branchName: 'codexm/session/1',
      startRef: 'main',
    );

    expect(repository.branch, 'main');
    expect(repository.isClean, isTrue);
    expect(worktree.name, 'session-1');
    expect(worktree.path, '/worktrees/session');
  });

  test('parses structured merge conflicts', () async {
    final result = await platform.gitMerge(
      targetRepoDirUri: '/target',
      sourceRef: 'codexm/session/1',
      message: 'merge',
      userName: 'Codex User',
      userEmail: 'codex@example.com',
    );

    expect(result.outcome, GitMergeOutcome.conflicts);
    expect(result.conflictPaths, ['lib/main.dart']);
  });
}
