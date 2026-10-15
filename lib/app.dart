import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/home/catalog_controller.dart';
import 'features/player/playback_controller.dart';
import 'features/search/search_view_model.dart';
import 'features/watchlist/watchlist_controller.dart';
import 'navigation/app_router.dart';
import 'navigation/main_shell.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/local_store.dart';
import 'services/onboarding_service.dart';
import 'services/playback_service.dart';
import 'services/search_history_service.dart';
import 'services/watchlist_service.dart';

/// Root widget: wires services into controllers and hosts the router.
class NovaCinemaApp extends StatelessWidget {
  const NovaCinemaApp({
    super.key,
    required this.store,
    this.catalogService = const CatalogService(),
  });

  final LocalStore store;

  /// Injectable so tests can supply an in-memory catalogue.
  final CatalogService catalogService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController(AuthService(store))..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogController(catalogService)..load(),
        ),
        ChangeNotifierProxyProvider<AuthController, WatchlistController>(
          create: (_) => WatchlistController(WatchlistService(store)),
          update: (_, auth, watchlist) =>
              watchlist!..setUser(auth.user?.email),
        ),
        ChangeNotifierProxyProvider<AuthController, PlaybackController>(
          create: (_) => PlaybackController(PlaybackService(store)),
          update: (_, auth, playback) => playback!..setUser(auth.user?.email),
        ),
        ChangeNotifierProxyProvider2<AuthController, CatalogController,
            SearchViewModel>(
          create: (_) => SearchViewModel(SearchHistoryService(store)),
          update: (_, auth, catalog, search) => search!
            ..setUser(auth.user?.email)
            ..attach(catalog.catalog),
        ),
        Provider<OnboardingService>(
          create: (_) => OnboardingService(store),
        ),
        ChangeNotifierProvider(create: (_) => ShellTabs()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
