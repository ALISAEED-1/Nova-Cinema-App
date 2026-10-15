import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/checkout_session.dart';
import '../../services/billing_service.dart';
import '../auth/auth_controller.dart';
import 'checkout_launcher.dart';

enum CheckoutResult {
  /// The server confirmed the payment; the account has been refreshed.
  paid,

  /// The provider reported a failure, such as a declined card.
  failed,

  /// The customer backed out before paying.
  canceled,

  /// They returned from the provider but the payment is not confirmed yet.
  pending,
}

/// One pass through a checkout, shared by plans and rentals: create the
/// session, show the provider's page, then ask the server how it ended. The
/// redirect back proves nothing on its own; only the server's view of the
/// session counts. [ApiException]s are left to the caller.
Future<(CheckoutResult, CheckoutSession)> runCheckout(
  BuildContext context,
  Future<CheckoutSession> Function(BillingService billing) start, {
  void Function()? onConfirming,
}) async {
  final billing = context.read<BillingService>();
  final auth = context.read<AuthController>();
  final launcher = context.read<CheckoutLauncher>();

  var session = await start(billing);
  CheckoutReturn? how;
  if (session.status == CheckoutStatus.open) {
    if (!context.mounted) return (CheckoutResult.canceled, session);
    how = await launcher.open(context, session);
    onConfirming?.call();
    // Even after a cancel, check: they may have paid just before closing.
    session = how == CheckoutReturn.returned
        ? await billing.waitForOutcome(session.id)
        : await billing.fetchSession(session.id);
  }

  switch (session.status) {
    case CheckoutStatus.paid:
      await auth.refreshAccount();
      return (CheckoutResult.paid, session);
    case CheckoutStatus.failed:
      return (CheckoutResult.failed, session);
    case CheckoutStatus.open:
      return (
        how == CheckoutReturn.returned
            ? CheckoutResult.pending
            : CheckoutResult.canceled,
        session,
      );
  }
}

/// A message for a session the provider reported as failed.
String checkoutFailureMessage(String? reason) => switch (reason) {
  'card_declined' =>
    'Your card was declined and nothing was charged. Try again or use another card.',
  'expired' => 'The checkout page expired before payment. Please try again.',
  'amount_mismatch' =>
    'The payment didn’t match the price, so it wasn’t accepted.',
  _ => 'The payment didn’t go through. Please try again.',
};

/// A message for a checkout that did not end in payment or failure.
String checkoutUnsettledMessage(CheckoutResult result) =>
    result == CheckoutResult.pending
    ? 'Your payment is still being confirmed. It will unlock as soon as it is.'
    : 'Checkout canceled. You have not been charged.';
