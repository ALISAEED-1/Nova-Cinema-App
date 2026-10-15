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
    required this.price,
    required this.currentPeriodEnd,
  });

  final String id;
  final String planId;
  final String planName;
  final String quality;

  /// `active`, `past_due`, `canceled` or `expired`.
  final String status;
  final Money price;
  final DateTime currentPeriodEnd;

  bool get isActive => status == 'active';

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      UserSubscription(
        id: json['id'] as String,
        planId: json['planId'] as String,
        planName: json['planName'] as String,
        quality: json['quality'] as String,
        status: json['status'] as String,
        price: Money.fromJson(json['price'] as Map<String, dynamic>),
        currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'planId': planId,
    'planName': planName,
    'quality': quality,
    'status': status,
    'price': price.toJson(),
    'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
  };
}
