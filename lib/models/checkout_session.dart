import 'money.dart';

enum CheckoutStatus { open, paid, failed }

/// A payment attempt for a plan, created by the nova-pay backend.
class CheckoutSession {
  const CheckoutSession({
    required this.id,
    required this.status,
    required this.planId,
    required this.amount,
    required this.returnUrl,
    this.checkoutUrl,
    this.failureReason,
  });

  final String id;
  final CheckoutStatus status;
  final String planId;
  final Money amount;

  /// The provider's hosted payment page.
  final String? checkoutUrl;

  /// The provider sends the customer here when they finish; the checkout
  /// screen closes as soon as it sees this URL.
  final String returnUrl;
  final String? failureReason;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        id: json['id'] as String,
        status: CheckoutStatus.values.byName(json['status'] as String),
        planId: json['planId'] as String,
        amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
        checkoutUrl: json['checkoutUrl'] as String?,
        returnUrl: json['returnUrl'] as String,
        failureReason: json['failureReason'] as String?,
      );
}
