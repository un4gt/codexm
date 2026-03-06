typedef McpServerId = String;

class McpServer {
  const McpServer({
    required this.id,
    required this.kind,
    required this.name,
    required this.configKey,
    required this.transport,
    required this.createdAt,
    required this.updatedAt,
    this.url,
    this.command,
    this.args,
  });

  final McpServerId id;
  final String kind;
  final String name;
  final String configKey;
  final String transport;
  final String? url;
  final String? command;
  final List<String>? args;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kind': kind,
      'name': name,
      'configKey': configKey,
      'transport': transport,
      'url': url,
      'command': command,
      'args': args,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory McpServer.fromMap(Map<String, Object?> map) {
    return McpServer(
      id: map['id']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'rmcp',
      name: map['name']?.toString() ?? '',
      configKey: map['configKey']?.toString() ?? '',
      transport: map['transport']?.toString() ?? 'url',
      url: map['url']?.toString(),
      command: map['command']?.toString(),
      args: (map['args'] as List?)
          ?.map((item) => item.toString())
          .toList(growable: false),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class McpServerCreateParams {
  const McpServerCreateParams({
    this.id,
    this.kind = 'rmcp',
    required this.name,
    this.configKey,
    required this.transport,
    this.url,
    this.command,
    this.args,
  });

  final McpServerId? id;
  final String kind;
  final String name;
  final String? configKey;
  final String transport;
  final String? url;
  final String? command;
  final List<String>? args;
}
