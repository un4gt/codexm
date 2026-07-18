class GitRepositoryInfo {
  const GitRepositoryInfo({
    required this.branch,
    required this.headOid,
    required this.isClean,
    required this.isMerging,
  });

  final String branch;
  final String headOid;
  final bool isClean;
  final bool isMerging;

  factory GitRepositoryInfo.fromMap(Map<Object?, Object?> map) {
    return GitRepositoryInfo(
      branch: map['branch']?.toString() ?? '',
      headOid: map['headOid']?.toString() ?? '',
      isClean: map['isClean'] as bool? ?? false,
      isMerging: map['isMerging'] as bool? ?? false,
    );
  }
}
