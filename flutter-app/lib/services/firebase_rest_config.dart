/// Desktop (Windows/macOS/Linux) Firebase Auth/RTDB config for REST-based access.
///
/// This file intentionally avoids any FlutterFire imports so it can be used in
/// desktop builds where Firebase SDK dependencies may be removed.
class FirebaseRestConfig {
  // Firebase Web API key (same project as mobile).
  static const String apiKey = 'AIzaSyD0p0VVhW_yeemr9cWwdcDOd-BOSI3hk4Q';

  // Realtime Database URL.
  static const String databaseUrl =
      'https://similarity-quiz-sync-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Google OAuth client ID for "Desktop app" credentials.
  ///
  /// Set via: `--dart-define=DESKTOP_GOOGLE_OAUTH_CLIENT_ID=...`
  static const String googleDesktopClientId =
      String.fromEnvironment('DESKTOP_GOOGLE_OAUTH_CLIENT_ID', defaultValue: '');

  /// Google OAuth client secret for "Desktop app" credentials.
  ///
  /// Googleの「Desktop app」OAuthは token 交換時に `client_secret` が必要になるケースがあるため、
  /// 任意指定できるようにしています。
  ///
  /// Set via: `--dart-define=DESKTOP_GOOGLE_OAUTH_CLIENT_SECRET=...`
  static const String googleDesktopClientSecret = String.fromEnvironment(
    'DESKTOP_GOOGLE_OAUTH_CLIENT_SECRET',
    defaultValue: '',
  );
}
