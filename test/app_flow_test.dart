import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_cinema/app.dart';
import 'package:nova_cinema/services/catalog_service.dart';
import 'package:nova_cinema/services/local_store.dart';
import 'package:nova_cinema/services/onboarding_service.dart';
import 'package:nova_cinema/widgets/movie_card.dart';
import 'package:nova_cinema/widgets/nova_logo.dart';
import 'package:nova_cinema/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUpAll(() {
    catalogJson = File('assets/data/catalog.json').readAsStringSync();
  });

  Future<void> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'novaOnboardingSeen': true});
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle(catalogJson)),
      ),
    );
    // Splash holds for 1.5s minimum.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Finder navItem(String label) => find.widgetWithText(InkResponse, label);

  testWidgets('sign up → choose plan → browse → list → sign out',
      (tester) async {
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

    // Registering signs the account in and goes straight to plan selection.
    expect(find.text('Choose your plan'), findsOneWidget);

    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Continue with Premium'));
    await tester.pumpAndSettle();

    // --- Home -----------------------------------------------------------
    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('DEVIL IN OHIO'), findsOneWidget);
    expect(find.text('Horror'), findsNothing, reason: 'no horror titles exist');

    // Rows further down are built lazily — scroll the page to reach one.
    final homeScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ).first;
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
    final profileScroll = find.ancestor(
      of: find.text('ali@example.com').first,
      matching: find.byType(Scrollable),
    ).first;
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
    SharedPreferences.setMockInitialValues({
      'novaOnboardingSeen': true,
      'novaUsers': jsonEncode({
        'ali@example.com': {'name': 'Ali', 'password': 'secret123', 'plan': 'basic'},
      }),
      'novaUser': jsonEncode(
        {'name': 'Ali', 'email': 'ali@example.com', 'plan': 'basic'},
      ),
    });
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle(catalogJson)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Trending Now'), findsOneWidget);
  });

  testWidgets('catalogue failure shows a retryable error', (tester) async {
    SharedPreferences.setMockInitialValues({
      'novaOnboardingSeen': true,
      'novaUser': jsonEncode(
        {'name': 'Ali', 'email': 'ali@example.com', 'plan': 'basic'},
      ),
    });
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle('not json')),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load the catalogue'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('first launch runs onboarding, then hands off to sign-up',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle(catalogJson)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

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
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle(catalogJson)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('01 / 03'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Join the experience'), findsOneWidget);
    expect(OnboardingService(await LocalStore.open()).hasSeen(), isTrue);
  });

  testWidgets('a wrong password is rejected at sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({
      'novaOnboardingSeen': true,
      'novaUsers': jsonEncode({
        'ali@example.com': {'name': 'Ali', 'password': 'secret123'},
      }),
    });
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle(catalogJson)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

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

  testWidgets('home chrome retracts scrolling down and returns scrolling up',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'novaOnboardingSeen': true,
      'novaUser': jsonEncode(
        {'name': 'Ali', 'email': 'ali@example.com', 'plan': 'basic'},
      ),
    });
    final store = await LocalStore.open();
    await tester.pumpWidget(
      NovaCinemaApp(
        store: store,
        catalogService: CatalogService(bundle: _JsonBundle(catalogJson)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

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
    expect(slideOf(NovaLogo), const Offset(-1.4, 0),
        reason: 'the wordmark leaves to the left');
    expect(slideOf(UserAvatar), const Offset(1.4, 0),
        reason: 'the actions leave to the right');

    await tester.drag(page, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(slideOf(NovaLogo), Offset.zero, reason: 'scrolling up brings it back');
    expect(slideOf(UserAvatar), Offset.zero);
  });
}
