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
