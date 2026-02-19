#include <jni.h>

#include "git_ops.h"

#include <string>

static std::string jstring_to_string(JNIEnv *env, jstring s) {
  if (!s) return "";
  const char *chars = env->GetStringUTFChars(s, nullptr);
  std::string out(chars ? chars : "");
  if (chars) env->ReleaseStringUTFChars(s, chars);
  return out;
}

static void throw_java_runtime(JNIEnv *env, const std::string &msg) {
  jclass exClass = env->FindClass("java/lang/RuntimeException");
  if (exClass) env->ThrowNew(exClass, msg.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeClone(JNIEnv *env,
                                                   jobject /*thiz*/,
                                                   jstring remoteUrl,
                                                   jstring localPath,
                                                   jstring branch,
                                                   jstring username,
                                                   jstring token,
                                                   jstring userName,
                                                   jstring userEmail,
                                                   jboolean allowInsecure) {
  try {
    GitCloneOptions opts;
    opts.remoteUrl = jstring_to_string(env, remoteUrl);
    opts.localPath = jstring_to_string(env, localPath);
    opts.branch = jstring_to_string(env, branch);
    opts.username = jstring_to_string(env, username);
    opts.token = jstring_to_string(env, token);
    opts.userName = jstring_to_string(env, userName);
    opts.userEmail = jstring_to_string(env, userEmail);
    opts.allowInsecure = allowInsecure == JNI_TRUE;
    git_clone_repo(opts);
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeCheckout(JNIEnv *env,
                                                      jobject /*thiz*/,
                                                      jstring localPath,
                                                      jstring ref) {
  try {
    GitCheckoutOptions opts;
    opts.localPath = jstring_to_string(env, localPath);
    opts.ref = jstring_to_string(env, ref);
    git_checkout_ref(opts);
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativePull(JNIEnv *env,
                                                  jobject /*thiz*/,
                                                  jstring localPath,
                                                  jstring remote,
                                                  jstring branch,
                                                  jstring username,
                                                  jstring token,
                                                  jboolean allowInsecure) {
  try {
    GitPullOptions opts;
    opts.localPath = jstring_to_string(env, localPath);
    opts.remote = jstring_to_string(env, remote);
    opts.branch = jstring_to_string(env, branch);
    opts.username = jstring_to_string(env, username);
    opts.token = jstring_to_string(env, token);
    opts.allowInsecure = allowInsecure == JNI_TRUE;
    git_pull_ff_only(opts);
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativePush(JNIEnv *env,
                                                  jobject /*thiz*/,
                                                  jstring localPath,
                                                  jstring remote,
                                                  jstring branch,
                                                  jstring username,
                                                  jstring token,
                                                  jboolean allowInsecure) {
  try {
    GitPushOptions opts;
    opts.localPath = jstring_to_string(env, localPath);
    opts.remote = jstring_to_string(env, remote);
    opts.branch = jstring_to_string(env, branch);
    opts.username = jstring_to_string(env, username);
    opts.token = jstring_to_string(env, token);
    opts.allowInsecure = allowInsecure == JNI_TRUE;
    git_push_branch(opts);
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeStatus(JNIEnv *env,
                                                    jobject /*thiz*/,
                                                    jstring localPath) {
  try {
    const auto st = git_status(jstring_to_string(env, localPath));

    jclass arguments = env->FindClass("com/facebook/react/bridge/Arguments");
    jmethodID createMap =
      env->GetStaticMethodID(arguments, "createMap", "()Lcom/facebook/react/bridge/WritableMap;");
    jmethodID createArray =
      env->GetStaticMethodID(arguments, "createArray", "()Lcom/facebook/react/bridge/WritableArray;");

    jobject map = env->CallStaticObjectMethod(arguments, createMap);
    jclass mapClass = env->GetObjectClass(map);
    jmethodID putArray =
      env->GetMethodID(mapClass, "putArray", "(Ljava/lang/String;Lcom/facebook/react/bridge/ReadableArray;)V");

    auto buildArray = [&](const std::vector<std::string> &items) -> jobject {
      jobject arr = env->CallStaticObjectMethod(arguments, createArray);
      jclass arrClass = env->GetObjectClass(arr);
      jmethodID pushString = env->GetMethodID(arrClass, "pushString", "(Ljava/lang/String;)V");
      for (const auto &s : items) {
        jstring js = env->NewStringUTF(s.c_str());
        env->CallVoidMethod(arr, pushString, js);
        env->DeleteLocalRef(js);
      }
      env->DeleteLocalRef(arrClass);
      return arr;
    };

    jobject staged = buildArray(st.staged);
    jobject unstaged = buildArray(st.unstaged);
    jobject untracked = buildArray(st.untracked);

    jstring kStaged = env->NewStringUTF("staged");
    jstring kUnstaged = env->NewStringUTF("unstaged");
    jstring kUntracked = env->NewStringUTF("untracked");

    env->CallVoidMethod(map, putArray, kStaged, staged);
    env->CallVoidMethod(map, putArray, kUnstaged, unstaged);
    env->CallVoidMethod(map, putArray, kUntracked, untracked);

    env->DeleteLocalRef(kStaged);
    env->DeleteLocalRef(kUnstaged);
    env->DeleteLocalRef(kUntracked);
    env->DeleteLocalRef(staged);
    env->DeleteLocalRef(unstaged);
    env->DeleteLocalRef(untracked);
    env->DeleteLocalRef(mapClass);
    env->DeleteLocalRef(arguments);

    return map;
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}
