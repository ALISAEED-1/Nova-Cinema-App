/// An amount as the server sends it: integer minor units, a currency code and
/// a ready-made display string. The app never does arithmetic on prices.
class Money {
  const Money({
    required this.amountMinor,
    required this.currency,
    required this.formatted,
  });

  final int amountMinor;
  final String currency;

  /// e.g. "$9.99" or "Rs 899".
  final String formatted;

  factory Money.fromJson(Map<String, dynamic> json) => Money(
        amountMinor: (json['amountMinor'] as num).toInt(),
        currency: json['currency'] as String,
        formatted: json['formatted'] as String,
      );

  Map<String, dynamic> toJson() => {
        'amountMinor': amountMinor,
        'currency': currency,
        'formatted': formatted,
      };
}
