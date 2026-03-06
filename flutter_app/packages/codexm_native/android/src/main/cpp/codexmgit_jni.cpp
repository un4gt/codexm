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

    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID mapInit = env->GetMethodID(mapClass, "<init>", "()V");
    jmethodID mapPut =
      env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

    jclass listClass = env->FindClass("java/util/ArrayList");
    jmethodID listInit = env->GetMethodID(listClass, "<init>", "()V");
    jmethodID listAdd =
      env->GetMethodID(listClass, "add", "(Ljava/lang/Object;)Z");

    auto buildArray = [&](const std::vector<std::string> &items) -> jobject {
      jobject arr = env->NewObject(listClass, listInit);
      for (const auto &s : items) {
        jstring js = env->NewStringUTF(s.c_str());
        env->CallBooleanMethod(arr, listAdd, js);
        env->DeleteLocalRef(js);
      }
      return arr;
    };

    jobject map = env->NewObject(mapClass, mapInit);
    jobject staged = buildArray(st.staged);
    jobject unstaged = buildArray(st.unstaged);
    jobject untracked = buildArray(st.untracked);

    jstring kStaged = env->NewStringUTF("staged");
    jstring kUnstaged = env->NewStringUTF("unstaged");
    jstring kUntracked = env->NewStringUTF("untracked");

    env->CallObjectMethod(map, mapPut, kStaged, staged);
    env->CallObjectMethod(map, mapPut, kUnstaged, unstaged);
    env->CallObjectMethod(map, mapPut, kUntracked, untracked);

    env->DeleteLocalRef(kStaged);
    env->DeleteLocalRef(kUnstaged);
    env->DeleteLocalRef(kUntracked);
    env->DeleteLocalRef(staged);
    env->DeleteLocalRef(unstaged);
    env->DeleteLocalRef(untracked);
    env->DeleteLocalRef(mapClass);
    env->DeleteLocalRef(listClass);

    return map;
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeDiff(JNIEnv *env,
                                                   jobject /*thiz*/,
                                                   jstring localPath,
                                                   jint maxBytes) {
  try {
    const auto diff = git_diff_unified(jstring_to_string(env, localPath), static_cast<size_t>(maxBytes));
    return env->NewStringUTF(diff.c_str());
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeRecentCommits(JNIEnv *env,
                                                            jobject /*thiz*/,
                                                            jstring localPath,
                                                            jint limit) {
  try {
    const auto commits = git_recent_commits(
      jstring_to_string(env, localPath),
      static_cast<size_t>(limit < 0 ? 0 : limit)
    );

    jclass listClass = env->FindClass("java/util/ArrayList");
    jmethodID listInit = env->GetMethodID(listClass, "<init>", "()V");
    jmethodID listAdd =
      env->GetMethodID(listClass, "add", "(Ljava/lang/Object;)Z");

    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID mapInit = env->GetMethodID(mapClass, "<init>", "()V");
    jmethodID mapPut =
      env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

    jobject out = env->NewObject(listClass, listInit);
    for (const auto &commit : commits) {
      jobject map = env->NewObject(mapClass, mapInit);

      auto put_string = [&](const char *key, const std::string &value) {
        jstring jKey = env->NewStringUTF(key);
        jstring jValue = env->NewStringUTF(value.c_str());
        env->CallObjectMethod(map, mapPut, jKey, jValue);
        env->DeleteLocalRef(jKey);
        env->DeleteLocalRef(jValue);
      };

      put_string("hash", commit.hash);
      put_string("shortHash", commit.shortHash);
      put_string("title", commit.title);
      put_string("authorName", commit.authorName);

      jstring committedAtKey = env->NewStringUTF("committedAt");
      jclass longClass = env->FindClass("java/lang/Long");
      jmethodID longInit = env->GetMethodID(longClass, "<init>", "(J)V");
      jobject committedAtValue =
        env->NewObject(longClass, longInit, static_cast<jlong>(commit.committedAt));
      env->CallObjectMethod(map, mapPut, committedAtKey, committedAtValue);
      env->DeleteLocalRef(committedAtKey);
      env->DeleteLocalRef(committedAtValue);
      env->DeleteLocalRef(longClass);

      env->CallBooleanMethod(out, listAdd, map);
      env->DeleteLocalRef(map);
    }

    env->DeleteLocalRef(mapClass);
    env->DeleteLocalRef(listClass);
    return out;
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeShowCommit(JNIEnv *env,
                                                         jobject /*thiz*/,
                                                         jstring localPath,
                                                         jstring hash,
                                                         jint maxBytes) {
  try {
    const auto patch = git_show_commit(
      jstring_to_string(env, localPath),
      jstring_to_string(env, hash),
      static_cast<size_t>(maxBytes)
    );
    return env->NewStringUTF(patch.c_str());
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}
