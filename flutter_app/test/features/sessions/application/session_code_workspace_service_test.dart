import 'dart:io';

import 'package:codexm_flutter/features/sessions/application/session_code_workspace_service.dart';
import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provisions isolated worktrees and merges session branches', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    var workspace = await fixture.workspaceStore.createWorkspace(name: 'Demo');
    workspace = await fixture.service.prepareNewWorkspace(workspace);
    workspace = await fixture.service.updateGitIdentity(
      workspace,
      userName: 'Codex User',
      userEmail: 'codex@example.com',
    );

    final first = await fixture.service.createSession(
      workspace,
      title: 'First',
    );
    final second = await fixture.service.createSession(
      workspace,
      title: 'Second',
    );
    final paths = await fixture.directoryService.pathsFor(workspace.id);

    expect(first.codeState, SessionCodeState.ready);
    expect(second.codeState, SessionCodeState.ready);
    expect(first.branchName, isNot(second.branchName));
    expect(paths.sessionWorktreeDir(first.id).existsSync(), isTrue);
    expect(paths.sessionWorktreeDir(second.id).existsSync(), isTrue);

    final result = await fixture.service.merge(
      workspace,
      source: first,
      target: second,
    );
    expect(result.outcome, GitMergeOutcome.merged);
    expect(fixture.native.lastMergeSource, first.branchName);
    expect(
      fixture.native.lastMergeTarget,
      paths.sessionWorktreeDir(second.id).path,
    );

    await fixture.service.archive(workspace, first);
    final archived = await fixture.sessionStore.getSession(
      workspace.id,
      first.id,
    );
    expect(archived?.codeState, SessionCodeState.archived);
    expect(paths.sessionWorktreeDir(first.id).existsSync(), isFalse);
  });

  test('requires an explicit baseline for dirty legacy workspaces', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    final workspace = await fixture.workspaceStore.createWorkspace(
      name: 'Legacy',
    );
    await fixture.sessionStore.createSession(
      workspace.id,
      title: 'Legacy session',
    );
    final paths = await fixture.directoryService.pathsFor(workspace.id);
    fixture.native.statuses[paths.repoDir.path] = const GitStatus(
      staged: [],
      unstaged: [],
      untracked: ['draft.txt'],
    );

    await expectLater(
      fixture.service.migrateWorkspace(workspace),
      throwsA(isA<SessionCodeMigrationRequiredException>()),
    );
    final sessions = await fixture.sessionStore.listSessions(workspace.id);
    expect(sessions.single.codeState, SessionCodeState.migrationRequired);
    expect(paths.sessionWorktreeDir(sessions.single.id).existsSync(), isFalse);
  });

  test('protects unmerged code and allows explicit forced deletion', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    var workspace = await fixture.workspaceStore.createWorkspace(name: 'Demo');
    workspace = await fixture.service.prepareNewWorkspace(workspace);
    final session = await fixture.service.createSession(
      workspace,
      title: 'Unmerged',
    );
    fixture.native.isAncestor = false;

    await expectLater(
      fixture.service.delete(workspace, session, force: false),
      throwsA(isA<SessionCodeUnmergedException>()),
    );
    expect(
      await fixture.sessionStore.getSession(workspace.id, session.id),
      isNotNull,
    );

    await fixture.service.delete(workspace, session, force: true);

    expect(
      await fixture.sessionStore.getSession(workspace.id, session.id),
      isNull,
    );
    expect(fixture.native.deletedBranches, contains(session.branchName));
  });

  test('never deletes a session referenced by an active merge', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    var workspace = await fixture.workspaceStore.createWorkspace(name: 'Demo');
    workspace = await fixture.service.prepareNewWorkspace(workspace);
    final source = await fixture.service.createSession(
      workspace,
      title: 'Source',
    );
    final target = await fixture.service.createSession(
      workspace,
      title: 'Target',
    );
    await fixture.sessionStore.updateSessionCodeContext(
      workspace.id,
      target.id,
      codeState: SessionCodeState.conflict,
      pendingMergeSourceSessionId: source.id,
    );

    await expectLater(
      fixture.service.delete(workspace, source, force: true),
      throwsA(isA<SessionCodeMergeInProgressException>()),
    );
    expect(
      await fixture.sessionStore.getSession(workspace.id, source.id),
      isNotNull,
    );
    expect(fixture.native.deletedBranches, isEmpty);
  });
}

