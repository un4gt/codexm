#pragma once

#include <stdexcept>
#include <string>
#include <vector>

struct GitException : public std::runtime_error {
  explicit GitException(const std::string &msg) : std::runtime_error(msg) {}
};

struct GitCloneOptions {
  std::string remoteUrl;
  std::string localPath;
  std::string branch;
  std::string username;
  std::string token;
  bool allowInsecure = false;
  std::string userName;
  std::string userEmail;
};

struct GitCheckoutOptions {
  std::string localPath;
  std::string ref;
};

struct GitPullOptions {
  std::string localPath;
  std::string remote;
  std::string branch;
  std::string username;
  std::string token;
  bool allowInsecure = false;
};

struct GitPushOptions {
  std::string localPath;
  std::string remote;
  std::string branch;
  std::string username;
  std::string token;
  bool allowInsecure = false;
};

struct GitStatus {
  std::vector<std::string> staged;
  std::vector<std::string> unstaged;
  std::vector<std::string> untracked;
  std::vector<std::string> conflicted;
};

struct GitRepositoryInfo {
  std::string branch;
  std::string headOid;
  bool isClean = false;
  bool isMerging = false;
};

struct GitWorktreeInfo {
  std::string name;
  std::string path;
  bool valid = false;
  bool locked = false;
};

struct GitCommitResult {
  std::string oid;
  bool created = false;
};

struct GitMergeResult {
  std::string outcome;
  std::string headOid;
  std::vector<std::string> conflictPaths;
};

struct GitCommitSummary {
  std::string hash;
  std::string shortHash;
  std::string title;
  std::string authorName;
  long long committedAt = 0;
};

void git_clone_repo(const GitCloneOptions &opts);
void git_checkout_ref(const GitCheckoutOptions &opts);
void git_pull_ff_only(const GitPullOptions &opts);
void git_push_branch(const GitPushOptions &opts);
GitStatus git_status(const std::string &localPath);
std::string git_diff_unified(const std::string &localPath, size_t maxBytes);
std::vector<GitCommitSummary> git_recent_commits(const std::string &localPath,
                                                 size_t limit);
std::string git_show_commit(const std::string &localPath,
                            const std::string &hash,
                            size_t maxBytes);
GitRepositoryInfo git_init_repository(const std::string &localPath,
                                      const std::string &initialBranch);
GitRepositoryInfo git_repository_info(const std::string &localPath);
GitWorktreeInfo git_create_worktree(const std::string &mainRepoPath,
                                    const std::string &worktreePath,
                                    const std::string &name,
                                    const std::string &branchName,
                                    const std::string &startRef);
std::vector<GitWorktreeInfo> git_list_worktrees(const std::string &mainRepoPath);
void git_remove_worktree(const std::string &mainRepoPath,
                         const std::string &name,
                         bool force);
GitCommitResult git_create_checkpoint(const std::string &localPath,
                                      const std::string &message,
                                      const std::string &userName,
                                      const std::string &userEmail);
bool git_is_ancestor(const std::string &localPath,
                     const std::string &ancestorRef,
                     const std::string &descendantRef);
void git_delete_branch(const std::string &localPath,
                       const std::string &branchName,
                       bool force);
GitMergeResult git_merge_ref(const std::string &targetPath,
                             const std::string &sourceRef,
                             const std::string &message,
                             const std::string &userName,
                             const std::string &userEmail);
GitMergeResult git_merge_state(const std::string &targetPath);
GitMergeResult git_continue_merge(const std::string &targetPath,
                                  const std::string &message,
                                  const std::string &userName,
                                  const std::string &userEmail);
void git_abort_merge(const std::string &targetPath);
