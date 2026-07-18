import 'dart:io';

import 'package:codexm_native/codexm_native.dart';

import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_paths.dart';
import '../../workspaces/application/workspace_store.dart';
import 'session_models.dart';
import 'session_store.dart';

class SessionCodeDirtyException implements Exception {
  const SessionCodeDirtyException(this.status);

  final GitStatus status;
}

class SessionCodeMigrationRequiredException implements Exception {
  const SessionCodeMigrationRequiredException({
    required this.status,
    required this.diff,
  });

  final GitStatus status;
  final String diff;
}

class SessionCodeIdentityRequiredException implements Exception {
  const SessionCodeIdentityRequiredException();
}

class SessionCodeUnmergedException implements Exception {
  const SessionCodeUnmergedException();
}

class SessionCodeMergeInProgressException implements Exception {
  const SessionCodeMergeInProgressException();
}

class SessionCodeWorkspaceService {
  SessionCodeWorkspaceService({
    CodexmNative? native,
    WorkspaceStore? workspaceStore,
    WorkspaceDirectoryService? workspaceDirectoryService,
    SessionStore? sessionStore,
  }) : _native = native ?? const CodexmNative(),
       _workspaceStore = workspaceStore ?? WorkspaceStore(),
       _workspaceDirectoryService =
           workspaceDirectoryService ?? WorkspaceDirectoryService(),
       _sessionStore = sessionStore ?? SessionStore();

  final CodexmNative _native;
  final WorkspaceStore _workspaceStore;
  final WorkspaceDirectoryService _workspaceDirectoryService;
  final SessionStore _sessionStore;

  static String branchNameFor(SessionId sessionId) =>
      'codexm/session/$sessionId';

  static String worktreeNameFor(SessionId sessionId) =>
      'session-${sessionId.replaceAll('-', '')}';

