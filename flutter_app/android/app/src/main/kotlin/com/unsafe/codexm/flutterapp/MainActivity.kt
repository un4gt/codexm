package com.unsafe.codexm.flutterapp

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val codexmApplication: CodexmApplication
        get() = application as CodexmApplication

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return codexmApplication.flutterEngine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        codexmApplication.lanAccessHostBridge.attachActivity(this)
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        codexmApplication.lanAccessHostBridge.detachActivity(this)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (
            codexmApplication.lanAccessHostBridge.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            )
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
