import 'package:flutter/foundation.dart';

class AppConfig {
  /// The current execution environment.
  static const String env = 'production';

  /// The production API domain address.
  static const String prodDomain = 'cricket-tournament-djdp.onrender.com';

  /// Returns the base URL based on the environment configuration
  static String get baseUrl {
    return "http://10.225.255.71:8000/api/v1";
  }
}


