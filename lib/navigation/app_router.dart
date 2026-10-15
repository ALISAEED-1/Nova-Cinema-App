import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_spacing.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/movie_details/movie_details_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/player/player_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/subscription/plan_screen.dart';
import '../models/movie.dart';
import 'main_shell.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String plans = '/plans';
  static const String main = '/main';
  static const String details = '/details';
  static const String player = '/player';
}

class DetailsArgs {
  const DetailsArgs({required this.movie, this.heroTag});
  final Movie movie;
  final Object? heroTag;
}

class PlayerArgs {
  const PlayerArgs({required this.movie, this.trailer = false});
  final Movie movie;
  final bool trailer;
}

class PlanArgs {
  const PlanArgs({this.popOnSave = false});

  /// True when opened from the profile: save then return instead of
  /// continuing into the app.
  final bool popOnSave;
}

/// Central route table with per-route transitions.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fade(const SplashScreen(), settings);
      case AppRoutes.onboarding:
        return _fade(const OnboardingScreen(), settings);
      case AppRoutes.login:
        return _fade(const LoginScreen(), settings);
      case AppRoutes.register:
        return _slideUp(const RegisterScreen(), settings);
      case AppRoutes.plans:
        final args = settings.arguments as PlanArgs? ?? const PlanArgs();
        return _slideUp(PlanScreen(args: args), settings);
      case AppRoutes.main:
        return _fade(const MainShell(), settings);
      case AppRoutes.details:
        final args = settings.arguments as DetailsArgs;
        return _slideUp(
          MovieDetailsScreen(movie: args.movie, heroTag: args.heroTag),
          settings,
        );
      case AppRoutes.player:
        final args = settings.arguments as PlayerArgs;
        return _fade(
          PlayerScreen(movie: args.movie, trailer: args.trailer),
          settings,
          duration: AppDurations.normal,
        );
      default:
        return _fade(const SplashScreen(), settings);
    }
  }

  static PageRoute<T> _fade<T>(
    Widget page,
    RouteSettings settings, {
    Duration duration = AppDurations.slow,
  }) => PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: AppDurations.normal,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );

  static PageRoute<T> _slideUp<T>(Widget page, RouteSettings settings) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: AppDurations.normal,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Convenience navigation helpers.
extension AppNavigation on BuildContext {
  Future<void> openDetails(Movie movie, {Object? heroTag}) =>
      Navigator.of(this).pushNamed(
        AppRoutes.details,
        arguments: DetailsArgs(movie: movie, heroTag: heroTag),
      );

  /// Plays a title. Trailers are free; the full title needs a plan or a
  /// rental, so without one this opens the details screen, which offers both.
  Future<void> openPlayer(Movie movie, {bool trailer = false}) {
    if (!trailer && !read<AuthController>().canWatch(movie.id)) {
      return openDetails(movie);
    }
    return Navigator.of(this).pushNamed(
      AppRoutes.player,
      arguments: PlayerArgs(movie: movie, trailer: trailer),
    );
  }
}
