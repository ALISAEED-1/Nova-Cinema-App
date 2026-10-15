import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/subscription_plan.dart';
import '../../navigation/app_router.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/nova_logo.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_controller.dart';

/// Plan picker — shown after sign-in (as on the web) and from the profile.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.args});

  final PlanArgs args;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late String _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = context.read<AuthController>().user?.planId ?? 'standard';
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    await context.read<AuthController>().selectPlan(_selectedId);
    if (!mounted) return;
    setState(() => _saving = false);

    if (widget.args.popOnSave) {
      showAppSnackBar(context, 'Plan updated', icon: Icons.check_rounded);
      Navigator.of(context).pop();
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
    }
  }

  Widget _card(int index) {
    final plan = SubscriptionPlan.all[index];
    return _PlanCard(
      plan: plan,
      selected: plan.id == _selectedId,
      onTap: () => setState(() => _selectedId = plan.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final responsive = Responsive.of(context);
    final selected = SubscriptionPlan.byId(_selectedId)!;

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
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                      vertical: AppSpacing.md,
                    ),
                    // Side by side on wide screens, stacked otherwise. Cards
                    // size to their content in both layouts.
                    sliver: SliverToBoxAdapter(
                      child: responsive.isTablet && responsive.isLandscape
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0;
                                      i < SubscriptionPlan.all.length;
                                      i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: AppSpacing.md),
                                    Expanded(child: _card(i)),
                                  ],
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (var i = 0;
                                    i < SubscriptionPlan.all.length;
                                    i++) ...[
                                  if (i > 0)
                                    const SizedBox(height: AppSpacing.md),
                                  _card(i),
                                ],
                              ],
                            ),
                    ),
                  ),
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
                label: widget.args.popOnSave
                    ? 'Switch to ${selected.name}'
                    : 'Continue with ${selected.name} · ${Formatters.price(selected.monthlyPrice)}/mo',
                loading: _saving,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                          if (plan.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                plan.badge!.toUpperCase(),
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
                        color: selected ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.borderStrong,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                RichText(
                  text: TextSpan(
                    style: text.headlineLarge,
                    children: [
                      TextSpan(text: Formatters.price(plan.monthlyPrice)),
                      TextSpan(
                        text: ' /month',
                        style: text.bodyMedium,
                      ),
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
                        Expanded(
                          child: Text(feature, style: text.bodyMedium),
                        ),
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
