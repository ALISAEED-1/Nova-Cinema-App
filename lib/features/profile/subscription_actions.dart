import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../services/api/nova_api.dart';
import '../../services/billing_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_controller.dart';
import '../subscription/checkout_flow.dart';

/// One line summing up where a subscription stands, for the profile.
String describeSubscription(UserSubscription? sub) {
  if (sub == null) return 'Choose a plan to start watching';
  final price = '${sub.price.formatted}/month';
  if (sub.isEnded) {
    return sub.endedReason == 'payment_failed'
        ? 'Ended because the payment didn’t go through'
        : 'Ended';
  }
  if (sub.isPastDue) {
    return 'Payment overdue · watching until ${Formatters.date(sub.graceUntil!)}';
  }
  if (sub.cancelAtPeriodEnd) {
    return '$price · Ends ${Formatters.date(sub.currentPeriodEnd)}';
  }
  if (sub.renewsAutomatically) {
    final card = sub.paymentMethod == null ? '' : ' · ${sub.paymentMethod}';
    return '$price · ${sub.quality} · Renews ${Formatters.date(sub.currentPeriodEnd)}$card';
  }
  return '$price · ${sub.quality} · Pay by ${Formatters.date(sub.currentPeriodEnd)} to renew';
}

/// Whether the profile should ask the user to pay a bill now.
bool needsPaymentAlert(UserSubscription? sub) =>
    sub != null &&
    !sub.isEnded &&
    !sub.cancelAtPeriodEnd &&
    sub.openInvoice != null &&
    (sub.isPastDue || sub.openInvoice!.collection == 'manual');

/// "Your payment didn't go through … [Pay Rs 899 now]".
class BillingAlert extends StatefulWidget {
  const BillingAlert({super.key, required this.subscription});

  final UserSubscription subscription;

  @override
  State<BillingAlert> createState() => _BillingAlertState();
}

class _BillingAlertState extends State<BillingAlert> {
  bool _busy = false;

  /// Kept until this bill settles, so a retry reuses the same checkout.
  String? _attemptKey;

  Future<void> _pay(Invoice invoice) async {
    final key = _attemptKey ??= BillingService.newIdempotencyKey();
    setState(() => _busy = true);
    try {
      final (result, session) = await runCheckout(
        context,
        (billing) =>
            billing.startRenewalCheckout(invoice.id, idempotencyKey: key),
      );
      if (!mounted) return;
      switch (result) {
        case CheckoutResult.paid:
          _attemptKey = null;
          showAppSnackBar(
            context,
            'Paid. Your plan runs until ${Formatters.date(invoice.periodEnd)}.',
            icon: Icons.check_rounded,
          );
        case CheckoutResult.failed:
          _attemptKey = null;
          showAppSnackBar(
            context,
            checkoutFailureMessage(session.failureReason),
            isError: true,
          );
        case CheckoutResult.canceled || CheckoutResult.pending:
          showAppSnackBar(context, checkoutUnsettledMessage(result));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, isError: true);
      // The bill may have been settled meanwhile (an automatic retry).
      await context.read<AuthController>().refreshAccount();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final invoice = sub.openInvoice!;
    final text = Theme.of(context).textTheme;
    final overdue = sub.isPastDue;
    final amount = invoice.amount.formatted;

    final String title;
    final String message;
    if (overdue && invoice.lastError != 'awaiting_payment') {
      title = 'Your payment didn’t go through';
      message =
          'We couldn’t charge ${sub.paymentMethod ?? 'your card'}. Pay $amount by '
          '${Formatters.date(sub.graceUntil!)} to keep watching.';
    } else if (overdue) {
      title = 'Your plan renewal is due';
      message =
          'Pay $amount by ${Formatters.date(sub.graceUntil!)} to keep watching.';
    } else {
      title = 'Renew your plan';
      message =
          'Your plan renews on ${Formatters.date(invoice.periodStart)}. '
          'Pay $amount to keep watching.';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: overdue ? const Color(0x33E50914) : AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: overdue ? const Color(0x80E50914) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                overdue ? Icons.error_outline_rounded : Icons.event_repeat,
                color: overdue ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Pay $amount now',
            loading: _busy,
            onPressed: () => _pay(invoice),
          ),
        ],
      ),
    );
  }
}

