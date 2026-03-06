package com.codexm.nativeplugin

import com.codexm.nativemodules.CodexRuntimeManager
import com.codexm.nativemodules.RuntimeStartRequest
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RuntimeMethodHandler(private val runtimeManager: CodexRuntimeManager) {
    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "runtime.start" -> result.success(runtimeManager.start(call.toRuntimeStartRequest()))

                "runtime.stop" -> {
                    runtimeManager.stop(call.optionalString("runtimeId"))
                    result.success(null)
                }

                "runtime.sendLine" -> {
                    runtimeManager.send(
                        runtimeId = call.optionalString("runtimeId") ?: "default",
                        line = call.requiredString("line"),
                    )
                    result.success(null)
                }

                "runtime.chmodPath" -> {
                    runtimeManager.chmod(call.requiredString("path"))
                    result.success(null)
                }

                "runtime.extractTarGz" -> {
                    runtimeManager.extractTarGz(
                        archivePath = call.requiredString("archivePath"),
                        destDir = call.requiredString("destDir"),
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error(
                runtimeErrorCode(call.method),
                error.message,
                mapOf("method" to call.method),
            )
        }
    }

    fun dispose() {
        runtimeManager.stopAll()
    }
}

private fun MethodCall.toRuntimeStartRequest(): RuntimeStartRequest {
    return RuntimeStartRequest(
        runtimeId = optionalString("runtimeId") ?: "default",
        cwdUri = requiredString("cwdUri"),
        executablePath = optionalString("executablePath"),
        assetPath = optionalString("assetPath"),
        args = optionalStringList("args") ?: emptyList(),
        env = optionalStringMap("env") ?: emptyMap(),
    )
}

private fun runtimeErrorCode(method: String): String {
    return when (method) {
        "runtime.start" -> "E_CODEX_RUNTIME_START"
        "runtime.stop" -> "E_CODEX_RUNTIME_STOP"
        "runtime.sendLine" -> "E_CODEX_RUNTIME_SEND"
        "runtime.chmodPath" -> "E_CHMOD"
        "runtime.extractTarGz" -> "E_TAR_GZ"
        else -> "E_RUNTIME_BRIDGE"
    }
}
