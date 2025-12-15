// Simple in-memory auth storage for development.
// For production/mobile persist to secure storage (flutter_secure_storage).
class AuthStorage {
  static String? _jwt;

  static void saveToken(String token) {
    _jwt = token;
  }

  static String? get token => _jwt;

  static void clear() {
    _jwt = null;
  }
}
