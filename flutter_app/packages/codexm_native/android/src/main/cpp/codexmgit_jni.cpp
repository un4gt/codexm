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

static jobject new_map(JNIEnv *env) {
  jclass cls = env->FindClass("java/util/HashMap");
  jmethodID init = env->GetMethodID(cls, "<init>", "()V");
  jobject map = env->NewObject(cls, init);
  env->DeleteLocalRef(cls);
  return map;
}

static void map_put(JNIEnv *env, jobject map, const char *key, jobject value) {
  jclass cls = env->FindClass("java/util/HashMap");
  jmethodID put = env->GetMethodID(
      cls, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  jstring jkey = env->NewStringUTF(key);
  env->CallObjectMethod(map, put, jkey, value);
  env->DeleteLocalRef(jkey);
  env->DeleteLocalRef(cls);
}

static void map_put_string(JNIEnv *env, jobject map, const char *key,
                           const std::string &value) {
  jstring jvalue = env->NewStringUTF(value.c_str());
  map_put(env, map, key, jvalue);
  env->DeleteLocalRef(jvalue);
}

static void map_put_bool(JNIEnv *env, jobject map, const char *key, bool value) {
  jclass cls = env->FindClass("java/lang/Boolean");
  jmethodID value_of = env->GetStaticMethodID(
      cls, "valueOf", "(Z)Ljava/lang/Boolean;");
  jobject boxed = env->CallStaticObjectMethod(cls, value_of,
                                               value ? JNI_TRUE : JNI_FALSE);
  map_put(env, map, key, boxed);
  env->DeleteLocalRef(boxed);
  env->DeleteLocalRef(cls);
}

static jobject string_list(JNIEnv *env, const std::vector<std::string> &items) {
  jclass cls = env->FindClass("java/util/ArrayList");
  jmethodID init = env->GetMethodID(cls, "<init>", "()V");
  jmethodID add = env->GetMethodID(cls, "add", "(Ljava/lang/Object;)Z");
  jobject list = env->NewObject(cls, init);
  for (const auto &item : items) {
    jstring value = env->NewStringUTF(item.c_str());
    env->CallBooleanMethod(list, add, value);
    env->DeleteLocalRef(value);
  }
  env->DeleteLocalRef(cls);
  return list;
}

static jobject repository_info_map(JNIEnv *env, const GitRepositoryInfo &info) {
  jobject map = new_map(env);
  map_put_string(env, map, "branch", info.branch);
  map_put_string(env, map, "headOid", info.headOid);
  map_put_bool(env, map, "isClean", info.isClean);
  map_put_bool(env, map, "isMerging", info.isMerging);
  return map;
}

static jobject worktree_info_map(JNIEnv *env, const GitWorktreeInfo &info) {
  jobject map = new_map(env);
  map_put_string(env, map, "name", info.name);
  map_put_string(env, map, "path", info.path);
  map_put_bool(env, map, "valid", info.valid);
  map_put_bool(env, map, "locked", info.locked);
  return map;
}

static jobject commit_result_map(JNIEnv *env, const GitCommitResult &result) {
  jobject map = new_map(env);
  map_put_string(env, map, "oid", result.oid);
  map_put_bool(env, map, "created", result.created);
  return map;
}

static jobject merge_result_map(JNIEnv *env, const GitMergeResult &result) {
  jobject map = new_map(env);
  map_put_string(env, map, "outcome", result.outcome);
  map_put_string(env, map, "headOid", result.headOid);
  jobject conflicts = string_list(env, result.conflictPaths);
  map_put(env, map, "conflictPaths", conflicts);
  env->DeleteLocalRef(conflicts);
  return map;
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
    jobject conflicted = buildArray(st.conflicted);

    jstring kStaged = env->NewStringUTF("staged");
    jstring kUnstaged = env->NewStringUTF("unstaged");
    jstring kUntracked = env->NewStringUTF("untracked");
    jstring kConflicted = env->NewStringUTF("conflicted");

    env->CallObjectMethod(map, mapPut, kStaged, staged);
    env->CallObjectMethod(map, mapPut, kUnstaged, unstaged);
    env->CallObjectMethod(map, mapPut, kUntracked, untracked);
    env->CallObjectMethod(map, mapPut, kConflicted, conflicted);

    env->DeleteLocalRef(kStaged);
    env->DeleteLocalRef(kUnstaged);
    env->DeleteLocalRef(kUntracked);
    env->DeleteLocalRef(kConflicted);
    env->DeleteLocalRef(staged);
    env->DeleteLocalRef(unstaged);
    env->DeleteLocalRef(untracked);
    env->DeleteLocalRef(conflicted);
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

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeInitRepository(
    JNIEnv *env, jobject /*thiz*/, jstring localPath, jstring initialBranch) {
  try {
    return repository_info_map(
        env, git_init_repository(jstring_to_string(env, localPath),
                                 jstring_to_string(env, initialBranch)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeRepositoryInfo(
    JNIEnv *env, jobject /*thiz*/, jstring localPath) {
  try {
    return repository_info_map(
        env, git_repository_info(jstring_to_string(env, localPath)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeCreateWorktree(
    JNIEnv *env, jobject /*thiz*/, jstring mainRepoPath,
    jstring worktreePath, jstring name, jstring branchName, jstring startRef) {
  try {
    return worktree_info_map(
        env, git_create_worktree(jstring_to_string(env, mainRepoPath),
                                 jstring_to_string(env, worktreePath),
                                 jstring_to_string(env, name),
                                 jstring_to_string(env, branchName),
                                 jstring_to_string(env, startRef)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeListWorktrees(
    JNIEnv *env, jobject /*thiz*/, jstring mainRepoPath) {
  try {
    const auto worktrees =
        git_list_worktrees(jstring_to_string(env, mainRepoPath));
    jclass cls = env->FindClass("java/util/ArrayList");
    jmethodID init = env->GetMethodID(cls, "<init>", "()V");
    jmethodID add = env->GetMethodID(cls, "add", "(Ljava/lang/Object;)Z");
    jobject list = env->NewObject(cls, init);
    for (const auto &worktree : worktrees) {
      jobject map = worktree_info_map(env, worktree);
      env->CallBooleanMethod(list, add, map);
      env->DeleteLocalRef(map);
    }
    env->DeleteLocalRef(cls);
    return list;
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeRemoveWorktree(
    JNIEnv *env, jobject /*thiz*/, jstring mainRepoPath, jstring name,
    jboolean force) {
  try {
    git_remove_worktree(jstring_to_string(env, mainRepoPath),
                        jstring_to_string(env, name), force == JNI_TRUE);
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeCreateCheckpoint(
    JNIEnv *env, jobject /*thiz*/, jstring localPath, jstring message,
    jstring userName, jstring userEmail) {
  try {
    return commit_result_map(
        env, git_create_checkpoint(jstring_to_string(env, localPath),
                                   jstring_to_string(env, message),
                                   jstring_to_string(env, userName),
                                   jstring_to_string(env, userEmail)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeIsAncestor(
    JNIEnv *env, jobject /*thiz*/, jstring localPath, jstring ancestorRef,
    jstring descendantRef) {
  try {
    return git_is_ancestor(jstring_to_string(env, localPath),
                           jstring_to_string(env, ancestorRef),
                           jstring_to_string(env, descendantRef))
               ? JNI_TRUE
               : JNI_FALSE;
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return JNI_FALSE;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeDeleteBranch(
    JNIEnv *env, jobject /*thiz*/, jstring localPath, jstring branchName,
    jboolean force) {
  try {
    git_delete_branch(jstring_to_string(env, localPath),
                      jstring_to_string(env, branchName), force == JNI_TRUE);
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeMerge(
    JNIEnv *env, jobject /*thiz*/, jstring targetPath, jstring sourceRef,
    jstring message, jstring userName, jstring userEmail) {
  try {
    return merge_result_map(
        env, git_merge_ref(jstring_to_string(env, targetPath),
                           jstring_to_string(env, sourceRef),
                           jstring_to_string(env, message),
                           jstring_to_string(env, userName),
                           jstring_to_string(env, userEmail)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeMergeState(
    JNIEnv *env, jobject /*thiz*/, jstring targetPath) {
  try {
    return merge_result_map(
        env, git_merge_state(jstring_to_string(env, targetPath)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeContinueMerge(
    JNIEnv *env, jobject /*thiz*/, jstring targetPath, jstring message,
    jstring userName, jstring userEmail) {
  try {
    return merge_result_map(
        env, git_continue_merge(jstring_to_string(env, targetPath),
                                jstring_to_string(env, message),
                                jstring_to_string(env, userName),
                                jstring_to_string(env, userEmail)));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
    return nullptr;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_codexm_nativemodules_CodexMGitModule_nativeAbortMerge(
    JNIEnv *env, jobject /*thiz*/, jstring targetPath) {
  try {
    git_abort_merge(jstring_to_string(env, targetPath));
  } catch (const GitException &e) {
    throw_java_runtime(env, e.what());
  }
}
