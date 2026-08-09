import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Supplied with `--dart-define`, never checked in, so the same binary artefact
/// can be pointed at staging or production without a code change:
///
///   flutter run --dart-define=ABER_API_BASE_URL=https://api.abergroup.ae
class Env {
  const Env._();

  static const String _rawBaseUrl = String.fromEnvironment('ABER_API_BASE_URL');

  /// Base URL of the API.
  ///
  /// The default is developer convenience only. Android emulators reach the
  /// host through 10.0.2.2 rather than localhost, which is the single most
  /// common "why can't the app see my server" question on a new machine.
  static String get apiBaseUrl {
    if (_rawBaseUrl.isNotEmpty) return _rawBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
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
