class RuntimeLineEvent {
  const RuntimeLineEvent({
    required this.runtimeId,
    required this.stream,
    required this.line,
  });

  final String runtimeId;
  final String stream;
  final String line;

  factory RuntimeLineEvent.fromMap(Map<Object?, Object?> map) {
    return RuntimeLineEvent(
      runtimeId: map['runtimeId']?.toString() ?? '',
      stream: map['stream']?.toString() ?? 'stdout',
      line: map['line']?.toString() ?? '',
    );
  }
}
