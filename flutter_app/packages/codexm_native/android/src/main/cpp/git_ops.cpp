#include "git_ops.h"

#include <git2.h>

#include <sys/stat.h>

#include <dirent.h>

#include <mutex>
#include <string>
#include <vector>

namespace {
std::once_flag g_libgit2_once;

bool dir_exists(const char *path) {
  struct stat st;
  return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

bool directory_empty(const char *path) {
  DIR *dir = opendir(path);
  if (!dir) return false;
  bool empty = true;
  while (const dirent *entry = readdir(dir)) {
    const std::string name = entry->d_name;
    if (name != "." && name != "..") {
      empty = false;
      break;
    }
  }
  closedir(dir);
  return empty;
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

std::string fallback_username(const char *username_from_url) {
  if (username_from_url && username_from_url[0] != '\0') {
    return std::string(username_from_url);
  }
  return "git";
}

int credentials_cb(git_credential **out,
                   const char * /*url*/,
                   const char *username_from_url,
                   unsigned int allowed_types,
                   void *payload) {
  auto *p = reinterpret_cast<CredPayload *>(payload);
  if (!p || !p->hasCreds) return 0;
  const std::string username =
      p->username.empty() ? fallback_username(username_from_url) : p->username;

  if ((allowed_types & GIT_CREDENTIAL_USERNAME) != 0 &&
      (allowed_types & GIT_CREDENTIAL_USERPASS_PLAINTEXT) == 0) {
    return git_credential_username_new(out, username.c_str());
  }

  if ((allowed_types & GIT_CREDENTIAL_USERPASS_PLAINTEXT) != 0) {
    return git_credential_userpass_plaintext_new(out, username.c_str(), p->token.c_str());
  }

  return 0;
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
  if (!opts.token.empty()) {
    payload.username = opts.username;
    payload.token = opts.token;
    payload.hasCreds = true;
  }

  callbacks.credentials = credentials_cb;
  callbacks.certificate_check = cert_check_cb;
  callbacks.payload = &payload;

  fetch_opts.callbacks = callbacks;
  clone_opts.fetch_opts = fetch_opts;
  clone_opts.checkout_opts.checkout_strategy =
      GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;

  if (!opts.branch.empty()) {
    clone_opts.checkout_branch = opts.branch.c_str();
  }

  if (dir_exists(opts.localPath.c_str()) && !directory_empty(opts.localPath.c_str())) {
    throw GitException("destination path already exists and is not an empty directory");
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
  if (!opts.token.empty()) {
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
  if (!opts.token.empty()) {
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

    if (st & GIT_STATUS_CONFLICTED) {
      out.conflicted.push_back(p);
      continue;
    }

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

static void append_text(DiffBuffer &buf, const std::string &text) {
  if (text.empty()) return;
  if (buf.maxBytes > 0 && buf.out.size() >= buf.maxBytes) {
    buf.truncated = true;
    return;
  }
  const size_t remaining = buf.maxBytes > 0 ? (buf.maxBytes - buf.out.size()) : text.size();
  const size_t n = text.size() > remaining ? remaining : text.size();
  if (n > 0) {
    buf.out.append(text, 0, n);
  }
  if (buf.maxBytes > 0 && n < text.size()) {
    buf.truncated = true;
  }
}

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
  append_text(buf, title);
  if (!title.empty() && title.back() != '\n') append_text(buf, "\n");
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

std::vector<GitCommitSummary> git_recent_commits(const std::string &localPath,
                                                 size_t limit) {
  ensure_libgit2();

  if (limit == 0) {
    return {};
  }

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_revwalk *walk = nullptr;
  rc = git_revwalk_new(&walk, repo);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_revwalk_sorting(walk, GIT_SORT_TIME | GIT_SORT_TOPOLOGICAL);
  rc = git_revwalk_push_head(walk);
  if (rc == GIT_EUNBORNBRANCH || rc == GIT_ENOTFOUND) {
    git_revwalk_free(walk);
    git_repository_free(repo);
    return {};
  }
  if (rc != 0) {
    git_revwalk_free(walk);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  std::vector<GitCommitSummary> out;
  git_oid oid;
  while (out.size() < limit) {
    rc = git_revwalk_next(&oid, walk);
    if (rc == GIT_ITEROVER) {
      break;
    }
    if (rc != 0) {
      git_revwalk_free(walk);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }

    git_commit *commit = nullptr;
    rc = git_commit_lookup(&commit, repo, &oid);
    if (rc != 0) {
      git_revwalk_free(walk);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }

    char oid_buffer[GIT_OID_HEXSZ + 1];
    git_oid_tostr(oid_buffer, sizeof(oid_buffer), &oid);

    std::string title = git_commit_message(commit) ? git_commit_message(commit) : "";
    const size_t newline_index = title.find('\n');
    if (newline_index != std::string::npos) {
      title = title.substr(0, newline_index);
    }

    const git_signature *author = git_commit_author(commit);
    out.push_back(GitCommitSummary{
      oid_buffer,
      std::string(oid_buffer).substr(0, 7),
      title,
      author && author->name ? author->name : "",
      static_cast<long long>(git_commit_time(commit)) * 1000LL,
    });

    git_commit_free(commit);
  }

  git_revwalk_free(walk);
  git_repository_free(repo);
  return out;
}

std::string git_show_commit(const std::string &localPath,
                            const std::string &hash,
                            size_t maxBytes) {
  ensure_libgit2();

  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_object *resolved = nullptr;
  rc = git_revparse_single(&resolved, repo, hash.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_object *commit_obj = nullptr;
  rc = git_object_peel(&commit_obj, resolved, GIT_OBJECT_COMMIT);
  git_object_free(resolved);
  if (rc != 0 || commit_obj == nullptr) {
    git_repository_free(repo);
    throw GitException(rc == 0 ? "指定引用不是 commit。" : last_error_message(rc));
  }

  auto *commit = reinterpret_cast<git_commit *>(commit_obj);
  DiffBuffer buf;
  buf.maxBytes = maxBytes;

  const git_oid *commit_id = git_commit_id(commit);
  char oid_buffer[GIT_OID_HEXSZ + 1];
  git_oid_tostr(oid_buffer, sizeof(oid_buffer), commit_id);

  append_text(buf, "commit ");
  append_text(buf, oid_buffer);
  append_text(buf, "\n");

  const git_signature *author = git_commit_author(commit);
  if (author && author->name && author->name[0] != '\0') {
    append_text(buf, "Author: ");
    append_text(buf, author->name);
    if (author->email && author->email[0] != '\0') {
      append_text(buf, " <");
      append_text(buf, author->email);
      append_text(buf, ">");
    }
    append_text(buf, "\n");
  }
  append_text(buf, "CommittedAt: ");
  append_text(buf, std::to_string(static_cast<long long>(git_commit_time(commit)) * 1000LL));
  append_text(buf, "\n\n");

  const char *message = git_commit_message(commit);
  if (message && message[0] != '\0') {
    append_text(buf, message);
    if (buf.out.empty() || buf.out.back() != '\n') {
      append_text(buf, "\n");
    }
    append_text(buf, "\n");
  }

  git_tree *tree = nullptr;
  rc = git_commit_tree(&tree, commit);
  if (rc != 0) {
    git_object_free(commit_obj);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_tree *parent_tree = nullptr;
  if (git_commit_parentcount(commit) > 0) {
    git_commit *parent_commit = nullptr;
    rc = git_commit_parent(&parent_commit, commit, 0);
    if (rc != 0) {
      git_tree_free(tree);
      git_object_free(commit_obj);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }
    rc = git_commit_tree(&parent_tree, parent_commit);
    git_commit_free(parent_commit);
    if (rc != 0) {
      git_tree_free(tree);
      git_object_free(commit_obj);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }
  }

  git_diff *diff = nullptr;
  git_diff_options diff_opts = GIT_DIFF_OPTIONS_INIT;
  rc = git_diff_tree_to_tree(&diff, repo, parent_tree, tree, &diff_opts);
  if (rc != 0) {
    if (parent_tree) git_tree_free(parent_tree);
    git_tree_free(tree);
    git_object_free(commit_obj);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  print_diff(buf, diff);

  git_diff_free(diff);
  if (parent_tree) git_tree_free(parent_tree);
  git_tree_free(tree);
  git_object_free(commit_obj);
  git_repository_free(repo);

  if (buf.truncated) {
    append_text(buf, "\n…（commit 输出已截断）\n");
  }
  return buf.out;
}

namespace {

std::string oid_to_string(const git_oid *oid) {
  if (!oid) return "";
  char buffer[GIT_OID_SHA1_HEXSIZE + 1] = {0};
  git_oid_tostr(buffer, sizeof(buffer), oid);
  return std::string(buffer);
}

bool status_is_clean(const GitStatus &status) {
  return status.staged.empty() && status.unstaged.empty() &&
         status.untracked.empty() && status.conflicted.empty();
}

std::vector<std::string> index_conflict_paths(git_index *index) {
  std::vector<std::string> out;
  git_index_conflict_iterator *iterator = nullptr;
  int rc = git_index_conflict_iterator_new(&iterator, index);
  if (rc != 0) throw GitException(last_error_message(rc));

  const git_index_entry *ancestor = nullptr;
  const git_index_entry *ours = nullptr;
  const git_index_entry *theirs = nullptr;
  while ((rc = git_index_conflict_next(&ancestor, &ours, &theirs, iterator)) == 0) {
    const char *path = ours && ours->path
                           ? ours->path
                           : (theirs && theirs->path
                                  ? theirs->path
                                  : (ancestor ? ancestor->path : nullptr));
    if (path) out.emplace_back(path);
  }
  git_index_conflict_iterator_free(iterator);
  if (rc != GIT_ITEROVER) throw GitException(last_error_message(rc));
  return out;
}

GitRepositoryInfo repository_info(git_repository *repo,
                                  const std::string &localPath) {
  GitRepositoryInfo out;
  git_reference *head = nullptr;
  int rc = git_repository_head(&head, repo);
  if (rc == 0 && head) {
    if (git_reference_is_branch(head)) {
      const char *shorthand = git_reference_shorthand(head);
      if (shorthand) out.branch = shorthand;
    }
    out.headOid = oid_to_string(git_reference_target(head));
    git_reference_free(head);
  } else if (rc != GIT_EUNBORNBRANCH && rc != GIT_ENOTFOUND) {
    throw GitException(last_error_message(rc));
  }
  out.isClean = status_is_clean(git_status(localPath));
  out.isMerging = git_repository_state(repo) == GIT_REPOSITORY_STATE_MERGE;
  return out;
}

void stage_all(git_repository *repo, git_index **outIndex) {
  git_index *index = nullptr;
  int rc = git_repository_index(&index, repo);
  if (rc != 0) throw GitException(last_error_message(rc));
  git_strarray pathspec = {nullptr, 0};
  rc = git_index_add_all(index, &pathspec, GIT_INDEX_ADD_DEFAULT, nullptr, nullptr);
  if (rc == 0) {
    rc = git_index_update_all(index, &pathspec, nullptr, nullptr);
  }
  if (rc == 0) rc = git_index_write(index);
  if (rc != 0) {
    git_index_free(index);
    throw GitException(last_error_message(rc));
  }
  *outIndex = index;
}

git_signature *make_signature(const std::string &userName,
                              const std::string &userEmail) {
  if (userName.empty() || userEmail.empty()) {
    throw GitException("Git user name and email are required");
  }
  git_signature *signature = nullptr;
  const int rc = git_signature_now(&signature, userName.c_str(), userEmail.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  return signature;
}

GitCommitResult commit_index(git_repository *repo,
                             git_index *index,
                             const std::string &message,
                             const std::string &userName,
                             const std::string &userEmail,
                             const std::vector<git_commit *> &parents) {
  git_oid tree_oid;
  int rc = git_index_write_tree(&tree_oid, index);
  if (rc != 0) throw GitException(last_error_message(rc));

  git_tree *tree = nullptr;
  rc = git_tree_lookup(&tree, repo, &tree_oid);
  if (rc != 0) throw GitException(last_error_message(rc));

  git_signature *signature = make_signature(userName, userEmail);
  std::vector<const git_commit *> parent_ptrs;
  parent_ptrs.reserve(parents.size());
  for (git_commit *parent : parents) parent_ptrs.push_back(parent);

  git_oid commit_oid;
  rc = git_commit_create(&commit_oid, repo, "HEAD", signature, signature,
                         nullptr, message.c_str(), tree,
                         parent_ptrs.size(), parent_ptrs.data());
  git_signature_free(signature);
  git_tree_free(tree);
  if (rc != 0) throw GitException(last_error_message(rc));
  return GitCommitResult{oid_to_string(&commit_oid), true};
}

git_commit *lookup_head_commit(git_repository *repo) {
  git_reference *head = nullptr;
  int rc = git_repository_head(&head, repo);
  if (rc != 0) throw GitException(last_error_message(rc));
  const git_oid *oid = git_reference_target(head);
  git_commit *commit = nullptr;
  if (!oid) {
    git_reference_free(head);
    throw GitException("HEAD has no commit");
  }
  rc = git_commit_lookup(&commit, repo, oid);
  git_reference_free(head);
  if (rc != 0) throw GitException(last_error_message(rc));
  return commit;
}

void write_orig_head(git_repository *repo) {
  git_reference *head = nullptr;
  int rc = git_repository_head(&head, repo);
  if (rc != 0) throw GitException(last_error_message(rc));
  const git_oid *head_oid = git_reference_target(head);
  if (!head_oid) {
    git_reference_free(head);
    throw GitException("HEAD has no commit");
  }
  git_reference *original = nullptr;
  rc = git_reference_create(&original, repo, "ORIG_HEAD", head_oid, 1,
                            "CodexM merge");
  git_reference_free(head);
  if (original) git_reference_free(original);
  if (rc != 0) throw GitException(last_error_message(rc));
}

GitMergeResult merge_result(git_repository *repo,
                            const std::string &outcome,
                            const std::vector<std::string> &conflicts = {}) {
  git_reference *head = nullptr;
  std::string oid;
  if (git_repository_head(&head, repo) == 0 && head) {
    oid = oid_to_string(git_reference_target(head));
    git_reference_free(head);
  }
  return GitMergeResult{outcome, oid, conflicts};
}

int collect_merge_head(const git_oid *oid, void *payload) {
  auto *heads = reinterpret_cast<std::vector<git_oid> *>(payload);
  heads->push_back(*oid);
  return 0;
}

GitMergeResult finish_merge(git_repository *repo,
                            git_index *index,
                            const git_oid &source_oid,
                            const std::string &message,
                            const std::string &userName,
                            const std::string &userEmail) {
  git_commit *head = lookup_head_commit(repo);
  git_commit *source = nullptr;
  int rc = git_commit_lookup(&source, repo, &source_oid);
  if (rc != 0) {
    git_commit_free(head);
    throw GitException(last_error_message(rc));
  }
  const auto result = commit_index(repo, index, message, userName, userEmail,
                                   {head, source});
  git_commit_free(source);
  git_commit_free(head);
  rc = git_repository_state_cleanup(repo);
  if (rc != 0) throw GitException(last_error_message(rc));
  return GitMergeResult{"merged", result.oid, {}};
}

}  // namespace

GitRepositoryInfo git_init_repository(const std::string &localPath,
                                      const std::string &initialBranch) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc == 0) {
    const auto info = repository_info(repo, localPath);
    git_repository_free(repo);
    return info;
  }

  rc = git_repository_init(&repo, localPath.c_str(), 0);
  if (rc != 0) throw GitException(last_error_message(rc));
  const std::string branch = initialBranch.empty() ? "main" : initialBranch;
  const std::string ref_name = "refs/heads/" + branch;
  rc = git_repository_set_head(repo, ref_name.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_index *index = nullptr;
  rc = git_repository_index(&index, repo);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const auto result = commit_index(repo, index, "Initialize CodexM workspace",
                                   "CodexM", "codexm@local.invalid", {});
  (void)result;
  git_index_free(index);
  const auto info = repository_info(repo, localPath);
  git_repository_free(repo);
  return info;
}

GitRepositoryInfo git_repository_info(const std::string &localPath) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  const int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  const auto info = repository_info(repo, localPath);
  git_repository_free(repo);
  return info;
}

GitWorktreeInfo git_create_worktree(const std::string &mainRepoPath,
                                    const std::string &worktreePath,
                                    const std::string &name,
                                    const std::string &branchName,
                                    const std::string &startRef) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, mainRepoPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));

  git_reference *branch = nullptr;
  rc = git_branch_lookup(&branch, repo, branchName.c_str(), GIT_BRANCH_LOCAL);
  if (rc == GIT_ENOTFOUND) {
    git_object *start = nullptr;
    rc = git_revparse_single(&start, repo, startRef.c_str());
    if (rc != 0) {
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }
    git_commit *commit = nullptr;
    rc = git_commit_lookup(&commit, repo, git_object_id(start));
    git_object_free(start);
    if (rc == 0) {
      rc = git_branch_create(&branch, repo, branchName.c_str(), commit, 0);
    }
    if (commit) git_commit_free(commit);
  }
  if (rc != 0 || !branch) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }

  git_worktree_add_options options = GIT_WORKTREE_ADD_OPTIONS_INIT;
  options.ref = branch;
  options.checkout_existing = 1;
  options.checkout_options.checkout_strategy =
      GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;
  git_worktree *worktree = nullptr;
  rc = git_worktree_add(&worktree, repo, name.c_str(), worktreePath.c_str(),
                        &options);
  git_reference_free(branch);
  if (rc != 0 || !worktree) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const char *path = git_worktree_path(worktree);
  const int locked = git_worktree_is_locked(nullptr, worktree);
  GitWorktreeInfo info{name, path ? path : worktreePath,
                       git_worktree_validate(worktree) == 0, locked > 0};
  git_worktree_free(worktree);
  git_repository_free(repo);
  return info;
}

std::vector<GitWorktreeInfo> git_list_worktrees(const std::string &mainRepoPath) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, mainRepoPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_strarray names = {nullptr, 0};
  rc = git_worktree_list(&names, repo);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  std::vector<GitWorktreeInfo> out;
  for (size_t i = 0; i < names.count; ++i) {
    git_worktree *worktree = nullptr;
    if (git_worktree_lookup(&worktree, repo, names.strings[i]) != 0 ||
        !worktree) {
      continue;
    }
    const char *path = git_worktree_path(worktree);
    const int locked = git_worktree_is_locked(nullptr, worktree);
    out.push_back(GitWorktreeInfo{
        names.strings[i], path ? path : "",
        git_worktree_validate(worktree) == 0, locked > 0});
    git_worktree_free(worktree);
  }
  git_strarray_dispose(&names);
  git_repository_free(repo);
  return out;
}

void git_remove_worktree(const std::string &mainRepoPath,
                         const std::string &name,
                         bool force) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, mainRepoPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_worktree *worktree = nullptr;
  rc = git_worktree_lookup(&worktree, repo, name.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const char *path = git_worktree_path(worktree);
  if (!force && path && !status_is_clean(git_status(path))) {
    git_worktree_free(worktree);
    git_repository_free(repo);
    throw GitException("worktree has uncommitted changes");
  }
  if (force && git_worktree_is_locked(nullptr, worktree) > 0) {
    git_worktree_unlock(worktree);
  }
  git_worktree_prune_options options = GIT_WORKTREE_PRUNE_OPTIONS_INIT;
  options.flags = GIT_WORKTREE_PRUNE_VALID | GIT_WORKTREE_PRUNE_WORKING_TREE;
  if (force) options.flags |= GIT_WORKTREE_PRUNE_LOCKED;
  rc = git_worktree_prune(worktree, &options);
  git_worktree_free(worktree);
  git_repository_free(repo);
  if (rc != 0) throw GitException(last_error_message(rc));
}

GitCommitResult git_create_checkpoint(const std::string &localPath,
                                      const std::string &message,
                                      const std::string &userName,
                                      const std::string &userEmail) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_index *index = nullptr;
  stage_all(repo, &index);

  git_oid tree_oid;
  rc = git_index_write_tree(&tree_oid, index);
  git_commit *head = nullptr;
  if (rc == 0) head = lookup_head_commit(repo);
  if (rc != 0 || !head) {
    git_index_free(index);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  git_tree *head_tree = nullptr;
  rc = git_commit_tree(&head_tree, head);
  if (rc != 0) {
    git_commit_free(head);
    git_index_free(index);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  if (git_oid_equal(&tree_oid, git_tree_id(head_tree))) {
    const GitCommitResult result{oid_to_string(git_commit_id(head)), false};
    git_tree_free(head_tree);
    git_commit_free(head);
    git_index_free(index);
    git_repository_free(repo);
    return result;
  }
  git_tree_free(head_tree);
  const auto result = commit_index(repo, index, message, userName, userEmail,
                                   {head});
  git_commit_free(head);
  git_index_free(index);
  git_repository_free(repo);
  return result;
}

bool git_is_ancestor(const std::string &localPath,
                     const std::string &ancestorRef,
                     const std::string &descendantRef) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_object *ancestor = nullptr;
  git_object *descendant = nullptr;
  rc = git_revparse_single(&ancestor, repo, ancestorRef.c_str());
  if (rc == 0) rc = git_revparse_single(&descendant, repo, descendantRef.c_str());
  if (rc != 0) {
    if (ancestor) git_object_free(ancestor);
    if (descendant) git_object_free(descendant);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  if (git_oid_equal(git_object_id(descendant), git_object_id(ancestor))) {
    rc = 1;
  } else {
    rc = git_graph_descendant_of(repo, git_object_id(descendant),
                                 git_object_id(ancestor));
  }
  git_object_free(descendant);
  git_object_free(ancestor);
  git_repository_free(repo);
  if (rc < 0) throw GitException(last_error_message(rc));
  return rc == 1;
}

void git_delete_branch(const std::string &localPath,
                       const std::string &branchName,
                       bool force) {
  ensure_libgit2();
  (void)force;
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, localPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_reference *branch = nullptr;
  rc = git_branch_lookup(&branch, repo, branchName.c_str(), GIT_BRANCH_LOCAL);
  if (rc == GIT_ENOTFOUND) {
    git_repository_free(repo);
    return;
  }
  if (rc == 0) rc = git_branch_delete(branch);
  if (branch) git_reference_free(branch);
  git_repository_free(repo);
  if (rc != 0) throw GitException(last_error_message(rc));
}

GitMergeResult git_merge_ref(const std::string &targetPath,
                             const std::string &sourceRef,
                             const std::string &message,
                             const std::string &userName,
                             const std::string &userEmail) {
  ensure_libgit2();
  if (!status_is_clean(git_status(targetPath))) {
    throw GitException("target worktree has uncommitted changes");
  }
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, targetPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  if (git_repository_state(repo) != GIT_REPOSITORY_STATE_NONE) {
    git_repository_free(repo);
    throw GitException("target repository already has an operation in progress");
  }

  git_object *source_object = nullptr;
  rc = git_revparse_single(&source_object, repo, sourceRef.c_str());
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const git_oid source_oid = *git_object_id(source_object);
  git_object_free(source_object);
  git_annotated_commit *source = nullptr;
  rc = git_annotated_commit_lookup(&source, repo, &source_oid);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const git_annotated_commit *heads[] = {source};
  git_merge_analysis_t analysis;
  git_merge_preference_t preference;
  rc = git_merge_analysis(&analysis, &preference, repo, heads, 1);
  if (rc != 0) {
    git_annotated_commit_free(source);
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  if (analysis & GIT_MERGE_ANALYSIS_UP_TO_DATE) {
    const auto result = merge_result(repo, "upToDate");
    git_annotated_commit_free(source);
    git_repository_free(repo);
    return result;
  }
  if (analysis & GIT_MERGE_ANALYSIS_FASTFORWARD) {
    git_reference *head = nullptr;
    rc = git_repository_head(&head, repo);
    if (rc != 0 || !head || !git_reference_is_branch(head)) {
      if (head) git_reference_free(head);
      git_annotated_commit_free(source);
      git_repository_free(repo);
      throw GitException("fast-forward requires an attached target branch");
    }
    const std::string head_name = git_reference_name(head);
    git_object *target = nullptr;
    rc = git_object_lookup(&target, repo, &source_oid, GIT_OBJECT_COMMIT);
    if (rc == 0) {
      git_checkout_options checkout = GIT_CHECKOUT_OPTIONS_INIT;
      checkout.checkout_strategy = GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;
      rc = git_checkout_tree(repo, target, &checkout);
    }
    if (target) git_object_free(target);
    git_reference *updated = nullptr;
    if (rc == 0) {
      rc = git_reference_set_target(&updated, head, &source_oid, "CodexM merge");
    }
    git_reference_free(head);
    if (updated) git_reference_free(updated);
    if (rc == 0) rc = git_repository_set_head(repo, head_name.c_str());
    if (rc != 0) {
      git_annotated_commit_free(source);
      git_repository_free(repo);
      throw GitException(last_error_message(rc));
    }
    const auto result = merge_result(repo, "fastForward");
    git_annotated_commit_free(source);
    git_repository_free(repo);
    return result;
  }

  git_merge_options merge_options = GIT_MERGE_OPTIONS_INIT;
  git_checkout_options checkout = GIT_CHECKOUT_OPTIONS_INIT;
  checkout.checkout_strategy = GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;
  write_orig_head(repo);
  rc = git_merge(repo, heads, 1, &merge_options, &checkout);
  git_annotated_commit_free(source);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  git_index *index = nullptr;
  rc = git_repository_index(&index, repo);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const auto conflicts = index_conflict_paths(index);
  if (!conflicts.empty()) {
    git_index_free(index);
    const auto result = merge_result(repo, "conflicts", conflicts);
    git_repository_free(repo);
    return result;
  }
  const auto result = finish_merge(repo, index, source_oid, message, userName,
                                   userEmail);
  git_index_free(index);
  git_repository_free(repo);
  return result;
}

GitMergeResult git_merge_state(const std::string &targetPath) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, targetPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_index *index = nullptr;
  rc = git_repository_index(&index, repo);
  if (rc != 0) {
    git_repository_free(repo);
    throw GitException(last_error_message(rc));
  }
  const auto conflicts = index_conflict_paths(index);
  git_index_free(index);
  const auto result = merge_result(repo, conflicts.empty() ? "merged" : "conflicts",
                                   conflicts);
  git_repository_free(repo);
  return result;
}

GitMergeResult git_continue_merge(const std::string &targetPath,
                                  const std::string &message,
                                  const std::string &userName,
                                  const std::string &userEmail) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, targetPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  if (git_repository_state(repo) != GIT_REPOSITORY_STATE_MERGE) {
    git_repository_free(repo);
    throw GitException("no merge is in progress");
  }
  git_index *index = nullptr;
  stage_all(repo, &index);
  const auto conflicts = index_conflict_paths(index);
  if (!conflicts.empty()) {
    git_index_free(index);
    const auto result = merge_result(repo, "conflicts", conflicts);
    git_repository_free(repo);
    return result;
  }
  std::vector<git_oid> merge_heads;
  rc = git_repository_mergehead_foreach(repo, collect_merge_head, &merge_heads);
  if (rc != 0 || merge_heads.empty()) {
    git_index_free(index);
    git_repository_free(repo);
    throw GitException(rc == 0 ? "merge source is missing" : last_error_message(rc));
  }
  const auto result = finish_merge(repo, index, merge_heads.front(), message,
                                   userName, userEmail);
  git_index_free(index);
  git_repository_free(repo);
  return result;
}

void git_abort_merge(const std::string &targetPath) {
  ensure_libgit2();
  git_repository *repo = nullptr;
  int rc = git_repository_open(&repo, targetPath.c_str());
  if (rc != 0) throw GitException(last_error_message(rc));
  git_oid original;
  rc = git_reference_name_to_id(&original, repo, "ORIG_HEAD");
  git_object *target = nullptr;
  if (rc == 0) rc = git_object_lookup(&target, repo, &original, GIT_OBJECT_COMMIT);
  if (rc == 0) {
    git_checkout_options checkout = GIT_CHECKOUT_OPTIONS_INIT;
    checkout.checkout_strategy = GIT_CHECKOUT_FORCE | GIT_CHECKOUT_RECREATE_MISSING;
    rc = git_reset(repo, target, GIT_RESET_HARD, &checkout);
  }
  if (target) git_object_free(target);
  if (rc == 0) rc = git_repository_state_cleanup(repo);
  git_repository_free(repo);
  if (rc != 0) throw GitException(last_error_message(rc));
}
