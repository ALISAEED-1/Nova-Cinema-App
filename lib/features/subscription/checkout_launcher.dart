import 'package:flutter/material.dart';

import '../../models/checkout_session.dart';
import 'checkout_webview_screen.dart';

/// How the customer left the provider's checkout page.
enum CheckoutReturn {
  /// The provider sent them back to the return URL after paying or declining.
  returned,

  /// They chose Cancel on the provider's page.
  canceled,

  /// They closed the checkout screen themselves.
  dismissed,
}

/// Shows the provider's hosted checkout. Injectable so tests can stand in for
/// the web view.
abstract class CheckoutLauncher {
  Future<CheckoutReturn> open(BuildContext context, CheckoutSession session);
}

class WebViewCheckoutLauncher implements CheckoutLauncher {
  const WebViewCheckoutLauncher();

  @override
  Future<CheckoutReturn> open(
    BuildContext context,
    CheckoutSession session,
  ) async {
    final result = await Navigator.of(context).push<CheckoutReturn>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CheckoutWebViewScreen(session: session),
      ),
    );
    return result ?? CheckoutReturn.dismissed;
  }
}
