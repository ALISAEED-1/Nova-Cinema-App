import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../models/checkout_session.dart';
import '../../models/subscription_plan.dart';
import '../../navigation/app_router.dart';
import '../../services/api/nova_api.dart';
import '../../services/billing_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/nova_logo.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_widgets.dart';
import '../auth/auth_controller.dart';
import 'checkout_launcher.dart';

enum _Step { idle, opening, confirming }

/// Plan picker and checkout — shown after sign-in (as on the web) and from the
/// profile. Prices come from the server in the user's currency; paying opens
/// the provider's hosted checkout, and the plan unlocks only once the server
/// has confirmed the payment.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.args});

  final PlanArgs args;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  PlanCatalog? _catalog;
  List<BillingCountry> _countries = const [];
  String? _loadError;
  String? _selectedId;
  _Step _step = _Step.idle;

  /// One idempotency key per plan, kept until that purchase settles, so a
  /// retry after a dropped connection reuses the same checkout.
  final Map<String, String> _attemptKeys = {};

  @override
  void initState() {
    super.initState();
    _selectedId = context.read<AuthController>().user?.planId;
    _load();
  }

  Future<void> _load() async {
    final billing = context.read<BillingService>();
    setState(() {
      _catalog = null;
      _loadError = null;
    });
    try {
      final catalog = await billing.fetchPlans();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        if (catalog.byId(_selectedId) == null) {
          _selectedId = (catalog.byId('standard') ?? catalog.plans.first).id;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
    if (_countries.isEmpty) {
      try {
        final countries = await billing.fetchCountries();
        if (mounted) setState(() => _countries = countries);
      } on ApiException {
        // The picker falls back to country codes.
      }
    }
  }

  Future<void> _checkout() async {
    final plan = _catalog?.byId(_selectedId);
    if (plan == null) return;
    final billing = context.read<BillingService>();
    final auth = context.read<AuthController>();
    final launcher = context.read<CheckoutLauncher>();
    final key = _attemptKeys[plan.id] ??= BillingService.newIdempotencyKey();

    setState(() => _step = _Step.opening);
    try {
      var session = await billing.startCheckout(plan.id, idempotencyKey: key);
      CheckoutReturn? how;
      if (session.status == CheckoutStatus.open) {
        if (!mounted) return;
        how = await launcher.open(context, session);
        if (!mounted) return;
        setState(() => _step = _Step.confirming);
        // Even after a cancel, check: they may have paid just before closing.
        session = how == CheckoutReturn.returned
            ? await billing.waitForOutcome(session.id)
            : await billing.fetchSession(session.id);
      }
      if (!mounted) return;

      switch (session.status) {
        case CheckoutStatus.paid:
          _attemptKeys.remove(plan.id);
          await auth.refreshAccount();
          if (mounted) _finish(plan);
        case CheckoutStatus.failed:
          _attemptKeys.remove(plan.id);
          showAppSnackBar(
            context,
            _failureMessage(session.failureReason),
            icon: Icons.error_outline_rounded,
            isError: true,
          );
        case CheckoutStatus.open:
          showAppSnackBar(
            context,
            how == CheckoutReturn.returned
                ? 'Your payment is still being confirmed. Your plan updates as soon as it is.'
                : 'Checkout canceled. You have not been charged.',
            icon: Icons.info_outline_rounded,
          );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.message,
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _step = _Step.idle);
    }
  }

  void _finish(SubscriptionPlan plan) {
    if (widget.args.popOnSave) {
      showAppSnackBar(
        context,
        'You’re on ${plan.name} now',
        icon: Icons.check_rounded,
      );
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
    }
  }

  static String _failureMessage(String? reason) => switch (reason) {
    'card_declined' =>
      'Your card was declined and nothing was charged. Try again or use another card.',
    'amount_mismatch' =>
      'The payment didn’t match the plan price, so it wasn’t accepted.',
    _ => 'The payment didn’t go through. Please try again.',
  };

  Future<void> _changeCountry() async {
    final auth = context.read<AuthController>();
    final current = auth.user?.country;
    if (_countries.isEmpty) return;

    final picked = await showModalBottomSheet<BillingCountry>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      // Size to the list, scrolling when it is taller than the screen allows.
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Billing country',
                  style: Theme.of(sheet).textTheme.headlineMedium,
                ),
              ),
              for (final country in _countries)
                ListTile(
                  title: Text(country.name),
                  subtitle: Text('Prices in ${country.currency}'),
                  trailing: country.code == current
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheet).pop(country),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked.code == current || !mounted) return;

    try {
      await auth.updateCountry(picked.code);
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
      return;
    }
    _attemptKeys.clear();
    await _load();
  }

  String _countryLabel(PlanCatalog catalog) {
    for (final c in _countries) {
      if (c.code == catalog.country) return '${c.name} · ${catalog.currency}';
    }
    return '${catalog.country} · ${catalog.currency}';
  }

  Widget _card(SubscriptionPlan plan, String? currentPlanId) {
    return _PlanCard(
      plan: plan,
      selected: plan.id == _selectedId,
      current: plan.id == currentPlanId,
      onTap: _step == _Step.idle
          ? () => setState(() => _selectedId = plan.id)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final responsive = Responsive.of(context);
    final currentPlanId = context.watch<AuthController>().user?.planId;
    final catalog = _catalog;
    final selected = catalog?.byId(_selectedId);

    final Widget plans;
    if (_loadError != null) {
      plans = SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorWidget(
          title: 'Couldn’t load plans',
          message: _loadError!,
          onRetry: _load,
        ),
      );
    } else if (catalog == null) {
      plans = const SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingWidget(),
      );
    } else {
      plans = SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.md,
        ),
        // Side by side on wide screens, stacked otherwise. Cards size to
        // their content in both layouts.
        sliver: SliverToBoxAdapter(
          child: responsive.isTablet && responsive.isLandscape
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < catalog.plans.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.md),
                        Expanded(child: _card(catalog.plans[i], currentPlanId)),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < catalog.plans.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _card(catalog.plans[i], currentPlanId),
                    ],
                  ],
                ),
        ),
      );
    }

    final String label;
    VoidCallback? onPressed = _checkout;
    if (selected == null) {
      label = 'Choose a plan';
      onPressed = null;
    } else if (selected.id == currentPlanId) {
      label = 'This is your current plan';
      onPressed = null;
    } else if (_step == _Step.confirming) {
      label = 'Confirming payment…';
    } else {
      final verb = currentPlanId == null ? 'Continue with' : 'Switch to';
      label = '$verb ${selected.name} · ${selected.price.formatted}/mo';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.lg,
                      AppSpacing.gutter,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.args.popOnSave)
                                CircleIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  filled: false,
                                  onPressed: () => Navigator.of(context).pop(),
                                )
                              else
                                const NovaLogo(size: 22),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text('Choose your plan', style: text.displayMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Watch all you want. Recommendations just for you. '
                            'Change or cancel your plan anytime.',
                            style: text.bodyMedium,
                          ),
                          if (catalog != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _CountryChip(
                              label: _countryLabel(catalog),
                              onTap: _countries.isEmpty || _step != _Step.idle
                                  ? null
                                  : _changeCountry,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  plans,
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: PrimaryButton(
                label: label,
                loading: _step == _Step.opening,
                onPressed: _step == _Step.idle ? onPressed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Billing country: Pakistan · PKR" with a tap to change it.
class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.public_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Billing country: $label',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final badge = current ? 'Current plan' : plan.badge;
    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(plan.name, style: text.headlineMedium),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                badge.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedContainer(
                      duration: AppDurations.fast,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.borderStrong,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                RichText(
                  text: TextSpan(
                    style: text.headlineLarge,
                    children: [
                      TextSpan(text: plan.price.formatted),
                      TextSpan(text: ' /month', style: text.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final feature in plan.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(feature, style: text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
