import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            // Keychain item is readable only after first unlock and never leaves
            // this device (no iCloud/backup restore to another device). Android
            // uses the plugin's hardware-backed KeyStore ciphers (v10 default:
            // AES-GCM data key wrapped with RSA-OAEP); data written by ≤9.x's
            // EncryptedSharedPreferences is migrated automatically on first access
            // (migrateOnAlgorithmChange defaults to true).
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _s;
  // In-memory cache to avoid a disk read per outbound HTTP request.
  String? _accessCache;
  String? _refreshCache;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kCachedUser = 'cached_session_user_v1';

  Future<String?> getAccess() async =>
      _accessCache ??= await _s.read(key: _kAccess);

  Future<String?> getRefresh() async =>
      _refreshCache ??= await _s.read(key: _kRefresh);

  Future<String?> getCachedUser() => _s.read(key: _kCachedUser);

  Future<void> saveCachedUser(String json) =>
      _s.write(key: _kCachedUser, value: json);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessCache = access;
    _refreshCache = refresh;
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kCachedUser);
  }
}
