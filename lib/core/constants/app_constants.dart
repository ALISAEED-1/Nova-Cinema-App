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

/// Keys used with SharedPreferences.
abstract final class StorageKeys {
  /// The session token and a cached copy of the account from the backend.
  static const String session = 'novaSession';

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
