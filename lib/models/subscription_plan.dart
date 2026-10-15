/// Subscription tiers from the web app's `subscription.html`.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.quality,
    required this.features,
    this.badge,
  });

  final String id;
  final String name;
  final double monthlyPrice;
  final String quality;
  final List<String> features;
  final String? badge;

  static const List<SubscriptionPlan> all = [
    SubscriptionPlan(
      id: 'basic',
      name: 'Basic',
      monthlyPrice: 9.99,
      quality: 'HD',
      features: [
        'HD (720p) quality',
        'Watch on 1 device at a time',
        'Watch on your laptop, TV, phone and tablet',
        'Unlimited movies and TV shows',
      ],
    ),
    SubscriptionPlan(
      id: 'standard',
      name: 'Standard',
      monthlyPrice: 14.99,
      quality: 'Full HD',
      badge: 'Most Popular',
      features: [
        'Full HD (1080p) quality',
        'Watch on 2 devices at a time',
        'Watch on your laptop, TV, phone and tablet',
        'Unlimited movies and TV shows',
        'Download on 2 devices',
      ],
    ),
    SubscriptionPlan(
      id: 'premium',
      name: 'Premium',
      monthlyPrice: 19.99,
      quality: '4K + HDR',
      features: [
        '4K (Ultra HD) + HDR quality',
        'Watch on 4 devices at a time',
        'Watch on your laptop, TV, phone and tablet',
        'Unlimited movies and TV shows',
        'Download on 4 devices',
        'Nova Cinema spatial audio',
      ],
    ),
  ];

  static SubscriptionPlan? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
