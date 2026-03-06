class GitCommitSummary {
  const GitCommitSummary({
    required this.hash,
    required this.shortHash,
    required this.title,
    required this.authorName,
    required this.committedAt,
  });

  final String hash;
  final String shortHash;
  final String title;
  final String authorName;
  final int committedAt;

  factory GitCommitSummary.fromMap(Map<Object?, Object?> map) {
    return GitCommitSummary(
      hash: map['hash']?.toString() ?? '',
      shortHash: map['shortHash']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      authorName: map['authorName']?.toString() ?? '',
      committedAt: (map['committedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
