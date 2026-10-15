import 'money.dart';

/// A plan as offered by the nova-pay backend, priced in the user's currency.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.quality,
    required this.features,
    required this.price,
    this.badge,
  });

  final String id;
  final String name;
  final String quality;
  final List<String> features;
  final Money price;
  final String? badge;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        quality: json['quality'] as String,
        features: (json['features'] as List).cast<String>(),
        price: Money.fromJson(json['price'] as Map<String, dynamic>),
        badge: json['badge'] as String?,
      );
}

/// The plans on offer for the user's billing country.
class PlanCatalog {
  const PlanCatalog({
    required this.country,
    required this.currency,
    required this.plans,
  });

  final String country;
  final String currency;
  final List<SubscriptionPlan> plans;

  SubscriptionPlan? byId(String? id) {
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory PlanCatalog.fromJson(Map<String, dynamic> json) => PlanCatalog(
        country: json['country'] as String,
        currency: json['currency'] as String,
        plans: (json['plans'] as List)
            .map((p) => SubscriptionPlan.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// A country the user can bill from, with the currency it implies.
class BillingCountry {
  const BillingCountry({
    required this.code,
    required this.name,
    required this.currency,
  });

  final String code;
  final String name;
  final String currency;

  factory BillingCountry.fromJson(Map<String, dynamic> json) => BillingCountry(
        code: json['country'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
      );
}
