import 'money.dart';

enum CheckoutStatus { open, paid, failed }

enum CheckoutKind { subscription, rental }

/// A payment attempt for a plan or a rental, created by the nova-pay backend.
class CheckoutSession {
  const CheckoutSession({
    required this.id,
    required this.kind,
    required this.status,
    required this.amount,
    required this.returnUrl,
    this.planId,
    this.movieId,
    this.checkoutUrl,
    this.failureReason,
  });

  final String id;
  final CheckoutKind kind;
  final CheckoutStatus status;
  final Money amount;

  /// Set for a subscription checkout.
  final String? planId;

  /// Set for a rental checkout.
  final String? movieId;

  /// The provider's hosted payment page.
  final String? checkoutUrl;

  /// The provider sends the customer here when they finish; the checkout
  /// screen closes as soon as it sees this URL.
  final String returnUrl;
  final String? failureReason;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        id: json['id'] as String,
        kind: CheckoutKind.values.byName(
          json['kind'] as String? ?? 'subscription',
        ),
        status: CheckoutStatus.values.byName(json['status'] as String),
        planId: json['planId'] as String?,
        movieId: json['movieId'] as String?,
        amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
        checkoutUrl: json['checkoutUrl'] as String?,
        returnUrl: json['returnUrl'] as String,
        failureReason: json['failureReason'] as String?,
      );
}

/// What renting one title costs, in the user's currency.
class RentalOffer {
  const RentalOffer({required this.hours, required this.price});

  final int hours;
  final Money price;

  factory RentalOffer.fromJson(Map<String, dynamic> json) => RentalOffer(
    hours: (json['hours'] as num).toInt(),
    price: Money.fromJson(json['price'] as Map<String, dynamic>),
  );
}
