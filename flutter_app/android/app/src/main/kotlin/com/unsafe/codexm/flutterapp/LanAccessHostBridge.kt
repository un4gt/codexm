package com.unsafe.codexm.flutterapp

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LanAccessHostBridge(
    private val applicationContext: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, "codexm/lan_access")
    private val eventChannel = EventChannel(messenger, "codexm/lan_networks")
    private val networkMonitor = LanNetworkMonitor(applicationContext)

    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun attachActivity(value: Activity) {
        activity = value
    }

    fun detachActivity(value: Activity) {
        if (activity === value) {
            activity = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNetworkSnapshot" -> result.success(networkMonitor.snapshot())
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }
            "startForegroundService" -> {
                LanAccessForegroundService.start(
                    applicationContext,
                    call.argument<String>("message").orEmpty(),
                )
                result.success(null)
            }
            "updateForegroundService" -> {
                LanAccessForegroundService.update(
                    applicationContext,
                    call.argument<String>("message").orEmpty(),
                )
                result.success(null)
            }
            "stopForegroundService" -> {
                LanAccessForegroundService.stop(applicationContext)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        networkMonitor.start(events)
    }

    override fun onCancel(arguments: Any?) {
        networkMonitor.stop()
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (
            ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("activity_unavailable", "请打开应用后再启用局域网访问。", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_in_progress", "正在请求通知权限。", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.first() == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            data = Uri.parse("package:${applicationContext.packageName}")
            putExtra(Settings.EXTRA_APP_PACKAGE, applicationContext.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        applicationContext.startActivity(intent)
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 9021
    }
}
