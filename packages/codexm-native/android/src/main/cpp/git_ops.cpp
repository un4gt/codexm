#include "git_ops.h"

#include <git2.h>

#include <sys/stat.h>

#include <mutex>
#include <string>
#include <vector>

namespace {
std::once_flag g_libgit2_once;

bool dir_exists(const char *path) {
  struct stat st;
  return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

void ensure_libgit2() {
  std::call_once(g_libgit2_once, []() {
    git_libgit2_init();

    // Best-effort: point to Android system CA certs directory so HTTPS verification works.
    const char *ca_dir = nullptr;
    if (dir_exists("/apex/com.android.conscrypt/cacerts")) {
      ca_dir = "/apex/com.android.conscrypt/cacerts";
    } else if (dir_exists("/system/etc/security/cacerts")) {
      ca_dir = "/system/etc/security/cacerts";
    }
    if (ca_dir) {
      git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, nullptr, ca_dir);
    }
  });
}

struct CredPayload {
  std::string username;
  std::string token;
  bool hasCreds = false;
  bool allowInsecure = false;
};

int credentials_cb(git_credential **out,
                   const char * /*url*/,
                   const char * /*username_from_url*/,
                   unsigned int allowed_types,
                   void *payload) {
  auto *p = reinterpret_cast<CredPayload *>(payload);
  if (!p || !p->hasCreds) return 0;
  if ((allowed_types & GIT_CREDENTIAL_USERPASS_PLAINTEXT) == 0) return 0;
  return git_credential_userpass_plaintext_new(out, p->username.c_str(), p->token.c_str());
}

int cert_check_cb(git_cert * /*cert*/, int valid, const char * /*host*/, void *payload) {
  auto *p = reinterpret_cast<CredPayload *>(payload);
  if (p && p->allowInsecure) return 0;
  return valid ? 0 : -1;
}

std::string last_error_message(int fallback_code) {
  const git_error *e = git_error_last();
  if (e && e->message) return std::string(e->message);
  return "libgit2 error code " + std::to_string(fallback_code);
}

void fetch_remote(git_repository *repo, const std::string &remoteName, CredPayload &payload) {
  git_remote *remote = nullptr;
  int rc = git_remote_lookup(&remote, repo, remoteName.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_fetch_options fetch_opts = GIT_FETCH_OPTIONS_INIT;
  git_remote_callbacks callbacks = GIT_REMOTE_CALLBACKS_INIT;
  callbacks.credentials = credentials_cb;
  callbacks.certificate_check = cert_check_cb;
  callbacks.payload = &payload;
  fetch_opts.callbacks = callbacks;

  rc = git_remote_fetch(remote, nullptr, &fetch_opts, nullptr);
  git_remote_free(remote);
  if (rc != 0) throw GitException(last_error_message(rc));
}
}  // namespace

void git_clone_repo(const GitCloneOptions &opts) {
  ensure_libgit2();

  git_repository *repo = nullptr;

  git_clone_options clone_opts = GIT_CLONE_OPTIONS_INIT;
  git_fetch_options fetch_opts = GIT_FETCH_OPTIONS_INIT;
  git_remote_callbacks callbacks = GIT_REMOTE_CALLBACKS_INIT;

  CredPayload payload;
  payload.allowInsecure = opts.allowInsecure;
  if (!opts.username.empty() && !opts.token.empty()) {
    payload.username = opts.username;
    payload.token = opts.token;
    payload.hasCreds = true;
  }

  callbacks.credentials = credentials_cb;
  callbacks.certificate_check = cert_check_cb;
  callbacks.payload = &payload;

  fetch_opts.callbacks = callbacks;
  clone_opts.fetch_opts = fetch_opts;

  if (!opts.branch.empty()) {
    clone_opts.checkout_branch = opts.branch.c_str();
  }

  int rc = git_clone(&repo, opts.remoteUrl.c_str(), opts.localPath.c_str(), &clone_opts);
  if (rc != 0) {
    throw GitException(last_error_message(rc));
  }

  if (repo && (!opts.userName.empty() || !opts.userEmail.empty())) {
    git_config *cfg = nullptr;
    if (git_repository_config(&cfg, repo) == 0 && cfg) {
      if (!opts.userName.empty()) {
        git_config_set_string(cfg, "user.name", opts.userName.c_str());
      }
      if (!opts.userEmail.empty()) {
        git_config_set_string(cfg, "user.email", opts.userEmail.c_str());
      }
      git_config_free(cfg);
    }
  }

  git_repository_free(repo);
}

void git_checkout_ref(const GitCheckoutOptions &opts) {
  ensure_libgit2();

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, opts.localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_object *obj = nullptr;
  rc = git_revparse_single(&obj, repo, opts.ref.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_checkout_options co = GIT_CHECKOUT_OPTIONS_INIT;
  co.checkout_strategy = GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;
  rc = git_checkout_tree(repo, obj, &co);
  if (rc != 0) {
    git_object_free(obj);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  rc = git_repository_set_head_detached(repo, git_object_id(obj));
  if (rc != 0) {
    git_object_free(obj);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_object_free(obj);
  git_repository_free(repo);
}

void git_pull_ff_only(const GitPullOptions &opts) {
  ensure_libgit2();

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, opts.localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  CredPayload payload;
  payload.allowInsecure = opts.allowInsecure;
  if (!opts.username.empty() && !opts.token.empty()) {
    payload.username = opts.username;
    payload.token = opts.token;
    payload.hasCreds = true;
  }

  const std::string remoteName = opts.remote.empty() ? "origin" : opts.remote;
  fetch_remote(repo, remoteName, payload);

  std::string branchName = opts.branch;
  if (branchName.empty()) {
    git_reference *head = nullptr;
    rc = git_repository_head(&head, repo);
    if (rc == 0) {
      branchName = git_reference_shorthand(head);
      git_reference_free(head);
    }
  }
  if (branchName.empty()) {
    git_repository_free(repo);
    throw GitException("Unable to determine current branch for pull");
  }

  const std::string remoteRefName = "refs/remotes/" + remoteName + "/" + branchName;
  git_reference *remote_ref = nullptr;
  rc = git_reference_lookup(&remote_ref, repo, remoteRefName.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_annotated_commit *their_head = nullptr;
  rc = git_annotated_commit_from_ref(&their_head, repo, remote_ref);
  const git_oid *target_oid = git_reference_target(remote_ref);
  git_reference_free(remote_ref);
  if (rc != 0 || !target_oid) {
    if (their_head) git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc != 0 ? rc : -1));
  }

  git_merge_analysis_t analysis;
  git_merge_preference_t pref;
  const git_annotated_commit *heads[] = {their_head};
  rc = git_merge_analysis(&analysis, &pref, repo, heads, 1);
  if (rc != 0) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  if (analysis & GIT_MERGE_ANALYSIS_UP_TO_DATE) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    return;
  }

  if (!(analysis & GIT_MERGE_ANALYSIS_FASTFORWARD)) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException("Non fast-forward pull not supported in Phase A");
  }

  const std::string localRefName = "refs/heads/" + branchName;
  git_reference *local_ref = nullptr;
  rc = git_reference_lookup(&local_ref, repo, localRefName.c_str());
  if (rc != 0) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_reference *new_ref = nullptr;
  rc = git_reference_set_target(&new_ref, local_ref, target_oid, "fast-forward");
  git_reference_free(local_ref);
  if (new_ref) git_reference_free(new_ref);
  if (rc != 0) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_object *target_obj = nullptr;
  rc = git_object_lookup(&target_obj, repo, target_oid, GIT_OBJECT_COMMIT);
  if (rc != 0) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_checkout_options co = GIT_CHECKOUT_OPTIONS_INIT;
  co.checkout_strategy = GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;
  rc = git_checkout_tree(repo, target_obj, &co);
  git_object_free(target_obj);
  if (rc != 0) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  rc = git_repository_set_head(repo, localRefName.c_str());
  if (rc != 0) {
    git_annotated_commit_free(their_head);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_annotated_commit_free(their_head);
  git_repository_free(repo);
}

void git_push_branch(const GitPushOptions &opts) {
  ensure_libgit2();

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, opts.localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  CredPayload payload;
  payload.allowInsecure = opts.allowInsecure;
  if (!opts.username.empty() && !opts.token.empty()) {
    payload.username = opts.username;
    payload.token = opts.token;
    payload.hasCreds = true;
  }

  const std::string remoteName = opts.remote.empty() ? "origin" : opts.remote;
  git_remote *remote = nullptr;
  rc = git_remote_lookup(&remote, repo, remoteName.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  std::string branchName = opts.branch;
  if (branchName.empty()) {
    git_reference *head = nullptr;
    rc = git_repository_head(&head, repo);
    if (rc == 0) {
      branchName = git_reference_shorthand(head);
      git_reference_free(head);
    }
  }
  if (branchName.empty()) {
    git_remote_free(remote);
    git_repository_free(repo);
    throw GitException("Unable to determine current branch for push");
  }

  const std::string refspec = "refs/heads/" + branchName + ":refs/heads/" + branchName;
  const char *specs[] = {refspec.c_str()};
  git_strarray refspecs;
  refspecs.count = 1;
  refspecs.strings = const_cast<char **>(specs);

  git_push_options push_opts = GIT_PUSH_OPTIONS_INIT;
  git_remote_callbacks callbacks = GIT_REMOTE_CALLBACKS_INIT;
  callbacks.credentials = credentials_cb;
  callbacks.certificate_check = cert_check_cb;
  callbacks.payload = &payload;
  push_opts.callbacks = callbacks;

  rc = git_remote_push(remote, &refspecs, &push_opts);
  git_remote_free(remote);
  git_repository_free(repo);
  if (rc != 0) throw GitException(last_error_message(rc));
}

GitStatus git_status(const std::string &localPath) {
  ensure_libgit2();

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_status_options opts = GIT_STATUS_OPTIONS_INIT;
  opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;
  opts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX;

  git_status_list *status = nullptr;
  rc = git_status_list_new(&status, repo, &opts);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  GitStatus out;
  const size_t count = git_status_list_entrycount(status);
  for (size_t i = 0; i < count; i++) {
    const git_status_entry *s = git_status_byindex(status, i);
    if (!s) continue;

    const char *path = nullptr;
    if (s->head_to_index && s->head_to_index->new_file.path) path = s->head_to_index->new_file.path;
    else if (s->index_to_workdir && s->index_to_workdir->new_file.path) path = s->index_to_workdir->new_file.path;
    if (!path) continue;

    const unsigned int st = s->status;
    const std::string p(path);

    if (st & (GIT_STATUS_INDEX_NEW | GIT_STATUS_INDEX_MODIFIED | GIT_STATUS_INDEX_DELETED |
              GIT_STATUS_INDEX_RENAMED | GIT_STATUS_INDEX_TYPECHANGE)) {
      out.staged.push_back(p);
    }
    if (st & (GIT_STATUS_WT_MODIFIED | GIT_STATUS_WT_DELETED | GIT_STATUS_WT_RENAMED |
              GIT_STATUS_WT_TYPECHANGE)) {
      out.unstaged.push_back(p);
    }
    if (st & GIT_STATUS_WT_NEW) {
      out.untracked.push_back(p);
    }
  }

  git_status_list_free(status);
  git_repository_free(repo);
  return out;
}

struct DiffBuffer {
  std::string out;
  size_t maxBytes = 0;
  bool truncated = false;
};

static int diff_print_cb(const git_diff_delta * /*delta*/,
                         const git_diff_hunk * /*hunk*/,
                         const git_diff_line *line,
                         void *payload) {
  auto *buf = static_cast<DiffBuffer *>(payload);
  if (!buf || !line) return 0;
  if (buf->maxBytes > 0 && buf->out.size() >= buf->maxBytes) {
    buf->truncated = true;
    return GIT_EUSER;
  }

  // `git_diff_print(..., GIT_DIFF_FORMAT_PATCH, ...)` provides the line type via `origin` but
  // does not include the unified-diff prefix in `content` for ordinary lines. Add it so the
  // output can be parsed/applied and remains readable.
  if (line->origin == '+' || line->origin == '-' || line->origin == ' ') {
    buf->out.push_back(line->origin);
  }

  const size_t want = static_cast<size_t>(line->content_len);
  const size_t remaining = buf->maxBytes > 0 ? (buf->maxBytes - buf->out.size()) : want;
  const size_t n = want > remaining ? remaining : want;

  if (n > 0) buf->out.append(line->content, n);
  if (buf->maxBytes > 0 && n < want) {
    buf->truncated = true;
    return GIT_EUSER;
  }
  return 0;
}

static void append_section_header(DiffBuffer &buf, const std::string &title) {
  buf.out.append(title);
  if (!title.empty() && title.back() != '\n') buf.out.push_back('\n');
}

static void print_diff(DiffBuffer &buf, git_diff *diff) {
  if (!diff) return;
  const size_t deltas = git_diff_num_deltas(diff);
  if (deltas == 0) {
    buf.out.append("（无变更）\n");
    return;
  }

  const int rc = git_diff_print(diff, GIT_DIFF_FORMAT_PATCH, diff_print_cb, &buf);
  if (rc == GIT_EUSER && buf.truncated) {
    buf.out.append("\n…（diff 已截断）\n");
    return;
  }
  if (rc != 0) throw GitException(last_error_message(rc));
}

std::string git_diff_unified(const std::string &localPath, size_t maxBytes) {
  ensure_libgit2();

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_index *index = nullptr;
  rc = git_repository_index(&index, repo);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_tree *headTree = nullptr;
  git_reference *headRef = nullptr;
  rc = git_repository_head(&headRef, repo);
  if (rc == 0) {
    git_object *headObj = nullptr;
    rc = git_reference_peel(&headObj, headRef, GIT_OBJECT_COMMIT);
    if (rc != 0) {
      git_reference_free(headRef);
      git_index_free(index);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }
    rc = git_commit_tree(&headTree, reinterpret_cast<git_commit *>(headObj));
    git_object_free(headObj);
    git_reference_free(headRef);
    if (rc != 0) {
      git_index_free(index);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }
  } else if (rc == GIT_ENOTFOUND || rc == GIT_EUNBORNBRANCH) {
    // Repo has no commits yet; treat HEAD tree as empty.
  } else {
    git_index_free(index);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  DiffBuffer buf;
  buf.maxBytes = maxBytes;

  git_diff *diffStaged = nullptr;
  git_diff_options stagedOpts = GIT_DIFF_OPTIONS_INIT;
  rc = git_diff_tree_to_index(&diffStaged, repo, headTree, index, &stagedOpts);
  if (rc != 0) {
    if (headTree) git_tree_free(headTree);
    git_index_free(index);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_diff *diffWorkdir = nullptr;
  git_diff_options workOpts = GIT_DIFF_OPTIONS_INIT;
  workOpts.flags = GIT_DIFF_INCLUDE_UNTRACKED | GIT_DIFF_RECURSE_UNTRACKED_DIRS |
                   GIT_DIFF_SHOW_UNTRACKED_CONTENT;
  rc = git_diff_index_to_workdir(&diffWorkdir, repo, index, &workOpts);
  if (rc != 0) {
    git_diff_free(diffStaged);
    if (headTree) git_tree_free(headTree);
    git_index_free(index);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  append_section_header(buf, "# Staged (HEAD..INDEX)");
  print_diff(buf, diffStaged);
  buf.out.push_back('\n');
  append_section_header(buf, "# Workdir (INDEX..WORKDIR, include untracked)");
  print_diff(buf, diffWorkdir);

  git_diff_free(diffWorkdir);
  git_diff_free(diffStaged);
  if (headTree) git_tree_free(headTree);
  git_index_free(index);
  git_repository_free(repo);

  if (buf.out.empty()) return "（无变更）\n";
  return buf.out;
}
