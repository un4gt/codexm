class GitCommitResult {
  const GitCommitResult({required this.oid, required this.created});

  final String oid;
  final bool created;

  factory GitCommitResult.fromMap(Map<Object?, Object?> map) {
    return GitCommitResult(
      oid: map['oid']?.toString() ?? '',
      created: map['created'] as bool? ?? false,
    );
  }
}
