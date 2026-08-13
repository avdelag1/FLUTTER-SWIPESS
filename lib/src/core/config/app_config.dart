/// App secrets / public config via `--dart-define` / dart_defines.json.
///
/// Do **not** hardcode tokens in source — GitHub push protection blocks them.
/// Copy `dart_defines.json.example` → `dart_defines.json` (gitignored) and run:
/// `flutter run --dart-define-from-file=dart_defines.json`
class AppConfig {
  AppConfig._();

  /// RevenueCat public SDK key (`test_…` for Test Store, or `appl_` / `goog_`).
  static const revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  static const revenueCatAppleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: '',
  );
  static const revenueCatGoogleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: '',
  );

  /// Mapbox **public** token (`pk.…`).
  /// Prefer `--dart-define=MAPBOX_ACCESS_TOKEN=…` / `dart_defines.json`.
  /// Cap ships a public fallback so the map never stays blank when env is missing.
  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static bool get hasMapboxToken => mapboxAccessToken.trim().isNotEmpty;

  /// Google Sign-In web/server client ID (`….apps.googleusercontent.com`).
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// iOS OAuth client ID for native Google Sign-In.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get hasRevenueCatKey => revenueCatApiKey.trim().isNotEmpty ||
      revenueCatAppleApiKey.trim().isNotEmpty ||
      revenueCatGoogleApiKey.trim().isNotEmpty;
}
