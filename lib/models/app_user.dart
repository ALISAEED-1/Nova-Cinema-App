import 'money.dart';

/// The signed-in user and their subscription, as the nova-pay backend reports
/// them. The server decides what the user has paid for; the app only caches it.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.country,
    required this.currency,
    this.subscription,
    this.rentals = const [],
  });

  final String id;
  final String name;
  final String email;

  /// Billing country (ISO code) and the currency it implies.
  final String country;
  final String currency;

  final UserSubscription? subscription;

  /// Titles rented and still within their watch window, per the server.
  final List<Rental> rentals;

  /// The plan the user may watch with right now, or null.
  String? get planId =>
      subscription?.isActive == true ? subscription!.planId : null;

  bool get hasActivePlan => planId != null;

  /// The rental that lets the user watch [movieId] now, if any.
  Rental? activeRentalFor(String movieId, {DateTime? now}) {
    final at = now ?? DateTime.now();
    for (final r in rentals) {
      if (r.movieId == movieId && r.expiresAt.isAfter(at)) return r;
    }
    return null;
  }

  /// Rentals that have not run out yet.
  List<Rental> activeRentals({DateTime? now}) {
    final at = now ?? DateTime.now();
    return rentals.where((r) => r.expiresAt.isAfter(at)).toList();
  }

  /// Whether the user may play the full title: a plan covers everything, a
  /// rental covers one title for its window.
  bool canWatch(String movieId) =>
      hasActivePlan || activeRentalFor(movieId) != null;

  factory AppUser.fromAccountJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final subscription = json['subscription'] as Map<String, dynamic>?;
    return AppUser(
      id: user['id'] as String,
      name: user['name'] as String? ?? '',
      email: user['email'] as String,
      country: user['country'] as String,
      currency: user['currency'] as String,
      subscription: subscription == null
          ? null
          : UserSubscription.fromJson(subscription),
      rentals: [
        for (final r in json['rentals'] as List? ?? const [])
          Rental.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toAccountJson() => {
    'user': {
      'id': id,
      'name': name,
      'email': email,
      'country': country,
      'currency': currency,
    },
    'subscription': subscription?.toJson(),
    'rentals': [for (final r in rentals) r.toJson()],
  };
}

/// One title rented for a limited window.
class Rental {
  const Rental({
    required this.movieId,
    required this.title,
    required this.expiresAt,
  });

  final String movieId;
  final String title;
  final DateTime expiresAt;

  factory Rental.fromJson(Map<String, dynamic> json) => Rental(
    movieId: json['movieId'] as String,
    title: json['title'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'title': title,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

class UserSubscription {
  const UserSubscription({
    required this.id,
    required this.planId,
    required this.planName,
    required this.quality,
    required this.status,
    required this.hasAccess,
    required this.price,
    required this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.graceUntil,
    this.endedReason,
    this.renewal = 'manual',
    this.paymentMethod,
    this.openInvoice,
  });

  final String id;
  final String planId;
  final String planName;
  final String quality;

  /// `active`, `past_due` or `canceled`.
  final String status;

  /// Whether the plan lets the user watch now, as decided by the server
  /// (active, or past due within the grace period).
  final bool hasAccess;
  final Money price;
  final DateTime currentPeriodEnd;

  /// Canceled by the user: ends at [currentPeriodEnd] instead of renewing.
  final bool cancelAtPeriodEnd;

  /// While past due: when access stops unless the bill is paid.
  final DateTime? graceUntil;

  /// Why a canceled plan ended: `canceled` or `payment_failed`.
  final String? endedReason;

  /// `automatic` charges a saved card; `manual` means paying each period.
  final String renewal;

  /// "Visa •••• 4242", "Mobile wallet".
  final String? paymentMethod;

  /// The next or overdue bill, if one is waiting.
  final Invoice? openInvoice;

  bool get isActive => hasAccess;
  bool get isPastDue => status == 'past_due';
  bool get isEnded => status == 'canceled';
  bool get renewsAutomatically => renewal == 'automatic';

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    final grace = json['graceUntil'] as String?;
    final invoice = json['openInvoice'] as Map<String, dynamic>?;
    return UserSubscription(
      id: json['id'] as String,
      planId: json['planId'] as String,
      planName: json['planName'] as String,
      quality: json['quality'] as String,
      status: status,
      // Accounts cached by an older version of the app lack this field.
      hasAccess: json['hasAccess'] as bool? ?? status == 'active',
      price: Money.fromJson(json['price'] as Map<String, dynamic>),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      graceUntil: grace == null ? null : DateTime.parse(grace),
      endedReason: json['endedReason'] as String?,
      renewal: json['renewal'] as String? ?? 'manual',
      paymentMethod: json['paymentMethod'] as String?,
      openInvoice: invoice == null ? null : Invoice.fromJson(invoice),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'planId': planId,
    'planName': planName,
    'quality': quality,
    'status': status,
    'hasAccess': hasAccess,
    'price': price.toJson(),
    'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
    'cancelAtPeriodEnd': cancelAtPeriodEnd,
    'graceUntil': graceUntil?.toIso8601String(),
    'endedReason': endedReason,
    'renewal': renewal,
    'paymentMethod': paymentMethod,
    'openInvoice': openInvoice?.toJson(),
  };
}

/// One period's bill.
class Invoice {
  const Invoice({
    required this.id,
    required this.status,
    required this.collection,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    this.attemptCount = 0,
    this.lastError,
    this.nextAttemptAt,
    this.paidAt,
  });

  final String id;

  /// `open`, `paid`, `void` or `uncollectible`.
  final String status;

  /// `automatic` (a saved card is charged) or `manual` (the user pays).
  final String collection;
  final Money amount;

  /// The period the bill pays for; [periodStart] is when it is due.
  final DateTime periodStart;
  final DateTime periodEnd;
  final int attemptCount;
  final String? lastError;
  final DateTime? nextAttemptAt;
  final DateTime? paidAt;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    return Invoice(
      id: json['id'] as String,
      status: json['status'] as String,
      collection: json['collection'] as String,
      amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      nextAttemptAt: date('nextAttemptAt'),
      paidAt: date('paidAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'collection': collection,
    'amount': amount.toJson(),
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'attemptCount': attemptCount,
    'lastError': lastError,
    'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
  };
}
