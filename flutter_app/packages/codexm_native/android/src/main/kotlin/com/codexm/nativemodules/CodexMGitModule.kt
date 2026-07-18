package com.codexm.nativemodules

import android.net.Uri

class CodexMGitModule {
    init {
        System.loadLibrary("codexm_git")
    }

    private fun uriToFilePath(uriOrPath: String): String {
        return try {
            val uri = Uri.parse(uriOrPath)
            if (uri.scheme == null) {
                uriOrPath
            } else {
                uri.path ?: uriOrPath
            }
        } catch (_: Throwable) {
            uriOrPath
        }
    }

    private external fun nativeClone(
        remoteUrl: String,
        localPath: String,
        branch: String?,
        username: String?,
        token: String?,
        userName: String?,
        userEmail: String?,
        allowInsecure: Boolean,
    )

    private external fun nativeCheckout(localPath: String, ref: String)

    private external fun nativePull(
        localPath: String,
        remote: String?,
        branch: String?,
        username: String?,
        token: String?,
        allowInsecure: Boolean,
    )

    private external fun nativePush(
        localPath: String,
        remote: String?,
        branch: String?,
        username: String?,
        token: String?,
        allowInsecure: Boolean,
    )

    private external fun nativeStatus(localPath: String): Map<String, List<String>>
    private external fun nativeDiff(localPath: String, maxBytes: Int): String
    private external fun nativeRecentCommits(localPath: String, limit: Int): List<Map<String, Any?>>
    private external fun nativeShowCommit(localPath: String, hash: String, maxBytes: Int): String
    private external fun nativeInitRepository(localPath: String, initialBranch: String): Map<String, Any?>
    private external fun nativeRepositoryInfo(localPath: String): Map<String, Any?>
    private external fun nativeCreateWorktree(
        mainRepoPath: String,
        worktreePath: String,
        name: String,
        branchName: String,
        startRef: String,
    ): Map<String, Any?>
    private external fun nativeListWorktrees(mainRepoPath: String): List<Map<String, Any?>>
    private external fun nativeRemoveWorktree(mainRepoPath: String, name: String, force: Boolean)
    private external fun nativeCreateCheckpoint(
        localPath: String,
        message: String,
        userName: String,
        userEmail: String,
    ): Map<String, Any?>
    private external fun nativeIsAncestor(
        localPath: String,
        ancestorRef: String,
        descendantRef: String,
    ): Boolean
    private external fun nativeDeleteBranch(localPath: String, branchName: String, force: Boolean)
    private external fun nativeMerge(
        targetPath: String,
        sourceRef: String,
        message: String,
        userName: String,
        userEmail: String,
    ): Map<String, Any?>
    private external fun nativeMergeState(targetPath: String): Map<String, Any?>
    private external fun nativeContinueMerge(
        targetPath: String,
        message: String,
        userName: String,
        userEmail: String,
    ): Map<String, Any?>
    private external fun nativeAbortMerge(targetPath: String)

    fun clone(
        remoteUrl: String,
        localRepoDirUri: String,
        branch: String?,
        username: String?,
        token: String?,
        userName: String?,
        userEmail: String?,
        allowInsecure: Boolean,
    ) {
        nativeClone(
            remoteUrl,
            uriToFilePath(localRepoDirUri),
            branch,
            username,
            token,
            userName,
            userEmail,
            allowInsecure,
        )
    }

    fun checkout(localRepoDirUri: String, ref: String) {
        nativeCheckout(uriToFilePath(localRepoDirUri), ref)
    }

    fun pull(
        localRepoDirUri: String,
        remote: String?,
        branch: String?,
        username: String?,
        token: String?,
        allowInsecure: Boolean,
    ) {
        nativePull(
            uriToFilePath(localRepoDirUri),
            remote,
            branch,
            username,
            token,
            allowInsecure,
        )
    }

    fun push(
        localRepoDirUri: String,
        remote: String?,
        branch: String?,
        username: String?,
        token: String?,
        allowInsecure: Boolean,
    ) {
        nativePush(
            uriToFilePath(localRepoDirUri),
            remote,
            branch,
            username,
            token,
            allowInsecure,
        )
    }

    fun status(localRepoDirUri: String): Map<String, List<String>> {
        return nativeStatus(uriToFilePath(localRepoDirUri))
    }

    fun diff(localRepoDirUri: String, maxBytes: Int): String {
        return nativeDiff(uriToFilePath(localRepoDirUri), maxBytes)
    }

    fun recentCommits(localRepoDirUri: String, limit: Int): List<Map<String, Any?>> {
        return nativeRecentCommits(uriToFilePath(localRepoDirUri), limit)
    }

    fun showCommit(localRepoDirUri: String, hash: String, maxBytes: Int): String {
        return nativeShowCommit(uriToFilePath(localRepoDirUri), hash, maxBytes)
    }

    fun initRepository(localRepoDirUri: String, initialBranch: String): Map<String, Any?> =
        nativeInitRepository(uriToFilePath(localRepoDirUri), initialBranch)

    fun repositoryInfo(localRepoDirUri: String): Map<String, Any?> =
        nativeRepositoryInfo(uriToFilePath(localRepoDirUri))

    fun createWorktree(
        mainRepoDirUri: String,
        worktreeDirUri: String,
        name: String,
        branchName: String,
        startRef: String,
    ): Map<String, Any?> = nativeCreateWorktree(
        uriToFilePath(mainRepoDirUri),
        uriToFilePath(worktreeDirUri),
        name,
        branchName,
        startRef,
    )

    fun listWorktrees(mainRepoDirUri: String): List<Map<String, Any?>> =
        nativeListWorktrees(uriToFilePath(mainRepoDirUri))

    fun removeWorktree(mainRepoDirUri: String, name: String, force: Boolean) =
        nativeRemoveWorktree(uriToFilePath(mainRepoDirUri), name, force)

    fun createCheckpoint(
        localRepoDirUri: String,
        message: String,
        userName: String,
        userEmail: String,
    ): Map<String, Any?> = nativeCreateCheckpoint(
        uriToFilePath(localRepoDirUri),
        message,
        userName,
        userEmail,
    )

    fun isAncestor(localRepoDirUri: String, ancestorRef: String, descendantRef: String): Boolean =
        nativeIsAncestor(uriToFilePath(localRepoDirUri), ancestorRef, descendantRef)

    fun deleteBranch(localRepoDirUri: String, branchName: String, force: Boolean) =
        nativeDeleteBranch(uriToFilePath(localRepoDirUri), branchName, force)

    fun merge(
        targetRepoDirUri: String,
        sourceRef: String,
        message: String,
        userName: String,
        userEmail: String,
    ): Map<String, Any?> = nativeMerge(
        uriToFilePath(targetRepoDirUri),
        sourceRef,
        message,
        userName,
        userEmail,
    )

    fun mergeState(targetRepoDirUri: String): Map<String, Any?> =
        nativeMergeState(uriToFilePath(targetRepoDirUri))

    fun continueMerge(
        targetRepoDirUri: String,
        message: String,
        userName: String,
        userEmail: String,
    ): Map<String, Any?> = nativeContinueMerge(
        uriToFilePath(targetRepoDirUri),
        message,
        userName,
        userEmail,
    )

    fun abortMerge(targetRepoDirUri: String) = nativeAbortMerge(uriToFilePath(targetRepoDirUri))
}
