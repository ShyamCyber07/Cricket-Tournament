import 'package:flutter/foundation.dart';

class AppConfig {
  /// The current execution environment.
  static const String env = 'production';

  /// The production API domain address.
  static const String prodDomain = 'cricket-tournament-production.up.railway.app';

  /// Returns the base URL based on the environment configuration
  static String get baseUrl {
    return "https://cricket-tournament-production.up.railway.app/api/v1";
  }
}


