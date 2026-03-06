class WebDavConfig {
  const WebDavConfig({
    required this.endpoint,
    this.basePath,
    this.authRef,
  });

  final String endpoint;
  final String? basePath;
  final String? authRef;
}

class WebDavUploadOptions {
  const WebDavUploadOptions({
    this.contentType,
    this.ifMatchETag,
  });

  final String? contentType;
  final String? ifMatchETag;
}

class WebDavDownloadResult {
  const WebDavDownloadResult({
    this.etag,
    this.contentType,
    this.contentLength,
  });

  final String? etag;
  final String? contentType;
  final int? contentLength;
}

class WebDavEntry {
  const WebDavEntry({
    required this.href,
    required this.path,
    required this.isCollection,
    this.etag,
    this.contentLength,
    this.lastModified,
  });

  final String href;
  final String path;
  final bool isCollection;
  final String? etag;
  final int? contentLength;
  final String? lastModified;
}

class WebDavBasicAuth {
  const WebDavBasicAuth({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

class WebDavBearerAuth {
  const WebDavBearerAuth({required this.token});

  final String token;
}

class WebDavSyncProgress {
  const WebDavSyncProgress({
    required this.phase,
    this.current,
    this.total,
    this.path,
  });

  final String phase;
  final int? current;
  final int? total;
  final String? path;
}
