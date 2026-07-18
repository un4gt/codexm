class GitWorktreeInfo {
  const GitWorktreeInfo({
    required this.name,
    required this.path,
    required this.valid,
    required this.locked,
  });

  final String name;
  final String path;
  final bool valid;
  final bool locked;

  factory GitWorktreeInfo.fromMap(Map<Object?, Object?> map) {
    return GitWorktreeInfo(
      name: map['name']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      valid: map['valid'] as bool? ?? false,
      locked: map['locked'] as bool? ?? false,
    );
  }
}
