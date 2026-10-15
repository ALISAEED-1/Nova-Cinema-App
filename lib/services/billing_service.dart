import 'dart:math';

import '../models/app_user.dart';
import '../models/checkout_session.dart';
import '../models/subscription_plan.dart';
import 'api/nova_api.dart';
import 'auth_service.dart';

/// Plans, rentals and checkout, on behalf of the signed-in user.
class BillingService {
  BillingService(this._api, this._auth);

  final NovaApi _api;
  final AuthService _auth;

  Future<PlanCatalog> fetchPlans() => _api.fetchPlans(_token());

  Future<List<BillingCountry>> fetchCountries() => _api.fetchCountries();

  Future<RentalOffer> fetchRentalOffer() => _api.fetchRentalOffer(_token());

  /// Creates (or, for a repeated [idempotencyKey], finds) the checkout for a plan.
  Future<CheckoutSession> startPlanCheckout(
    String planId, {
    required String idempotencyKey,
  }) => _api.createPlanCheckout(
    _token(),
    planId: planId,
    idempotencyKey: idempotencyKey,
  );

  /// Creates (or finds) the checkout to rent one title.
  Future<CheckoutSession> startRentalCheckout(
    String movieId, {
    required String title,
    required String idempotencyKey,
  }) => _api.createRentalCheckout(
    _token(),
    movieId: movieId,
    title: title,
    idempotencyKey: idempotencyKey,
  );

  /// Creates (or finds) the checkout that pays an open renewal invoice.
  Future<CheckoutSession> startRenewalCheckout(
    String invoiceId, {
    required String idempotencyKey,
  }) => _api.createRenewalCheckout(
    _token(),
    invoiceId: invoiceId,
    idempotencyKey: idempotencyKey,
  );

  Future<List<Invoice>> fetchInvoices() => _api.fetchInvoices(_token());

  Future<CheckoutSession> fetchSession(String sessionId) =>
      _api.fetchCheckoutSession(_token(), sessionId);

  /// Polls until the provider's webhook has settled the session, or [timeout]
  /// passes. The webhook, not the redirect, is what marks a session paid.
  Future<CheckoutSession> waitForOutcome(
    String sessionId, {
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var session = await fetchSession(sessionId);
    while (session.status == CheckoutStatus.open &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      session = await fetchSession(sessionId);
    }
    return session;
  }

  /// A fresh random key for one purchase attempt.
  static String newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _token() {
    final token = _auth.token;
    if (token == null) {
      throw const ApiException('Your session has ended. Sign in again.');
    }
    return token;
  }
}
