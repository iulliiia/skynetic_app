import 'dart:io';

import 'package:flutter/foundation.dart';

/// Runtime configuration. Values can be overridden at build time:
///   flutter run --dart-define=API_URL=http://192.168.1.230:8080
class AppConfig {
  const AppConfig._();

  static const String _apiUrlOverride = String.fromEnvironment('API_URL');

  /// Version of the mandatory processing notice the registration screen
  /// shows. Phase 7 replaces this constant with `GET /consents/notices`.
  static const String serviceNoticeVersion = '1.0';

  /// Platform API (Go backend): accounts, lesions, scans, analysis, reviews.
  /// The AI inference service is reached only through it.
  static String get platformBaseUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    if (kReleaseMode) return 'https://eldie.ro/api/v1/skynetic';
    return '${_devHost()}:8080';
  }

  /// The Android emulator reaches the host machine through 10.0.2.2, the
  /// iOS simulator through localhost.
  static String _devHost() {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2';
    return 'http://localhost';
  }
}
