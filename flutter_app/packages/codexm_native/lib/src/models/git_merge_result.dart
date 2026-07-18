enum GitMergeOutcome { upToDate, fastForward, merged, conflicts }

class GitMergeResult {
  const GitMergeResult({
    required this.outcome,
    required this.headOid,
    required this.conflictPaths,
  });

  final GitMergeOutcome outcome;
  final String headOid;
  final List<String> conflictPaths;

  factory GitMergeResult.fromMap(Map<Object?, Object?> map) {
    return GitMergeResult(
      outcome: GitMergeOutcome.values.firstWhere(
        (value) => value.name == map['outcome']?.toString(),
        orElse: () => GitMergeOutcome.conflicts,
      ),
      headOid: map['headOid']?.toString() ?? '',
      conflictPaths: (map['conflictPaths'] as List? ?? const <Object?>[])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}
