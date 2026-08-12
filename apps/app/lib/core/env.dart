/// Build-time configuration.
///
/// Supplied with `--dart-define`, never checked in, so the same binary artefact
/// can be pointed at staging or production without a code change:
///
///   flutter run --dart-define=ABER_API_BASE_URL=http://localhost:8000
class Env {
  const Env._();

  static const String _hostedBaseUrl = 'https://aber-api.onrender.com';
  static const String _rawBaseUrl = String.fromEnvironment('ABER_API_BASE_URL');

  /// Base URL of the API.
  ///
  /// The deployed Render service is the default so preview builds and phone
  /// installs talk to the shared backend unless a developer overrides it.
  static String get apiBaseUrl {
    if (_rawBaseUrl.isNotEmpty) return _rawBaseUrl;
    return _hostedBaseUrl;
  }

  static const String environment = String.fromEnvironment(
    'ABER_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';

  static const Duration connectTimeout = Duration(seconds: 10);

  /// Generous because agents upload photos over weak site connections.
  static const Duration receiveTimeout = Duration(seconds: 30);
}
