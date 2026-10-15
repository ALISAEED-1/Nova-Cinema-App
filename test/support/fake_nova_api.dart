import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:nova_cinema/features/subscription/checkout_launcher.dart';
import 'package:nova_cinema/models/app_user.dart';
import 'package:nova_cinema/models/checkout_session.dart';
import 'package:nova_cinema/models/subscription_plan.dart';
import 'package:nova_cinema/services/api/nova_api.dart';

class _Account {
  _Account({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.country,
  });

  final String id;
  String name;
  final String email;
  final String password;
  String country;
  Map<String, dynamic>? subscription;
}

class _Session {
  _Session(this.email, this.json);
  final String email;
  final Map<String, dynamic> json;
}

/// In-memory stand-in for the nova-pay backend with the same rules: prices
/// per currency, idempotent checkout, plans granted only once a session is paid.
class FakeNovaApi implements NovaApi {
  final _accounts = <String, _Account>{};
  final _tokens = <String, String>{};
  final _sessions = <String, _Session>{};
  final _sessionsByKey = <String, String>{};
  var _ids = 0;

  static const _currencies = {'US': 'USD', 'DE': 'EUR', 'PK': 'PKR'};
  static const _prices = {
    'USD': {'basic': (999, r'$9.99'), 'standard': (1499, r'$14.99'), 'premium': (1999, r'$19.99')},
    'EUR': {'basic': (899, '€8.99'), 'standard': (1399, '€13.99'), 'premium': (1799, '€17.99')},
    'PKR': {'basic': (59900, 'Rs 599'), 'standard': (89900, 'Rs 899'), 'premium': (119900, 'Rs 1,199')},
  };
  static const _plans = [
    ('basic', 'Basic', 'HD', null),
    ('standard', 'Standard', 'Full HD', 'Most Popular'),
    ('premium', 'Premium', '4K + HDR', null),
  ];

  /// Creates an account directly, optionally already subscribed.
  String seedAccount({
    String name = 'Ali',
    required String email,
    String password = 'secret123',
    String country = 'US',
    String? planId,
  }) {
    final account = _addAccount(name, email, password, country);
    if (planId != null) _subscribe(account, planId);
    return _issueToken(account);
  }

  /// SharedPreferences value for a signed-in session, as the app stores it.
  String sessionJsonFor(String email) {
    final account = _accounts[email]!;
    final token = _tokens.entries.firstWhere((e) => e.value == email).key;
    return jsonEncode({'token': token, 'account': _accountJson(account)});
  }

