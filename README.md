# Nova Cinema — Flutter app

A mobile-first, cinematic movie streaming app for phones and tablets. It started as a
rebuild of the Nova Cinema streaming website and reproduces its functionality with a
redesigned interface.

## Run it

```bash
flutter pub get
flutter run                 # picks a connected device / emulator
flutter run -d chrome       # quick look in a browser
flutter build apk --release # android/app/build/outputs/... → build/app/outputs/flutter-apk/app-release.apk
```

Requirements: Flutter 3.32+ (Dart 3.8+), Android SDK for APK builds. No API keys,
environment variables or backend services are needed — the original project is
fully client-side and so is this app.

## Architecture

```
lib/
  main.dart                 bootstrap (orientation, system UI, local store)
  app.dart                  providers + MaterialApp
  core/
    constants/              app constants, storage keys, asset paths
    theme/                  colours, spacing/radius/durations, ThemeData
    utils/                  debouncer, formatters, validators, responsive
  models/                   Movie, Catalog, AppUser, SubscriptionPlan, PlaybackProgress…
  services/                 CatalogService, AuthService, WatchlistService,
                            PlaybackService, SearchHistoryService, LocalStore
  features/
    splash/  auth/  subscription/  home/  search/  movie_details/
    player/  watchlist/  profile/     (screen + ChangeNotifier per feature)
  navigation/               AppRouter (routes + transitions), MainShell (bottom nav)
  widgets/                  MovieCard, MovieSection, WatchlistButton, RatingBadge,
                            PrimaryButton, AppImage, Shimmer, loading/error/empty states…
assets/
  data/catalog.json         the consolidated title catalogue
  images/                   posters/backdrops (converted from the web project)
  videos/                   trailer MP4s (full-length movies are not included)
  fonts/                    Outfit (the web project's typeface)
```

State management is `provider` with one `ChangeNotifier` per concern
(`AuthController`, `CatalogController`, `WatchlistController`, `PlaybackController`,
`SearchViewModel`, `ShellTabs`). Services do I/O; controllers hold state; screens are
thin.

## Data

The website kept its movie data inline in each HTML page. That data has been merged
into `assets/data/catalog.json` and is loaded through `CatalogService`, so the UI
never touches the source directly and a remote API can replace the asset without UI
changes. Accounts, session, watchlist, playback progress, recent searches and
playback preferences are stored with `shared_preferences` — the mobile counterpart
of the website's `localStorage`, using the same `novaUsers` / `novaUser` keys.

## Packages

| Package              | Why                                                        |
|----------------------|------------------------------------------------------------|
| `provider`           | lightweight state management                               |
| `video_player`       | native playback (ExoPlayer / AVPlayer) of the bundled MP4s |
| `shared_preferences` | on-device persistence, mirrors the web `localStorage`      |
| `wakelock_plus`      | keeps the screen on while a movie is playing               |
