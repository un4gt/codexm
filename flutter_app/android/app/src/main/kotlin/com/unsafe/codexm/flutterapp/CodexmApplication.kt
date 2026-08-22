package com.unsafe.codexm.flutterapp

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class CodexmApplication : Application() {
    lateinit var flutterEngine: FlutterEngine
        private set

    lateinit var lanAccessHostBridge: LanAccessHostBridge
        private set

    override fun onCreate() {
        super.onCreate()
        flutterEngine = FlutterEngine(this)
        lanAccessHostBridge = LanAccessHostBridge(
            applicationContext = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
    }

    companion object {
        const val ENGINE_ID = "codexm_app_engine"
    }
}
