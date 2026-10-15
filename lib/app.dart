import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/api_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/home/catalog_controller.dart';
import 'features/player/playback_controller.dart';
import 'features/search/search_view_model.dart';
import 'features/subscription/checkout_launcher.dart';
import 'features/watchlist/watchlist_controller.dart';
import 'navigation/app_router.dart';
import 'navigation/main_shell.dart';
import 'services/api/http_nova_api.dart';
import 'services/api/nova_api.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
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
    this.api,
    this.checkoutLauncher = const WebViewCheckoutLauncher(),
  });

  final LocalStore store;

  /// Injectable so tests can supply an in-memory catalogue.
  final CatalogService catalogService;

  /// The nova-pay backend. Defaults to HTTP at [ApiConfig.baseUrl]; tests
  /// supply a fake.
  final NovaApi? api;

  /// Opens the provider's hosted checkout. Tests replace the web view.
  final CheckoutLauncher checkoutLauncher;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NovaApi>(
          create: (_) => api ?? HttpNovaApi(baseUrl: ApiConfig.baseUrl),
        ),
        Provider<AuthService>(
          create: (context) => AuthService(store, context.read<NovaApi>()),
        ),
        Provider<BillingService>(
          create: (context) => BillingService(
            context.read<NovaApi>(),
            context.read<AuthService>(),
          ),
        ),
        Provider<CheckoutLauncher>.value(value: checkoutLauncher),
        ChangeNotifierProvider(
          create: (context) =>
              AuthController(context.read<AuthService>())..restoreSession(),
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
