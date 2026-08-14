/// App secrets / public config via `--dart-define` / dart_defines.json.
///
/// Do **not** hardcode tokens in source — GitHub push protection blocks them.
/// Copy `dart_defines.json.example` → `dart_defines.json` (gitignored) and run:
/// `flutter run --dart-define-from-file=dart_defines.json`
class AppConfig {
  AppConfig._();

  /// Mapbox **public** token (`pk.…`).
  /// Prefer `--dart-define=MAPBOX_ACCESS_TOKEN=…` / `dart_defines.json`.
  /// Empty → Esri satellite + Carto labels (the old Cap `pk.` is revoked).
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
}
