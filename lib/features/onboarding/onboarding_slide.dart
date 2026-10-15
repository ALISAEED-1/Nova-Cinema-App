/// Copy and artwork for one onboarding page.
class OnboardingSlide {
  const OnboardingSlide({
    required this.image,
    required this.titleLead,
    required this.titleAccent,
    required this.body,
    required this.action,
  });

  final String image;

  /// First part of the heading, rendered in white.
  final String titleLead;

  /// Closing word(s), rendered in the brand red.
  final String titleAccent;
  final String body;

  /// Label on the primary button for this page.
  final String action;

  static const List<OnboardingSlide> all = [
    OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_1.jpg',
      titleLead: 'Discover',
      titleAccent: 'Movies',
      body: 'Explore thousands of movies and\nfind something worth watching.',
      action: 'Next',
    ),
    OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_2.jpg',
      titleLead: 'Made For Your',
      titleAccent: 'Taste',
      body: 'Nova Cinema learns what you love and\nbrings the right stories closer to you.',
      action: 'Next',
    ),
    OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_3.jpg',
      titleLead: 'Your Cinema,',
      titleAccent: 'Anywhere',
      body: 'Enjoy your favorite stories whenever\nyou want, wherever you are.',
      action: 'Get Started',
    ),
  ];
}
