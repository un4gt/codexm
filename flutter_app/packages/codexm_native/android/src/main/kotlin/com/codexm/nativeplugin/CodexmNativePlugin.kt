package com.codexm.nativeplugin

import android.os.Handler
import android.os.Looper
import com.codexm.nativemodules.CodexRuntimeManager
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CodexmNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var gitMethodHandler: GitMethodHandler
    private lateinit var runtimeManager: CodexRuntimeManager
    private lateinit var runtimeMethodHandler: RuntimeMethodHandler
    private lateinit var updateMethodHandler: UpdateMethodHandler
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "codexm_native/methods")
        eventChannel = EventChannel(binding.binaryMessenger, "codexm_native/runtime_lines")
        gitMethodHandler = GitMethodHandler()
        runtimeManager = CodexRuntimeManager(binding.applicationContext) { event ->
            mainHandler.post { eventSink?.success(event) }
        }
        runtimeMethodHandler = RuntimeMethodHandler(runtimeManager)
        updateMethodHandler = UpdateMethodHandler(binding.applicationContext)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        runtimeMethodHandler.dispose()
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when {
            call.method == "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            call.method.startsWith("git.") -> gitMethodHandler.onMethodCall(call, result)
            call.method.startsWith("runtime.") -> runtimeMethodHandler.onMethodCall(call, result)
            call.method.startsWith("update.") -> updateMethodHandler.onMethodCall(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
