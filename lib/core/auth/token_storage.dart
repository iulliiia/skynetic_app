import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session tokens as returned by the backend.
class StoredTokens {
  final String accessToken;
  final String refreshToken;

  const StoredTokens({required this.accessToken, required this.refreshToken});

  factory StoredTokens.fromJson(Map<String, dynamic> json) => StoredTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );
}

/// Where tokens live. The production implementation uses the platform
/// keychain/keystore; tests use memory. Tokens are never written to
/// SharedPreferences.
abstract class TokenStorage {
  Future<StoredTokens?> read();
  Future<void> write(StoredTokens tokens);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  static const _accessKey = 'skynetic.access_token';
  static const _refreshKey = 'skynetic.refresh_token';

  final FlutterSecureStorage _storage;

  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Android: EncryptedSharedPreferences is the default in v11.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  @override
  Future<StoredTokens?> read() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access == null || refresh == null) return null;
      return StoredTokens(accessToken: access, refreshToken: refresh);
    } catch (_) {
      // Keychain unavailable (e.g. first unlock not yet happened): treat as
      // signed out rather than crashing.
      return null;
    }
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// In-memory storage for tests and previews.
class InMemoryTokenStorage implements TokenStorage {
  StoredTokens? _tokens;

  InMemoryTokenStorage([this._tokens]);

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