  Future<Directory> workingDirectory(
    WorkspaceId workspaceId,
    SessionId sessionId,
  ) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspaceId);
    return paths.sessionWorktreeDir(sessionId);
  }

  Future<Workspace> prepareNewWorkspace(Workspace workspace) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final info = await _native.gitInitRepository(
      localRepoDirUri: paths.repoDir.path,
    );
    final updated = workspace.copyWith(
      integrationBranch: info.branch.isEmpty ? 'main' : info.branch,
      sessionGitVersion: 1,
    );
    await _workspaceStore.upsertWorkspace(updated);
    return updated;
  }

  Future<Workspace> registerClonedRepository(Workspace workspace) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final info = await _native.gitRepositoryInfo(
      localRepoDirUri: paths.repoDir.path,
    );
    final updated = workspace.copyWith(
      integrationBranch: info.branch.isEmpty
          ? (workspace.git?.defaultBranch ?? 'main')
          : info.branch,
      sessionGitVersion: 1,
      gitUserName: workspace.git?.userName,
      gitUserEmail: workspace.git?.userEmail,
    );
    await _workspaceStore.upsertWorkspace(updated);
    return updated;
  }

  Future<Workspace> ensureRepository(Workspace workspace) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    await paths.repoDir.create(recursive: true);
    await paths.worktreesDir.create(recursive: true);
    GitRepositoryInfo info;
    try {
      info = await _native.gitRepositoryInfo(
        localRepoDirUri: paths.repoDir.path,
      );
    } catch (_) {
      final gitEntry = FileSystemEntity.typeSync('${paths.repoDir.path}/.git');
      if (gitEntry != FileSystemEntityType.notFound) {
        rethrow;
      }
      info = await _native.gitInitRepository(
        localRepoDirUri: paths.repoDir.path,
      );
    }
    final latest =
        await _workspaceStore.getWorkspace(workspace.id) ?? workspace;
    final branch = latest.integrationBranch?.trim().isNotEmpty == true
        ? latest.integrationBranch!
        : (info.branch.isEmpty ? 'main' : info.branch);
    if (latest.integrationBranch == branch) {
      return latest;
    }
    final updated = latest.copyWith(integrationBranch: branch);
    await _workspaceStore.upsertWorkspace(updated);
    return updated;
  }

  Future<Workspace> migrateWorkspace(Workspace workspace) async {
    final prepared = await ensureRepository(workspace);
    final sessions = await _sessionStore.listSessions(prepared.id);
    final needsMigration =
        prepared.sessionGitVersion < 1 ||
        sessions.any((session) => session.branchName == null);
    if (!needsMigration) {
      return prepared;
    }
    final paths = await _workspaceDirectoryService.pathsFor(prepared.id);
    final status = await _native.gitStatus(localRepoDirUri: paths.repoDir.path);
    if (!status.isClean) {
      final diff = await _native.gitDiff(localRepoDirUri: paths.repoDir.path);
      for (final session in sessions) {
        await _sessionStore.updateSessionCodeContext(
          prepared.id,
          session.id,
          codeState: SessionCodeState.migrationRequired,
        );
      }
      throw SessionCodeMigrationRequiredException(status: status, diff: diff);
    }
    for (final session in sessions) {
      await _provisionSession(
        prepared,
        session,
        startRef: prepared.integrationBranch ?? 'main',
      );
    }
    final migrated = prepared.copyWith(sessionGitVersion: 1);
    await _workspaceStore.upsertWorkspace(migrated);
    return migrated;
  }

  Future<Workspace> checkpointMigrationBaseline(
    Workspace workspace, {
    required String message,
    required String userName,
    required String userEmail,
  }) async {
    final prepared = await updateGitIdentity(
      workspace,
      userName: userName,
      userEmail: userEmail,
    );
    final paths = await _workspaceDirectoryService.pathsFor(prepared.id);
    await _native.gitCreateCheckpoint(
      localRepoDirUri: paths.repoDir.path,
      message: message,
      userName: userName,
      userEmail: userEmail,
    );
    return migrateWorkspace(prepared);
  }

  Future<Workspace> updateGitIdentity(
    Workspace workspace, {
    required String userName,
    required String userEmail,
  }) async {
    final updated = workspace.copyWith(
      gitUserName: userName.trim(),
      gitUserEmail: userEmail.trim(),
    );
    await _workspaceStore.upsertWorkspace(updated);
    return updated;
  }

  Future<Session> ensurePrimarySession(Workspace workspace) async {
    final migrated = await migrateWorkspace(workspace);
    final existing = await _sessionStore.getPrimarySession(migrated.id);
    if (existing != null) {
      return ensureSessionWorktree(migrated, existing);
    }
    return createSession(migrated, title: '主会话');
  }

  Future<Session> createSession(
    Workspace workspace, {
    required String title,
    Session? sourceSession,
  }) async {
    final migrated = await migrateWorkspace(workspace);
    if (sourceSession != null) {
      final source = await ensureSessionWorktree(migrated, sourceSession);
      final sourceStatus = await statusFor(migrated, source);
      if (!sourceStatus.isClean) {
        throw SessionCodeDirtyException(sourceStatus);
      }
    }
    final session = await _sessionStore.createSession(
      migrated.id,
      title: title,
      createdFromSessionId: sourceSession?.id,
    );
    final startRef =
        sourceSession?.branchName ?? migrated.integrationBranch ?? 'main';
    return _provisionSession(migrated, session, startRef: startRef);
  }

  Future<Session> ensureSessionWorktree(
    Workspace workspace,
    Session session,
  ) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final worktree = paths.sessionWorktreeDir(session.id);
    if (worktree.existsSync()) {
      try {
        await _native.gitRepositoryInfo(localRepoDirUri: worktree.path);
        if (session.codeState == SessionCodeState.archived ||
            session.codeState == SessionCodeState.failed) {
          await _sessionStore.updateSessionCodeContext(
            workspace.id,
            session.id,
            codeState: SessionCodeState.ready,
            clearArchivedAt: true,
          );
          return (await _sessionStore.getSession(workspace.id, session.id))!;
        }
        return session;
      } catch (_) {
        // Reconcile against libgit2's worktree registry below.
      }
    }
    final branch = session.branchName;
    if (branch == null || branch.isEmpty) {
      return _provisionSession(
        workspace,
        session,
        startRef: workspace.integrationBranch ?? 'main',
      );
    }
    return _provisionSession(workspace, session, startRef: branch);
  }

  Future<Session> _provisionSession(
    Workspace workspace,
    Session session, {
    required String startRef,
  }) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final branch = session.branchName ?? branchNameFor(session.id);
    final worktreeName = worktreeNameFor(session.id);
    await _sessionStore.updateSessionCodeContext(
      workspace.id,
      session.id,
      branchName: branch,
      codeState: SessionCodeState.provisioning,
    );
    try {
      final registered = await _native.gitListWorktrees(
        mainRepoDirUri: paths.repoDir.path,
      );
      GitWorktreeInfo? existing;
      for (final item in registered) {
        if (item.name == worktreeName && item.valid) {
          existing = item;
          break;
        }
      }
      if (existing == null) {
        await _native.gitCreateWorktree(
          mainRepoDirUri: paths.repoDir.path,
          worktreeDirUri: paths.sessionWorktreeDir(session.id).path,
          name: worktreeName,
          branchName: branch,
          startRef: startRef,
        );
      }
      final info = await _native.gitRepositoryInfo(
        localRepoDirUri: paths.sessionWorktreeDir(session.id).path,
      );
      await _sessionStore.updateSessionCodeContext(
        workspace.id,
        session.id,
        branchName: branch,
        baseCommitOid: session.baseCommitOid ?? info.headOid,
        codeState: SessionCodeState.ready,
        clearArchivedAt: true,
      );
    } catch (_) {
      await _sessionStore.updateSessionCodeContext(
        workspace.id,
        session.id,
        branchName: branch,
        codeState: SessionCodeState.failed,
      );
      rethrow;
    }
    return (await _sessionStore.getSession(workspace.id, session.id))!;
  }

  Future<GitStatus> statusFor(Workspace workspace, Session session) async {
    final ready = await ensureSessionWorktree(workspace, session);
    final dir = await workingDirectory(workspace.id, ready.id);
    return _native.gitStatus(localRepoDirUri: dir.path);
  }

  Future<GitCommitResult> checkpoint(
    Workspace workspace,
    Session session, {
    required String message,
  }) async {
    final identity = _identityFor(workspace);
    final ready = await ensureSessionWorktree(workspace, session);
    final dir = await workingDirectory(workspace.id, ready.id);
    return _native.gitCreateCheckpoint(
      localRepoDirUri: dir.path,
      message: message,
      userName: identity.$1,
      userEmail: identity.$2,
    );
  }

  Future<GitMergeResult> merge(
    Workspace workspace, {
    required Session source,
    Session? target,
  }) async {
    final identity = _identityFor(workspace);
    final sourceReady = await ensureSessionWorktree(workspace, source);
    final sourceStatus = await statusFor(workspace, sourceReady);
    if (!sourceStatus.isClean) {
      throw SessionCodeDirtyException(sourceStatus);
    }
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final targetPath = target == null
        ? paths.repoDir.path
        : (await workingDirectory(
            workspace.id,
            (await ensureSessionWorktree(workspace, target)).id,
          )).path;
    final targetStatus = await _native.gitStatus(localRepoDirUri: targetPath);
    if (!targetStatus.isClean) {
      throw SessionCodeDirtyException(targetStatus);
    }
    final targetLabel = target?.title ?? workspace.name;
    final result = await _native.gitMerge(
      targetRepoDirUri: targetPath,
      sourceRef: sourceReady.branchName!,
      message: 'Merge ${source.title} into $targetLabel',
      userName: identity.$1,
      userEmail: identity.$2,
    );
    if (result.outcome == GitMergeOutcome.conflicts) {
      if (target == null) {
        await _workspaceStore.upsertWorkspace(
          workspace.copyWith(pendingMergeSourceSessionId: source.id),
        );
      } else {
        await _sessionStore.updateSessionCodeContext(
          workspace.id,
          target.id,
          codeState: SessionCodeState.conflict,
          pendingMergeSourceSessionId: source.id,
        );
      }
    }
    return result;
  }

  Future<GitMergeResult> continueMerge(
    Workspace workspace, {
    Session? target,
  }) async {
    final identity = _identityFor(workspace);
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final targetPath = target == null
        ? paths.repoDir.path
        : (await workingDirectory(workspace.id, target.id)).path;
    final result = await _native.gitContinueMerge(
      targetRepoDirUri: targetPath,
      message: 'Complete CodexM session merge',
      userName: identity.$1,
      userEmail: identity.$2,
    );
    if (result.outcome != GitMergeOutcome.conflicts) {
      await _clearMergeState(workspace, target: target);
    }
    return result;
  }

  Future<void> abortMerge(Workspace workspace, {Session? target}) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final targetPath = target == null
        ? paths.repoDir.path
        : (await workingDirectory(workspace.id, target.id)).path;
    await _native.gitAbortMerge(targetRepoDirUri: targetPath);
    await _clearMergeState(workspace, target: target);
  }

  Future<void> _clearMergeState(Workspace workspace, {Session? target}) async {
    if (target == null) {
      final latest =
          await _workspaceStore.getWorkspace(workspace.id) ?? workspace;
      await _workspaceStore.upsertWorkspace(
        latest.copyWith(clearPendingMergeSourceSessionId: true),
      );
    } else {
      await _sessionStore.updateSessionCodeContext(
        workspace.id,
        target.id,
        codeState: SessionCodeState.ready,
        clearPendingMergeSourceSessionId: true,
      );
    }
  }

  Future<void> archive(Workspace workspace, Session session) async {
    final ready = await ensureSessionWorktree(workspace, session);
    final status = await statusFor(workspace, ready);
    if (!status.isClean) throw SessionCodeDirtyException(status);
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    await _native.gitRemoveWorktree(
      mainRepoDirUri: paths.repoDir.path,
      name: worktreeNameFor(session.id),
    );
    await _sessionStore.updateSessionCodeContext(
      workspace.id,
      session.id,
      codeState: SessionCodeState.archived,
      archivedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> delete(
    Workspace workspace,
    Session session, {
    required bool force,
  }) async {
    final sessions = await _sessionStore.listSessions(workspace.id);
    final referenced =
        sessions.any(
          (item) => item.pendingMergeSourceSessionId == session.id,
        ) ||
        workspace.pendingMergeSourceSessionId == session.id;
    if (referenced) throw const SessionCodeMergeInProgressException();
    final ready =
        session.codeState == SessionCodeState.archived ||
            (force && session.codeState == SessionCodeState.failed)
        ? session
        : await ensureSessionWorktree(workspace, session);
    if (ready.codeState != SessionCodeState.archived &&
        ready.codeState != SessionCodeState.failed) {
      final status = await statusFor(workspace, ready);
      if (!force && !status.isClean) throw SessionCodeDirtyException(status);
    }
    if (!force) {
      final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
      final merged = await _native.gitIsAncestor(
        localRepoDirUri: paths.repoDir.path,
        ancestorRef: ready.branchName!,
        descendantRef: workspace.integrationBranch ?? 'main',
      );
      if (!merged) throw const SessionCodeUnmergedException();
    }
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final worktreeName = worktreeNameFor(session.id);
    final registered = await _native.gitListWorktrees(
      mainRepoDirUri: paths.repoDir.path,
    );
    if (registered.any((item) => item.name == worktreeName)) {
      await _native.gitRemoveWorktree(
        mainRepoDirUri: paths.repoDir.path,
        name: worktreeName,
        force: force,
      );
    }
    await _native.gitDeleteBranch(
      localRepoDirUri: paths.repoDir.path,
      branchName: ready.branchName!,
      force: force,
    );
    await _sessionStore.deleteSession(workspace.id, session.id);
  }

  (String, String) _identityFor(Workspace workspace) {
    final name = workspace.gitUserName ?? workspace.git?.userName;
    final email = workspace.gitUserEmail ?? workspace.git?.userEmail;
    if (name?.trim().isEmpty != false || email?.trim().isEmpty != false) {
      throw const SessionCodeIdentityRequiredException();
    }
    return (name!.trim(), email!.trim());
  }
}
