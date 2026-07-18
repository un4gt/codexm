class GitStatus {
  const GitStatus({
    required this.staged,
    required this.unstaged,
    required this.untracked,
    this.conflicted = const <String>[],
  });

  final List<String> staged;
  final List<String> unstaged;
  final List<String> untracked;
  final List<String> conflicted;

  bool get isClean =>
      staged.isEmpty &&
      unstaged.isEmpty &&
      untracked.isEmpty &&
      conflicted.isEmpty;

  factory GitStatus.fromMap(Map<Object?, Object?> map) {
    List<String> readList(String key) {
      final raw = map[key];
      if (raw is List) {
        return raw.map((item) => item.toString()).toList(growable: false);
      }
      return const <String>[];
    }

    return GitStatus(
      staged: readList('staged'),
      unstaged: readList('unstaged'),
      untracked: readList('untracked'),
      conflicted: readList('conflicted'),
    );
  }
}
