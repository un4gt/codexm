package com.codexm.nativeplugin

import com.codexm.nativemodules.CodexMGitModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GitMethodHandler {
    private val gitModule = CodexMGitModule()

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "git.clone" -> {
                    gitModule.clone(
                        remoteUrl = call.requiredString("remoteUrl"),
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        branch = call.optionalString("branch"),
                        username = call.optionalString("username"),
                        token = call.optionalString("token"),
                        userName = call.optionalString("userName"),
                        userEmail = call.optionalString("userEmail"),
                        allowInsecure = call.optionalBoolean("allowInsecure"),
                    )
                    result.success(null)
                }

                "git.checkout" -> {
                    gitModule.checkout(
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        ref = call.requiredString("ref"),
                    )
                    result.success(null)
                }

                "git.pull" -> {
                    gitModule.pull(
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        remote = call.optionalString("remote"),
                        branch = call.optionalString("branch"),
                        username = call.optionalString("username"),
                        token = call.optionalString("token"),
                        allowInsecure = call.optionalBoolean("allowInsecure"),
                    )
                    result.success(null)
                }

                "git.push" -> {
                    gitModule.push(
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        remote = call.optionalString("remote"),
                        branch = call.optionalString("branch"),
                        username = call.optionalString("username"),
                        token = call.optionalString("token"),
                        allowInsecure = call.optionalBoolean("allowInsecure"),
                    )
                    result.success(null)
                }

                "git.status" -> result.success(gitModule.status(call.requiredString("localRepoDirUri")))
                "git.diff" -> result.success(
                    gitModule.diff(
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        maxBytes = call.optionalInt("maxBytes", 400000),
                    )
                )
                "git.recentCommits" -> result.success(
                    gitModule.recentCommits(
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        limit = call.optionalInt("limit", 24),
                    )
                )
                "git.showCommit" -> result.success(
                    gitModule.showCommit(
                        localRepoDirUri = call.requiredString("localRepoDirUri"),
                        hash = call.requiredString("hash"),
                        maxBytes = call.optionalInt("maxBytes", 120000),
                    )
                )
                "git.initRepository" -> result.success(
                    gitModule.initRepository(
                        call.requiredString("localRepoDirUri"),
                        call.optionalString("initialBranch") ?: "main",
                    )
                )
                "git.repositoryInfo" -> result.success(
                    gitModule.repositoryInfo(call.requiredString("localRepoDirUri"))
                )
                "git.createWorktree" -> result.success(
                    gitModule.createWorktree(
                        call.requiredString("mainRepoDirUri"),
                        call.requiredString("worktreeDirUri"),
                        call.requiredString("name"),
                        call.requiredString("branchName"),
                        call.requiredString("startRef"),
                    )
                )
                "git.listWorktrees" -> result.success(
                    gitModule.listWorktrees(call.requiredString("mainRepoDirUri"))
                )
                "git.removeWorktree" -> {
                    gitModule.removeWorktree(
                        call.requiredString("mainRepoDirUri"),
                        call.requiredString("name"),
                        call.optionalBoolean("force"),
                    )
                    result.success(null)
                }
                "git.createCheckpoint" -> result.success(
                    gitModule.createCheckpoint(
                        call.requiredString("localRepoDirUri"),
                        call.requiredString("message"),
                        call.requiredString("userName"),
                        call.requiredString("userEmail"),
                    )
                )
                "git.isAncestor" -> result.success(
                    gitModule.isAncestor(
                        call.requiredString("localRepoDirUri"),
                        call.requiredString("ancestorRef"),
                        call.requiredString("descendantRef"),
                    )
                )
                "git.deleteBranch" -> {
                    gitModule.deleteBranch(
                        call.requiredString("localRepoDirUri"),
                        call.requiredString("branchName"),
                        call.optionalBoolean("force"),
                    )
                    result.success(null)
                }
                "git.merge" -> result.success(
                    gitModule.merge(
                        call.requiredString("targetRepoDirUri"),
                        call.requiredString("sourceRef"),
                        call.requiredString("message"),
                        call.requiredString("userName"),
                        call.requiredString("userEmail"),
                    )
                )
                "git.mergeState" -> result.success(
                    gitModule.mergeState(call.requiredString("targetRepoDirUri"))
                )
                "git.continueMerge" -> result.success(
                    gitModule.continueMerge(
                        call.requiredString("targetRepoDirUri"),
                        call.requiredString("message"),
                        call.requiredString("userName"),
                        call.requiredString("userEmail"),
                    )
                )
                "git.abortMerge" -> {
                    gitModule.abortMerge(call.requiredString("targetRepoDirUri"))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            val message = error.message.orEmpty()
            val code = when {
                message.contains("uncommitted", ignoreCase = true) ||
                    message.contains("dirty", ignoreCase = true) -> "E_GIT_DIRTY"
                message.contains("conflict", ignoreCase = true) -> "E_GIT_CONFLICT"
                message.contains("name and email", ignoreCase = true) -> "E_GIT_IDENTITY"
                message.contains("worktree", ignoreCase = true) -> "E_GIT_WORKTREE"
                message.contains("not found", ignoreCase = true) -> "E_GIT_NOT_FOUND"
                message.contains("permission", ignoreCase = true) -> "E_GIT_PERMISSION"
                else -> "E_GIT_BRIDGE"
            }
            result.error(code, message, null)
        }
    }
}
