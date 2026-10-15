import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../navigation/app_router.dart';
import '../../widgets/nova_logo.dart';
import '../../services/onboarding_service.dart';
import '../auth/auth_controller.dart';
import '../home/catalog_controller.dart';

/// Brand reveal while the session is restored and the catalogue loads.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minimumDisplay = Duration(milliseconds: 1500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.35,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthController>();
    final catalog = context.read<CatalogController>();
    final onboarding = context.read<OnboardingService>();

    await Future.wait([
      Future<void>.delayed(_minimumDisplay),
      _waitForCatalog(catalog),
    ]);
    if (!mounted) return;

    final String next;
    if (!onboarding.hasSeen()) {
      next = AppRoutes.onboarding;
    } else if (!auth.isAuthenticated) {
      next = AppRoutes.login;
    } else {
      // Signed-in users without a plan still browse; titles they can't watch
      // offer a plan or a rental.
      next = AppRoutes.main;
    }
    Navigator.of(context).pushReplacementNamed(next);
  }

  /// Resolves once the catalogue is ready or has failed — the home screen
  /// handles the error state with a retry, so a failure must not block here.
  Future<void> _waitForCatalog(CatalogController catalog) {
    if (catalog.state == LoadState.ready || catalog.state == LoadState.error) {
      return Future.value();
    }
    final completer = Completer<void>();
    void listener() {
      if (catalog.state == LoadState.ready ||
          catalog.state == LoadState.error) {
        catalog.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    catalog.addListener(listener);
    return completer.future;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const NovaLogo(size: 36),
          ),
        ),
      ),
    );
  }
}
