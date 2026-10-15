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

Requirements: Flutter 3.32+ (Dart 3.8+), Android SDK for APK builds.

### Backend

Accounts, plans and payments come from **nova-pay**, the payment backend. Run it,
then let a USB-connected phone reach it:

```bash
adb reverse tcp:4000 tcp:4000   # phone's localhost:4000 → this computer
flutter run
```

The app calls `http://localhost:4000` by default. Change it with
`--dart-define=API_BASE_URL=...`, e.g. `http://10.0.2.2:4000` on the Android emulator.

### How paying works

1. The plan screen loads plans priced in the account's currency ($, €, Rs, ₹, Tk).
   The billing-country chip switches it.
2. **Continue** asks nova-pay for a checkout session, sending an idempotency key
   so a retry can never create a second charge.
3. The provider's hosted checkout page opens in a web view. Card details go to
   the provider, never to the app.
4. When the provider redirects back, the app asks nova-pay for the outcome. The
   plan unlocks only when the server has confirmed the payment with the provider.

US and EU checkouts go to Stripe when the backend has a Stripe test key;
everything else uses the backend's test provider.

### Rentals

A plan is optional. New members can choose **Not now** and browse. Any title
they can't watch shows **Rent for 48h** (for example `Rs 199` or `$3.99`) beside
a link to the plans. The same checkout flow runs, and once the payment is
confirmed the title plays for 48 hours. Profile lists active rentals with the
time left. Trailers are always free.

### Managing a plan

Profile › Subscription shows where the plan stands, for example "Renews
15 Nov · Visa •••• 4242", "Ends 15 Nov" or "Payment overdue · watching until
22 Nov". It offers:
- **Pay now** when a renewal is due by hand (mobile wallets) or a card was
  declined. The plan keeps working through the grace period until it's paid.
- **Cancel plan / Resume plan.** A canceled plan runs to the end of the period
  already paid for.
- **Billing history** of past bills.
- **Developer: skip ahead** (debug builds only), which asks the test server to
  move this account's billing dates forward, to show a renewal or a failed
  payment without waiting a month.

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
  services/                 CatalogService, AuthService, BillingService, WatchlistService,
                            PlaybackService, SearchHistoryService, LocalStore
    api/                    NovaApi (backend interface) and its HTTP implementation
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
changes. Accounts and subscriptions live on the nova-pay backend; the app keeps
the session token and a cached copy of the account so it opens signed in. The
watchlist, playback progress, recent searches and playback preferences stay on
the device with `shared_preferences`.

## Packages

| Package              | Why                                                        |
|----------------------|------------------------------------------------------------|
| `provider`           | lightweight state management                               |
| `video_player`       | native playback (ExoPlayer / AVPlayer) of the bundled MP4s |
| `shared_preferences` | on-device persistence, mirrors the web `localStorage`      |
| `wakelock_plus`      | keeps the screen on while a movie is playing               |
| `http`               | talks to the nova-pay backend                              |
| `webview_flutter`    | shows the payment provider's hosted checkout page          |
