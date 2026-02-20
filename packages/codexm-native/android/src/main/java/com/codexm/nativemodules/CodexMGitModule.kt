package com.codexm.nativemodules

import android.net.Uri
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import java.util.concurrent.Executors

class CodexMGitModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val ioExecutor = Executors.newCachedThreadPool()

  override fun getName(): String = "CodexMGit"

  init {
    System.loadLibrary("codexm_git")
  }

  private fun uriToFilePath(uriOrPath: String): String {
    return try {
      val uri = Uri.parse(uriOrPath)
      if (uri.scheme == null) uriOrPath else (uri.path ?: uriOrPath)
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

  private external fun nativeStatus(localPath: String): WritableMap
  private external fun nativeDiff(localPath: String, maxBytes: Int): String

  @ReactMethod
  fun clone(params: ReadableMap, promise: Promise) {
    ioExecutor.execute {
      try {
        val remoteUrl = params.getString("remoteUrl") ?: throw IllegalArgumentException("remoteUrl is required")
        val localRepoDirUri =
          params.getString("localRepoDirUri") ?: throw IllegalArgumentException("localRepoDirUri is required")
        val localPath = uriToFilePath(localRepoDirUri)
        val branch = if (params.hasKey("branch") && !params.isNull("branch")) params.getString("branch") else null

        val auth = if (params.hasKey("auth") && !params.isNull("auth")) params.getMap("auth") else null
        val username = auth?.getString("username")
        val token = auth?.getString("token")
        val userName = if (params.hasKey("userName") && !params.isNull("userName")) params.getString("userName") else null
        val userEmail = if (params.hasKey("userEmail") && !params.isNull("userEmail")) params.getString("userEmail") else null
        val allowInsecure = params.hasKey("allowInsecure") && params.getBoolean("allowInsecure")

        nativeClone(remoteUrl, localPath, branch, username, token, userName, userEmail, allowInsecure)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("E_GIT_CLONE", e.message, e)
      }
    }
  }

  @ReactMethod
  fun checkout(params: ReadableMap, promise: Promise) {
    ioExecutor.execute {
      try {
        val localRepoDirUri =
          params.getString("localRepoDirUri") ?: throw IllegalArgumentException("localRepoDirUri is required")
        val ref = params.getString("ref") ?: throw IllegalArgumentException("ref is required")
        nativeCheckout(uriToFilePath(localRepoDirUri), ref)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("E_GIT_CHECKOUT", e.message, e)
      }
    }
  }

  @ReactMethod
  fun pull(params: ReadableMap, promise: Promise) {
    ioExecutor.execute {
      try {
        val localRepoDirUri =
          params.getString("localRepoDirUri") ?: throw IllegalArgumentException("localRepoDirUri is required")
        val remote = if (params.hasKey("remote") && !params.isNull("remote")) params.getString("remote") else null
        val branch = if (params.hasKey("branch") && !params.isNull("branch")) params.getString("branch") else null

        val auth = if (params.hasKey("auth") && !params.isNull("auth")) params.getMap("auth") else null
        val username = auth?.getString("username")
        val token = auth?.getString("token")
        val allowInsecure = params.hasKey("allowInsecure") && params.getBoolean("allowInsecure")

        nativePull(uriToFilePath(localRepoDirUri), remote, branch, username, token, allowInsecure)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("E_GIT_PULL", e.message, e)
      }
    }
  }

  @ReactMethod
  fun push(params: ReadableMap, promise: Promise) {
    ioExecutor.execute {
      try {
        val localRepoDirUri =
          params.getString("localRepoDirUri") ?: throw IllegalArgumentException("localRepoDirUri is required")
        val remote = if (params.hasKey("remote") && !params.isNull("remote")) params.getString("remote") else null
        val branch = if (params.hasKey("branch") && !params.isNull("branch")) params.getString("branch") else null

        val auth = if (params.hasKey("auth") && !params.isNull("auth")) params.getMap("auth") else null
        val username = auth?.getString("username")
        val token = auth?.getString("token")
        val allowInsecure = params.hasKey("allowInsecure") && params.getBoolean("allowInsecure")

        nativePush(uriToFilePath(localRepoDirUri), remote, branch, username, token, allowInsecure)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("E_GIT_PUSH", e.message, e)
      }
    }
  }

  @ReactMethod
  fun status(params: ReadableMap, promise: Promise) {
    ioExecutor.execute {
      try {
        val localRepoDirUri =
          params.getString("localRepoDirUri") ?: throw IllegalArgumentException("localRepoDirUri is required")
        val res = nativeStatus(uriToFilePath(localRepoDirUri))
        promise.resolve(res)
      } catch (e: Throwable) {
        promise.reject("E_GIT_STATUS", e.message, e)
      }
    }
  }

  @ReactMethod
  fun diff(params: ReadableMap, promise: Promise) {
    ioExecutor.execute {
      try {
        val localRepoDirUri =
          params.getString("localRepoDirUri") ?: throw IllegalArgumentException("localRepoDirUri is required")
        val maxBytes = if (params.hasKey("maxBytes") && !params.isNull("maxBytes")) params.getInt("maxBytes") else 400000
        val res = nativeDiff(uriToFilePath(localRepoDirUri), maxBytes)
        promise.resolve(res)
      } catch (e: Throwable) {
        promise.reject("E_GIT_DIFF", e.message, e)
      }
    }
  }
}
