import 'package:http/http.dart' as http;

/// Singleton HTTP client shared across mushroom services to avoid
/// creating multiple connections and leaking resources.
class SharedHttpClient {
  SharedHttpClient._internal();

  static final SharedHttpClient _instance = SharedHttpClient._internal();

  factory SharedHttpClient() => _instance;

  http.Client? _client;

  http.Client get client {
    _client ??= http.Client();
    return _client!;
  }

  /// Close the shared client. Call this when the app is shutting down
  /// or when all mushroom services are no longer needed.
  void dispose() {
    _client?.close();
    _client = null;
  }
}
