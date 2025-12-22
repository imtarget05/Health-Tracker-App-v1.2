import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Simple API service config helper used by the chat provider.
/// This avoids hardcoding API keys in multiple places and keeps a single
/// accessor for the (optional) client-side AI key read from `.env`.
class ApiService {
  /// Returns the client-side AI key (may be empty in production if you use backend).
  static String get apiKey => dotenv.env['AI_CHAT_API_KEY'] ?? '';
}
