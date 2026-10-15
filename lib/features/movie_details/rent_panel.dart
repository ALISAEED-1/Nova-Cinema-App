import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/checkout_session.dart';
import '../../models/movie.dart';
import '../../navigation/app_router.dart';
import '../../services/api/nova_api.dart';
import '../../services/billing_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_controller.dart';
import '../subscription/checkout_flow.dart';

/// Shown in place of "Watch Now" when the user has neither a plan nor a
/// rental for this title: rent it for 48 hours, or go to the plans.
class RentPanel extends StatefulWidget {
  const RentPanel({super.key, required this.movie});

  final Movie movie;

  @override
  State<RentPanel> createState() => _RentPanelState();
}

class _RentPanelState extends State<RentPanel> {
  RentalOffer? _offer;
  bool _busy = false;

  /// Kept until this rental settles, so a retry reuses the same checkout.
  String? _attemptKey;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    try {
      final offer = await context.read<BillingService>().fetchRentalOffer();
      if (mounted) setState(() => _offer = offer);
    } on ApiException {
      // The button works without a price; the checkout page shows it.
    }
  }

  Future<void> _rent() async {
    final movie = widget.movie;
    final key = _attemptKey ??= BillingService.newIdempotencyKey();
    setState(() => _busy = true);
    try {
      final (result, session) = await runCheckout(
        context,
        (billing) => billing.startRentalCheckout(
          movie.id,
          title: movie.title,
          idempotencyKey: key,
        ),
      );
      if (!mounted) return;
      switch (result) {
        case CheckoutResult.paid:
          _attemptKey = null;
          showAppSnackBar(
            context,
            'Rented. ${movie.title} is yours for ${_offer?.hours ?? 48} hours.',
            icon: Icons.check_rounded,
          );
        case CheckoutResult.failed:
          _attemptKey = null;
          showAppSnackBar(
            context,
            checkoutFailureMessage(session.failureReason),
            icon: Icons.error_outline_rounded,
            isError: true,
          );
        case CheckoutResult.canceled || CheckoutResult.pending:
          showAppSnackBar(
            context,
            checkoutUnsettledMessage(result),
            icon: Icons.info_outline_rounded,
          );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, isError: true);
      // "Already rented" or "covered by plan": the account is out of date.
      if (e.statusCode == 409) {
        await context.read<AuthController>().refreshAccount();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: offer == null
              ? 'Rent for 48h'
              : 'Rent for ${offer.hours}h · ${offer.price.formatted}',
          icon: Icons.local_activity_outlined,
          light: true,
          loading: _busy,
          onPressed: _rent,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pushNamed(
                  AppRoutes.plans,
                  arguments: const PlanArgs(popOnSave: true),
                ),
          child: const Text('Or watch everything with a plan'),
        ),
      ],
    );
  }
}

/// "Rented · 47h left" under the play button of a rented title.
class RentalBadge extends StatelessWidget {
  const RentalBadge({super.key, required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          'Rented · ${Formatters.timeLeft(rental.expiresAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
