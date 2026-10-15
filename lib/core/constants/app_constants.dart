/// App-wide constants.
abstract final class AppConstants {
  static const String appName = 'Nova Cinema';
  static const String catalogAsset = 'assets/data/catalog.json';
  static const String defaultAvatarAsset = 'assets/images/profile.jpg';
  static const String authBackdropAsset = 'assets/images/latest_background.jpg';

  /// Playback progress beyond this fraction counts as "watched".
  static const double watchedThreshold = 0.95;

  /// Progress below this fraction is treated as "not started" for resume.
  static const double resumeMinFraction = 0.01;

  static const int minPasswordLength = 6;
  static const int maxRecentSearches = 8;
}

/// Keys used with SharedPreferences. Mirrors the web app's localStorage keys
/// (`novaUsers`, `novaUser`) so the data model stays recognisable.
abstract final class StorageKeys {
  static const String users = 'novaUsers';
  static const String session = 'novaUser';

  /// Set once the user finishes (or skips) onboarding. Not per-user: the
  /// carousel runs before anyone signs in.
  static const String onboardingSeen = 'novaOnboardingSeen';

  static String watchlist(String email) => 'novaWatchlist:$email';
  static String progress(String email) => 'novaProgress:$email';
  static String recentSearches(String email) => 'novaRecentSearches:$email';
  static String playbackSettings(String email) => 'novaPlayback:$email';
}

abstract final class AssetPaths {
  static String image(String name) => 'assets/images/$name.jpg';
}
