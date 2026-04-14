package com.codexm.nativeplugin

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class UpdateMethodHandler(private val appContext: Context) {
    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "update.getAppInfo" -> {
                    val packageInfo = packageInfo()
                    result.success(
                        mapOf(
                            "packageName" to appContext.packageName,
                            "versionName" to packageInfo.versionName.orEmpty(),
                            "versionCode" to packageVersionCode(packageInfo).toInt(),
                        ),
                    )
                }

                "update.canRequestInstallPackages" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        appContext.packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(allowed)
                }

                "update.openUnknownSourcesSettings" -> {
                    launchIntent(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${appContext.packageName}"),
                        ),
                    )
                    result.success(null)
                }

                "update.installApk" -> {
                    val apkPath = call.requiredString("apkPath")
                    val apkFile = File(apkPath)
                    if (!apkFile.exists()) {
                        throw IllegalArgumentException("APK 文件不存在。")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !appContext.packageManager.canRequestPackageInstalls()
                    ) {
                        throw SecurityException("当前应用未获准安装未知应用。")
                    }
                    val uri = FileProvider.getUriForFile(
                        appContext,
                        "${appContext.packageName}.codexm_update_provider",
                        apkFile,
                    )
                    launchIntent(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }

                "update.openUrl" -> {
                    launchIntent(
                        Intent(Intent.ACTION_VIEW, Uri.parse(call.requiredString("url"))),
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error(
                updateErrorCode(call.method, error),
                error.message,
                mapOf("method" to call.method),
            )
        }
    }

    private fun packageInfo(): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.packageManager.getPackageInfo(
                appContext.packageName,
                android.content.pm.PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        }
    }

    private fun packageVersionCode(packageInfo: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
    }

    private fun launchIntent(intent: Intent) {
        val safeIntent = intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            appContext.startActivity(safeIntent)
        } catch (error: ActivityNotFoundException) {
            throw IllegalStateException("系统中没有可处理该操作的应用。", error)
        }
    }
}

private fun updateErrorCode(method: String, error: Throwable): String {
    return when {
        method == "update.installApk" && error is SecurityException -> "E_UPDATE_INSTALL_PERMISSION"
        method == "update.installApk" -> "E_UPDATE_INSTALL_APK"
        method == "update.openUnknownSourcesSettings" -> "E_UPDATE_OPEN_UNKNOWN_SOURCES"
        method == "update.openUrl" -> "E_UPDATE_OPEN_URL"
        method == "update.getAppInfo" -> "E_UPDATE_APP_INFO"
        method == "update.canRequestInstallPackages" -> "E_UPDATE_PERMISSION_STATUS"
        else -> "E_UPDATE_BRIDGE"
    }
}