/// Asks before canceling; an overdue plan ends at once, a paid one at period end.
Future<void> confirmCancelPlan(
  BuildContext context,
  UserSubscription sub,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Cancel your plan?'),
      content: Text(
        sub.isPastDue
            ? 'Your plan ends now and the overdue bill is cancelled.'
            : 'You can keep watching until ${Formatters.date(sub.currentPeriodEnd)}. '
                  'After that your plan won’t renew.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Keep plan'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('Cancel plan'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await _accountAction(
    context,
    (auth) => auth.cancelPlan(),
    sub.isPastDue
        ? 'Your plan has ended'
        : 'Plan canceled. Watch until ${Formatters.date(sub.currentPeriodEnd)}',
  );
}

Future<void> resumePlan(BuildContext context) => _accountAction(
  context,
  (auth) => auth.resumePlan(),
  'Your plan will keep renewing',
);

Future<void> _accountAction(
  BuildContext context,
  Future<void> Function(AuthController auth) action,
  String done,
) async {
  try {
    await action(context.read<AuthController>());
    if (context.mounted) {
      showAppSnackBar(context, done, icon: Icons.check_rounded);
    }
  } on ApiException catch (e) {
    if (context.mounted) showAppSnackBar(context, e.message, isError: true);
  }
}

/// Past bills, newest first.
Future<void> showBillingHistory(BuildContext context) {
  final invoices = context.read<BillingService>().fetchInvoices();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: FutureBuilder<List<Invoice>>(
        future: invoices,
        builder: (context, snapshot) {
          final text = Theme.of(context).textTheme;
          final Widget body;
          if (snapshot.hasError) {
            body = Text(
              'Couldn’t load your bills. ${snapshot.error}',
              style: text.bodyMedium,
            );
          } else if (!snapshot.hasData) {
            body = const Center(child: CircularProgressIndicator());
          } else if (snapshot.data!.isEmpty) {
            body = Text(
              'No bills yet. Each renewal bill appears a few days before it’s due.',
              style: text.bodyMedium,
            );
          } else {
            body = Column(
              children: [
                for (final invoice in snapshot.data!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(invoice.amount.formatted),
                    subtitle: Text(
                      '${Formatters.date(invoice.periodStart)} – '
                      '${Formatters.date(invoice.periodEnd)}',
                    ),
                    trailing: Text(
                      _invoiceStatus(invoice.status),
                      style: text.labelMedium,
                    ),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Billing history', style: text.headlineMedium),
                const SizedBox(height: AppSpacing.md),
                body,
              ],
            ),
          );
        },
      ),
    ),
  );
}

String _invoiceStatus(String status) => switch (status) {
  'paid' => 'PAID',
  'open' => 'DUE',
  'void' => 'CANCELLED',
  _ => 'UNPAID',
};

/// Development servers only: move this account's billing dates forward to
/// watch a renewal, a failed payment or the end of a grace period happen.
Future<void> showSkipAhead(BuildContext context) async {
  final days = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(
              'Skip ahead (test server)',
              style: Theme.of(sheet).textTheme.headlineMedium,
            ),
          ),
          for (final (days, label) in const [
            (1, '1 day'),
            (7, '1 week'),
            (30, '30 days'),
          ])
            ListTile(
              title: Text(label),
              onTap: () => Navigator.of(sheet).pop(days),
            ),
        ],
      ),
    ),
  );
  if (days == null || !context.mounted) return;
  await _accountAction(
    context,
    (auth) => auth.skipAhead(days),
    'Moved $days day${days == 1 ? '' : 's'} ahead',
  );
}
