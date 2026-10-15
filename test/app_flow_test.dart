import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_cinema/app.dart';
import 'package:nova_cinema/features/profile/profile_screen.dart';
import 'package:nova_cinema/features/subscription/checkout_launcher.dart';
import 'package:nova_cinema/services/catalog_service.dart';
import 'package:nova_cinema/services/local_store.dart';
import 'package:nova_cinema/services/onboarding_service.dart';
import 'package:nova_cinema/widgets/movie_card.dart';
import 'package:nova_cinema/widgets/nova_logo.dart';
import 'package:nova_cinema/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_nova_api.dart';

/// Serves the real catalogue JSON from memory so the widget test does not
/// depend on asynchronous asset I/O inside the fake-async test zone.
class _JsonBundle extends CachingAssetBundle {
  _JsonBundle(this.json);
  final String json;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}

void main() {
  late String catalogJson;
  late FakeNovaApi api;
  late FakeCheckoutLauncher checkout;

  setUpAll(() {
    catalogJson = File('assets/data/catalog.json').readAsStringSync();
  });

  setUp(() {
    api = FakeNovaApi();
    checkout = FakeCheckoutLauncher(api);
  });

  /// Starts the app with [prefs] as the device's saved state.
  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefs = const {'novaOnboardingSeen': true},
    String? catalog,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(
          bundle: _JsonBundle(catalog ?? catalogJson),
        ),
        api: api,
        checkoutLauncher: checkout,
      ),
    );
    // Splash holds for 1.5s minimum.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> launch(WidgetTester tester) => pumpApp(tester);

  Finder navItem(String label) => find.widgetWithText(InkResponse, label);

  /// From home, opens the plan screen through Profile › Subscription.
  Future<void> openPlans(WidgetTester tester) async {
    await tester.tap(navItem('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No plan selected'));
    await tester.pumpAndSettle();
  }

  /// Saved state for a signed-in user, optionally already subscribed.
  Map<String, Object> signedIn({String? planId, String country = 'US'}) {
    api.seedAccount(email: 'ali@example.com', planId: planId, country: country);
    return {
      'novaOnboardingSeen': true,
      'novaSession': api.sessionJsonFor('ali@example.com'),
    };
  }

  testWidgets('sign up → choose plan → browse → list → sign out', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    // --- Register -------------------------------------------------------
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Join the experience'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ali');
    await tester.enterText(fields.at(1), 'ali@example.com');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.tap(find.text('I agree to the Terms & Conditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();

    // Registering signs the account in and goes straight to plan selection,
    // with prices from the server in the account's currency.
    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text(r'$19.99 /month', findRichText: true), findsOneWidget);

    // Paying opens the provider's checkout; the plan unlocks once the
    // server reports the session paid.
    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(r'Continue with Premium · $19.99/mo'));
    await tester.pumpAndSettle();
    expect(checkout.opened, 1);

    // --- Home -----------------------------------------------------------
    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('DEVIL IN OHIO'), findsOneWidget);
    expect(find.text('Horror'), findsNothing, reason: 'no horror titles exist');

    // Rows further down are built lazily — scroll the page to reach one.
    final homeScroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Must-Watch Series'),
      200,
      scrollable: homeScroll,
    );
    expect(find.text('Must-Watch Series'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Trending Now'),
      -200,
      scrollable: homeScroll,
    );

    // --- Details + watchlist -------------------------------------------
    await tester.tap(find.byType(MovieCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.text('STORYLINE'), findsOneWidget);

    final myListButton = find.widgetWithText(FilledButton, 'My List');
    await tester.ensureVisible(myListButton);
    await tester.pumpAndSettle();
    await tester.tap(myListButton);
    await tester.pumpAndSettle();
    expect(find.text('Added to My List'), findsOneWidget);
    expect(find.text('In My List'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();

    // --- Watchlist tab --------------------------------------------------
    await tester.tap(navItem('My List'));
    await tester.pumpAndSettle();
    expect(find.text('1 title'), findsOneWidget);
    expect(find.text('Dune'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Your list is empty'), findsOneWidget);

    // --- Search tab -----------------------------------------------------
    await tester.tap(navItem('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Browse all titles'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'peaky');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Results for "peaky"'), findsOneWidget);
    expect(find.text('Peaky Blinders'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'zzzz-nothing');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No titles found'), findsOneWidget);

    // --- Profile tab + sign out ----------------------------------------
    await tester.tap(navItem('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('ali@example.com'), findsWidgets);
    expect(find.text('Premium plan'), findsOneWidget);

    // The settings groups sit below the fold of the profile list.
    final profileScroll = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: profileScroll,
    );
    // Clear the translucent bottom navigation bar that overlays the list.
    await tester.drag(profileScroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('restored session skips sign-in', (tester) async {
    await pumpApp(tester, prefs: signedIn(planId: 'basic'));

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Trending Now'), findsOneWidget);
  });

  testWidgets('a session saved by the old local-only app signs out cleanly', (
    tester,
  ) async {
    await pumpApp(
      tester,
      prefs: {
        'novaOnboardingSeen': true,
        'novaUser': jsonEncode({
          'name': 'Ali',
          'email': 'ali@example.com',
          'plan': 'basic',
        }),
      },
    );
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a declined card keeps the user on the plan screen', (
    tester,
  ) async {
    await pumpApp(tester, prefs: signedIn(country: 'PK'));
    await openPlans(tester);
    expect(find.text('Choose your plan'), findsOneWidget);
    expect(
      find.text('Rs 899 /month', findRichText: true),
      findsOneWidget,
      reason: 'priced in PKR',
    );

    checkout.declineCard = true;
    await tester.tap(find.textContaining('Continue with Standard'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your card was declined'), findsOneWidget);
    expect(find.text('Choose your plan'), findsOneWidget);

    // A second try with a working card goes through, once the message that
    // covers the button has gone.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    checkout.declineCard = false;
    await tester.tap(find.textContaining('Continue with Standard'));
    await tester.pumpAndSettle();
    // Opened from the profile, so it returns there with the new plan.
    expect(find.text('Standard plan'), findsOneWidget);
    expect(checkout.opened, 2);
  });

  testWidgets('changing the billing country reprices the plans', (
    tester,
  ) async {
    await pumpApp(tester, prefs: signedIn());
    await openPlans(tester);
    expect(find.text('Billing country: United States · USD'), findsOneWidget);

    await tester.tap(find.text('Billing country: United States · USD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pakistan'));
    await tester.pumpAndSettle();

    expect(find.text('Billing country: Pakistan · PKR'), findsOneWidget);
    expect(find.text('Rs 899 /month', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Continue with Standard · Rs 899/mo'),
      findsOneWidget,
    );
  });

  testWidgets('canceling checkout charges nothing', (tester) async {
    await pumpApp(tester, prefs: signedIn());
    await openPlans(tester);

    checkout.nextReturn = CheckoutReturn.canceled;
    await tester.tap(find.textContaining('Continue with Standard'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Checkout canceled'), findsOneWidget);
    expect(find.text('Choose your plan'), findsOneWidget);
  });

  testWidgets('a new member can skip the plan and browse', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ali');
    await tester.enterText(fields.at(1), 'ali@example.com');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.tap(find.text('I agree to the Terms & Conditions'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now, I’ll browse and rent'));
    await tester.pumpAndSettle();
    expect(find.text('Trending Now'), findsOneWidget);
    expect(checkout.opened, 0);
  });

  testWidgets('without a plan, a title is rented for 48 hours, then plays', (
    tester,
  ) async {
    await pumpApp(tester, prefs: signedIn());
    expect(
      find.text('Trending Now'),
      findsOneWidget,
      reason: 'browsing is open',
    );

    await tester.tap(navItem('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dune');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dune').last);
    await tester.pumpAndSettle();
    expect(find.text('Watch Now'), findsNothing);
    expect(find.text(r'Rent for 48h · $3.99'), findsOneWidget);

    await tester.ensureVisible(find.text(r'Rent for 48h · $3.99'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Rent for 48h · $3.99'));
    await tester.pumpAndSettle();
    expect(checkout.opened, 1);
    expect(
      find.textContaining('Rented. Dune is yours for 48 hours'),
      findsOneWidget,
    );
    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.textContaining('Rented · 47h left'), findsOneWidget);

    // Profile lists the rental.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(navItem('Profile'));
    await tester.pumpAndSettle();
    final profileScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Rentals'),
      200,
      scrollable: profileScroll,
    );
    expect(find.text('47h left'), findsOneWidget);
  });

  testWidgets('Watch Now without a plan or rental opens the rental offer', (
    tester,
  ) async {
    await pumpApp(tester, prefs: signedIn());
    await tester.tap(find.text('Watch Now').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Rent for 48h'), findsOneWidget);
    expect(find.text('Or watch everything with a plan'), findsOneWidget);
  });

  /// Opens Profile and scrolls [target] to the top of the list, clear of the
  /// translucent bottom navigation bar.
  Future<void> profileShowing(WidgetTester tester, Finder target) async {
    await tester.tap(navItem('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets('a subscriber cancels, keeps watching, then resumes', (
    tester,
  ) async {
    await pumpApp(tester, prefs: signedIn(planId: 'standard'));
    await profileShowing(tester, find.text('Cancel plan'));
    expect(find.textContaining('Renews'), findsOneWidget);
    expect(find.textContaining('Visa •••• 4242'), findsOneWidget);

    await tester.tap(find.text('Cancel plan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You can keep watching until'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel plan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('· Ends '), findsOneWidget);
    expect(find.text('Resume plan'), findsOneWidget);
    expect(find.text('Standard plan'), findsOneWidget, reason: 'still active');

    await tester.tap(find.text('Resume plan'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel plan'), findsOneWidget);
    expect(find.textContaining('Renews'), findsOneWidget);
  });

  testWidgets('a failed renewal is paid from Profile', (tester) async {
    final prefs = signedIn(planId: 'standard');
    api.makePastDue('ali@example.com');
    await pumpApp(tester, prefs: prefs);
    await profileShowing(tester, find.text(r'Pay $14.99 now'));

    expect(find.text('Your payment didn’t go through'), findsOneWidget);
    expect(
      find.textContaining('Payment overdue · watching until'),
      findsOneWidget,
    );

    await tester.tap(find.text(r'Pay $14.99 now'));
    await tester.pumpAndSettle();
    expect(checkout.opened, 1);
    expect(find.text('Your payment didn’t go through'), findsNothing);
    expect(find.textContaining('Renews'), findsOneWidget);

    await tester.ensureVisible(find.text('Billing history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Billing history'));
    await tester.pumpAndSettle();
    expect(find.text('PAID'), findsOneWidget);
  });

  testWidgets('canceling an overdue plan ends it straight away', (
    tester,
  ) async {
    final prefs = signedIn(planId: 'basic');
    api.makePastDue('ali@example.com');
    await pumpApp(tester, prefs: prefs);
    await profileShowing(tester, find.text('Cancel plan'));

    expect(find.text('Ends your plan now'), findsOneWidget);
    await tester.tap(find.text('Cancel plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel plan'));
    await tester.pumpAndSettle();
    expect(find.text('No plan selected'), findsOneWidget);
  });

  testWidgets('catalogue failure shows a retryable error', (tester) async {
    await pumpApp(
      tester,
      prefs: signedIn(planId: 'basic'),
      catalog: 'not json',
    );

    expect(find.text('Couldn’t load the catalogue'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('first launch runs onboarding, then hands off to sign-up', (
    tester,
  ) async {
    await pumpApp(tester, prefs: {});

    // Slide 1
    expect(find.text('01 / 03'), findsOneWidget);
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Movies'), findsWidgets);
    expect(find.text('Welcome back'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Slide 2
    expect(find.text('02 / 03'), findsOneWidget);
    expect(find.text('Made For Your'), findsWidgets);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Slide 3 — final page swaps the label and hides Skip.
    expect(find.text('03 / 03'), findsOneWidget);
    expect(find.text('Your Cinema,'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Join the experience'), findsOneWidget);
    expect(
      OnboardingService(await LocalStore.open()).hasSeen(),
      isTrue,
      reason: 'completing onboarding must be remembered',
    );
  });

  testWidgets('Skip leaves onboarding immediately', (tester) async {
    await pumpApp(tester, prefs: {});

    expect(find.text('01 / 03'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Join the experience'), findsOneWidget);
    expect(OnboardingService(await LocalStore.open()).hasSeen(), isTrue);
  });

  testWidgets('a wrong password is rejected at sign-in', (tester) async {
    api.seedAccount(email: 'ali@example.com');
    await pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ALI@example.com');
    await tester.enterText(fields.at(1), 'wrong-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password.'), findsOneWidget);

    // The right password gets through, and an account with no plan yet is
    // sent to plan selection.
    await tester.enterText(fields.at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your plan'), findsOneWidget);
  });

  testWidgets('home chrome retracts scrolling down and returns scrolling up', (
    tester,
  ) async {
    await pumpApp(tester, prefs: signedIn(planId: 'basic'));

    // The wordmark and the action buttons ride in their own AnimatedSlide,
    // leaving in opposite directions.
    Offset slideOf(Type widget) => tester
        .widget<AnimatedSlide>(
          find.ancestor(
            of: find.byType(widget),
            matching: find.byType(AnimatedSlide),
          ),
        )
        .offset;

    expect(slideOf(NovaLogo), Offset.zero);
    expect(slideOf(UserAvatar), Offset.zero);

    final page = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.drag(page, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      slideOf(NovaLogo),
      const Offset(-1.4, 0),
      reason: 'the wordmark leaves to the left',
    );
    expect(
      slideOf(UserAvatar),
      const Offset(1.4, 0),
      reason: 'the actions leave to the right',
    );

    await tester.drag(page, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(
      slideOf(NovaLogo),
      Offset.zero,
      reason: 'scrolling up brings it back',
    );
    expect(slideOf(UserAvatar), Offset.zero);
  });
}