class _Fixture {
  _Fixture({
    required this.documentsDir,
    required this.temporaryDir,
    required this.native,
    required this.directoryService,
    required this.workspaceStore,
    required this.sessionStore,
    required this.service,
  });

  final Directory documentsDir;
  final Directory temporaryDir;
  final _FakeNative native;
  final WorkspaceDirectoryService directoryService;
  final WorkspaceStore workspaceStore;
  final SessionStore sessionStore;
  final SessionCodeWorkspaceService service;

  static Future<_Fixture> create() async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final directoryService = WorkspaceDirectoryService(
      appDirectoryService: appDirectoryService,
    );
    final workspaceStore = WorkspaceStore(
      appDirectoryService: appDirectoryService,
      workspaceDirectoryService: directoryService,
    );
    final sessionStore = SessionStore(
      workspaceDirectoryService: directoryService,
    );
    final native = _FakeNative();
    final service = SessionCodeWorkspaceService(
      native: native,
      workspaceStore: workspaceStore,
      workspaceDirectoryService: directoryService,
      sessionStore: sessionStore,
    );
    return _Fixture(
      documentsDir: documentsDir,
      temporaryDir: temporaryDir,
      native: native,
      directoryService: directoryService,
      workspaceStore: workspaceStore,
      sessionStore: sessionStore,
      service: service,
    );
  }

  Future<void> dispose() async {
    if (documentsDir.existsSync()) await documentsDir.delete(recursive: true);
    if (temporaryDir.existsSync()) await temporaryDir.delete(recursive: true);
  }
}

class _FakeNative extends CodexmNative {
  final Map<String, GitStatus> statuses = <String, GitStatus>{};
  final List<GitWorktreeInfo> worktrees = <GitWorktreeInfo>[];
  final List<String> deletedBranches = <String>[];
  String? lastMergeSource;
  String? lastMergeTarget;
  bool isAncestor = true;

  @override
  Future<GitRepositoryInfo> gitInitRepository({
    required String localRepoDirUri,
    String initialBranch = 'main',
  }) async => GitRepositoryInfo(
    branch: initialBranch,
    headOid: 'head-1',
    isClean: true,
    isMerging: false,
  );

  @override
  Future<GitRepositoryInfo> gitRepositoryInfo({
    required String localRepoDirUri,
  }) async => const GitRepositoryInfo(
    branch: 'main',
    headOid: 'head-1',
    isClean: true,
    isMerging: false,
  );

  @override
  Future<GitStatus> gitStatus({required String localRepoDirUri}) async =>
      statuses[localRepoDirUri] ??
      const GitStatus(staged: [], unstaged: [], untracked: []);

  @override
  Future<String> gitDiff({
    required String localRepoDirUri,
    int maxBytes = 400000,
  }) async => 'diff';

  @override
  Future<List<GitWorktreeInfo>> gitListWorktrees({
    required String mainRepoDirUri,
  }) async => List<GitWorktreeInfo>.from(worktrees);

  @override
  Future<GitWorktreeInfo> gitCreateWorktree({
    required String mainRepoDirUri,
    required String worktreeDirUri,
    required String name,
    required String branchName,
    required String startRef,
  }) async {
    await Directory(worktreeDirUri).create(recursive: true);
    final result = GitWorktreeInfo(
      name: name,
      path: worktreeDirUri,
      valid: true,
      locked: false,
    );
    worktrees.add(result);
    return result;
  }

  @override
  Future<void> gitRemoveWorktree({
    required String mainRepoDirUri,
    required String name,
    bool force = false,
  }) async {
    final match = worktrees.where((item) => item.name == name).first;
    final dir = Directory(match.path);
    if (dir.existsSync()) await dir.delete(recursive: true);
    worktrees.removeWhere((item) => item.name == name);
  }

  @override
  Future<GitMergeResult> gitMerge({
    required String targetRepoDirUri,
    required String sourceRef,
    required String message,
    required String userName,
    required String userEmail,
  }) async {
    lastMergeSource = sourceRef;
    lastMergeTarget = targetRepoDirUri;
    return const GitMergeResult(
      outcome: GitMergeOutcome.merged,
      headOid: 'merged-1',
      conflictPaths: [],
    );
  }

  @override
  Future<bool> gitIsAncestor({
    required String localRepoDirUri,
    required String ancestorRef,
    required String descendantRef,
  }) async => isAncestor;

  @override
  Future<void> gitDeleteBranch({
    required String localRepoDirUri,
    required String branchName,
    bool force = false,
  }) async {
    deletedBranches.add(branchName);
  }
}