  /// Plays the payment provider: the customer pays or is declined.
  void settleCheckout(String sessionId, {required bool paid}) {
    final session = _sessions[sessionId]!;
    if (session.json['status'] != 'open') return;
    session.json['status'] = paid ? 'paid' : 'failed';
    if (paid) {
      _subscribe(_accounts[session.email]!, session.json['planId'] as String);
    } else {
      session.json['failureReason'] = 'card_declined';
    }
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String country,
  }) async {
    if (_accounts.containsKey(email.toLowerCase())) {
      throw const ApiException(
        'An account with this email already exists.',
        statusCode: 409,
      );
    }
    final account = _addAccount(name, email, password, country);
    return AuthResult(token: _issueToken(account), user: _user(account));
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final account = _accounts[email.toLowerCase()];
    if (account == null || account.password != password) {
      throw const ApiException('Invalid email or password.', statusCode: 401);
    }
    return AuthResult(token: _issueToken(account), user: _user(account));
  }

  @override
  Future<AppUser> fetchAccount(String token) async => _user(_auth(token));

  @override
  Future<AppUser> updateAccount(
    String token, {
    String? name,
    String? country,
  }) async {
    final account = _auth(token);
    if (name != null) account.name = name;
    if (country != null) account.country = country;
    return _user(account);
  }

  @override
  Future<List<BillingCountry>> fetchCountries() async => const [
        BillingCountry(code: 'US', name: 'United States', currency: 'USD'),
        BillingCountry(code: 'DE', name: 'Germany', currency: 'EUR'),
        BillingCountry(code: 'FR', name: 'France', currency: 'EUR'),
        BillingCountry(code: 'PK', name: 'Pakistan', currency: 'PKR'),
        BillingCountry(code: 'IN', name: 'India', currency: 'INR'),
        BillingCountry(code: 'BD', name: 'Bangladesh', currency: 'BDT'),
      ];

  @override
  Future<PlanCatalog> fetchPlans(String token) async {
    final account = _auth(token);
    final currency = _currencyOf(account);
    return PlanCatalog.fromJson({
      'country': account.country,
      'currency': currency,
      'plans': [
        for (final (id, name, quality, badge) in _plans)
          {
            'id': id,
            'name': name,
            'quality': quality,
            'badge': badge,
            'features': ['$quality quality'],
            'price': _price(currency, id),
          },
      ],
    });
  }

  @override
  Future<CheckoutSession> createCheckoutSession(
    String token, {
    required String planId,
    required String idempotencyKey,
  }) async {
    final account = _auth(token);
    final existing = _sessionsByKey['${account.email}|$idempotencyKey'];
    if (existing != null) return CheckoutSession.fromJson(_sessions[existing]!.json);

    final id = 'cs_${_ids++}';
    _sessionsByKey['${account.email}|$idempotencyKey'] = id;
    _sessions[id] = _Session(account.email, {
      'id': id,
      'status': 'open',
      'planId': planId,
      'amount': _price(_currencyOf(account), planId),
      'checkoutUrl': 'https://pay.test/checkout/$id',
      'returnUrl': 'https://pay.test/checkout/return?session=$id',
      'failureReason': null,
    });
    return CheckoutSession.fromJson(_sessions[id]!.json);
  }

  @override
  Future<CheckoutSession> fetchCheckoutSession(
    String token,
    String sessionId,
  ) async {
    final account = _auth(token);
    final session = _sessions[sessionId];
    if (session == null || session.email != account.email) {
      throw const ApiException('Checkout session not found', statusCode: 404);
    }
    return CheckoutSession.fromJson(session.json);
  }

  _Account _addAccount(String name, String email, String password, String country) {
    final account = _Account(
      id: 'usr_${_ids++}',
      name: name,
      email: email.toLowerCase(),
      password: password,
      country: country,
    );
    _accounts[account.email] = account;
    return account;
  }

  String _issueToken(_Account account) {
    final token = 'token_${_ids++}';
    _tokens[token] = account.email;
    return token;
  }

  _Account _auth(String token) {
    final email = _tokens[token];
    if (email == null) {
      throw const ApiException('Sign in again to continue', statusCode: 401);
    }
    return _accounts[email]!;
  }

  void _subscribe(_Account account, String planId) {
    final (_, name, quality, _) = _plans.firstWhere((p) => p.$1 == planId);
    account.subscription = {
      'id': 'sub_${_ids++}',
      'planId': planId,
      'planName': name,
      'quality': quality,
      'status': 'active',
      'price': _price(_currencyOf(account), planId),
      'currentPeriodEnd':
          DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
    };
  }

  String _currencyOf(_Account account) => _currencies[account.country] ?? 'USD';

  Map<String, dynamic> _price(String currency, String planId) {
    final (amount, formatted) = _prices[currency]![planId]!;
    return {'amountMinor': amount, 'currency': currency, 'formatted': formatted};
  }

  Map<String, dynamic> _accountJson(_Account account) => {
        'user': {
          'id': account.id,
          'name': account.name,
          'email': account.email,
          'country': account.country,
          'currency': _currencyOf(account),
        },
        'subscription': account.subscription,
      };

  AppUser _user(_Account account) => AppUser.fromAccountJson(_accountJson(account));
}

/// Stands in for the provider's hosted page: settles the session at once.
class FakeCheckoutLauncher implements CheckoutLauncher {
  FakeCheckoutLauncher(this.api);

  final FakeNovaApi api;

  /// What the next customer does on the checkout page.
  CheckoutReturn nextReturn = CheckoutReturn.returned;
  bool declineCard = false;

  int opened = 0;

  @override
  Future<CheckoutReturn> open(BuildContext context, CheckoutSession session) async {
    opened++;
    if (nextReturn == CheckoutReturn.returned) {
      api.settleCheckout(session.id, paid: !declineCard);
    }
    return nextReturn;
  }
}
