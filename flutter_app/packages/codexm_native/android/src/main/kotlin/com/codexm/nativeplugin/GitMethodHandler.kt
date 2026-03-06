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

                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("E_GIT_BRIDGE", error.message, null)
        }
    }
}
