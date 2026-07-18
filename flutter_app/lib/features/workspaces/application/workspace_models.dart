typedef AuthRef = String;
typedef WorkspaceId = String;

class WorkspaceGitConfig {
  const WorkspaceGitConfig({
    required this.remoteUrl,
    this.defaultBranch,
    this.authRef,
    this.allowInsecure = false,
    this.userName,
    this.userEmail,
  });

  final String remoteUrl;
  final String? defaultBranch;
  final AuthRef? authRef;
  final bool allowInsecure;
  final String? userName;
  final String? userEmail;

  Map<String, Object?> toMap() {
    return {
      'remoteUrl': remoteUrl,
      'defaultBranch': defaultBranch,
      'authRef': authRef,
      'allowInsecure': allowInsecure,
      'userName': userName,
      'userEmail': userEmail,
    };
  }

  factory WorkspaceGitConfig.fromMap(Map<String, Object?> map) {
    return WorkspaceGitConfig(
      remoteUrl: map['remoteUrl']?.toString() ?? '',
      defaultBranch: map['defaultBranch']?.toString(),
      authRef: map['authRef']?.toString(),
      allowInsecure: map['allowInsecure'] as bool? ?? false,
      userName: map['userName']?.toString(),
      userEmail: map['userEmail']?.toString(),
    );
  }
}

class WorkspaceWebDavConfig {
  const WorkspaceWebDavConfig({
    required this.endpoint,
    this.basePath,
    this.remoteRoot,
    this.authRef,
  });

  final String endpoint;
  final String? basePath;
  final String? remoteRoot;
  final AuthRef? authRef;

  Map<String, Object?> toMap() {
    return {
      'endpoint': endpoint,
      'basePath': basePath,
      'remoteRoot': remoteRoot,
      'authRef': authRef,
    };
  }

  factory WorkspaceWebDavConfig.fromMap(Map<String, Object?> map) {
    return WorkspaceWebDavConfig(
      endpoint: map['endpoint']?.toString() ?? '',
      basePath: map['basePath']?.toString(),
      remoteRoot: map['remoteRoot']?.toString(),
      authRef: map['authRef']?.toString(),
    );
  }
}

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.localPath,
    this.git,
    this.webdav,
    this.integrationBranch,
    this.sessionGitVersion = 0,
    this.gitUserName,
    this.gitUserEmail,
    this.pendingMergeSourceSessionId,
  });

  final WorkspaceId id;
  final String name;
  final int createdAt;
  final String localPath;
  final WorkspaceGitConfig? git;
  final WorkspaceWebDavConfig? webdav;
  final String? integrationBranch;
  final int sessionGitVersion;
  final String? gitUserName;
  final String? gitUserEmail;
  final String? pendingMergeSourceSessionId;

  Workspace copyWith({
    String? name,
    int? createdAt,
    String? localPath,
    WorkspaceGitConfig? git,
    WorkspaceWebDavConfig? webdav,
    String? integrationBranch,
    int? sessionGitVersion,
    String? gitUserName,
    String? gitUserEmail,
    String? pendingMergeSourceSessionId,
    bool clearGit = false,
    bool clearWebDav = false,
    bool clearPendingMergeSourceSessionId = false,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      localPath: localPath ?? this.localPath,
      git: clearGit ? null : (git ?? this.git),
      webdav: clearWebDav ? null : (webdav ?? this.webdav),
      integrationBranch: integrationBranch ?? this.integrationBranch,
      sessionGitVersion: sessionGitVersion ?? this.sessionGitVersion,
      gitUserName: gitUserName ?? this.gitUserName,
      gitUserEmail: gitUserEmail ?? this.gitUserEmail,
      pendingMergeSourceSessionId: clearPendingMergeSourceSessionId
          ? null
          : (pendingMergeSourceSessionId ?? this.pendingMergeSourceSessionId),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'localPath': localPath,
      'git': git?.toMap(),
      'webdav': webdav?.toMap(),
      'integrationBranch': integrationBranch,
      'sessionGitVersion': sessionGitVersion,
      'gitUserName': gitUserName,
      'gitUserEmail': gitUserEmail,
      'pendingMergeSourceSessionId': pendingMergeSourceSessionId,
    };
  }

  factory Workspace.fromMap(Map<String, Object?> map) {
    return Workspace(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      localPath: map['localPath']?.toString() ?? '',
      git: map['git'] is Map
          ? WorkspaceGitConfig.fromMap(
              Map<String, Object?>.from(map['git'] as Map),
            )
          : null,
      webdav: map['webdav'] is Map
          ? WorkspaceWebDavConfig.fromMap(
              Map<String, Object?>.from(map['webdav'] as Map),
            )
          : null,
      integrationBranch: map['integrationBranch']?.toString(),
      sessionGitVersion: (map['sessionGitVersion'] as num?)?.toInt() ?? 0,
      gitUserName: map['gitUserName']?.toString(),
      gitUserEmail: map['gitUserEmail']?.toString(),
      pendingMergeSourceSessionId: map['pendingMergeSourceSessionId']
          ?.toString(),
    );
  }
}
