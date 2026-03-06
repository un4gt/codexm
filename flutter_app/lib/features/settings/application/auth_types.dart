typedef AuthRef = String;

class GitHttpsAuth {
  const GitHttpsAuth({
    required this.username,
    required this.token,
  });

  final String username;
  final String token;

  Map<String, Object?> toMap() => {
        'type': 'git_https',
        'username': username,
        'token': token,
      };
}

class WebDavBasicStoredAuth {
  const WebDavBasicStoredAuth({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  Map<String, Object?> toMap() => {
        'type': 'webdav_basic',
        'username': username,
        'password': password,
      };
}

class WebDavBearerStoredAuth {
  const WebDavBearerStoredAuth({required this.token});

  final String token;

  Map<String, Object?> toMap() => {
        'type': 'webdav_bearer',
        'token': token,
      };
}

class CodexProviderAuth {
  const CodexProviderAuth({required this.token});

  final String token;

  Map<String, Object?> toMap() => {
        'type': 'codex_bearer',
        'token': token,
      };
}
