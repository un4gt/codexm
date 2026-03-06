import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'auth_types.dart';

abstract class SecureKeyValueStore {
  Future<void> write({
    required String key,
    required String value,
  });

  Future<String?> read({required String key});

  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

class AuthStore {
  AuthStore({
    SecureKeyValueStore? secureStore,
    Uuid? uuid,
  })  : _secureStore = secureStore ?? FlutterSecureKeyValueStore(),
        _uuid = uuid ?? const Uuid();

  static const _keyPrefix = 'codexm_auth_';

  final SecureKeyValueStore _secureStore;
  final Uuid _uuid;

  Future<AuthRef> saveAuth(Map<String, Object?> auth) async {
    final ref = '$_keyPrefix${_uuid.v4()}';
    await _secureStore.write(key: ref, value: jsonEncode(auth));
    return ref;
  }

  Future<Map<String, Object?>?> loadAuth(AuthRef ref) async {
    final raw = await _secureStore.read(key: ref);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = jsonDecode(raw);
    if (parsed is Map) {
      return Map<String, Object?>.from(parsed);
    }
    return null;
  }

  Future<void> deleteAuth(AuthRef ref) {
    return _secureStore.delete(key: ref);
  }
}
