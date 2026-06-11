import 'dart:io';

class AppConfig {
  /// The current execution environment.
  /// Possible values: 'dev_emulator' (default), 'physical_device', 'production'
  static const String env = String.fromEnvironment('APP_ENV', defaultValue: 'dev_emulator');

  /// The LAN IP address of your development machine when testing on a physical device.
  /// Define this using: --dart-define=LAN_IP=192.168.X.X
  static const String lanIp = String.fromEnvironment('LAN_IP', defaultValue: '192.168.1.100');

  /// The production API domain address.
  /// Define this using: --dart-define=PROD_DOMAIN=api.crickettournament.com
  static const String prodDomain = String.fromEnvironment('PROD_DOMAIN', defaultValue: 'cricket-tournament-production.up.railway.app');

  /// Returns the base URL based on the environment configuration
  static String get baseUrl {
    switch (env) {
      case 'production':
        return "https://$prodDomain/api/v1";
      case 'physical_device':
        return "http://$lanIp:8000/api/v1";
      case 'dev_emulator':
      default:
        // Development Emulator / Localhost fallback
        if (Platform.isAndroid) {
          return "http://10.0.2.2:8000/api/v1";
        }
        return "http://localhost:8000/api/v1";
    }
  }
}
