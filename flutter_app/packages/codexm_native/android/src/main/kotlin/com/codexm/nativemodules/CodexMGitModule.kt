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
}
