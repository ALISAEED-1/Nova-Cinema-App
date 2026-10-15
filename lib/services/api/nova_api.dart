import '../../models/app_user.dart';
import '../../models/checkout_session.dart';
import '../../models/subscription_plan.dart';

/// A failed call to the backend, with a message fit to show the user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.token, required this.user});
  final String token;
  final AppUser user;
}

/// The nova-pay backend. [HttpNovaApi] talks to the real server; tests supply
/// an in-memory fake.
abstract class NovaApi {
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String country,
  });

  Future<AuthResult> login({required String email, required String password});

  Future<AppUser> fetchAccount(String token);

  Future<AppUser> updateAccount(String token, {String? name, String? country});

  Future<List<BillingCountry>> fetchCountries();

  Future<PlanCatalog> fetchPlans(String token);

  Future<RentalOffer> fetchRentalOffer(String token);

  /// Starts paying for a plan. Repeating a call with the same
  /// [idempotencyKey] returns the same session.
  Future<CheckoutSession> createPlanCheckout(
    String token, {
    required String planId,
    required String idempotencyKey,
  });

  /// Starts paying to rent one title, under the same idempotency rule.
  Future<CheckoutSession> createRentalCheckout(
    String token, {
    required String movieId,
    required String title,
    required String idempotencyKey,
  });

  /// Pays an open renewal invoice by hand ("Pay now").
  Future<CheckoutSession> createRenewalCheckout(
    String token, {
    required String invoiceId,
    required String idempotencyKey,
  });

  Future<CheckoutSession> fetchCheckoutSession(String token, String sessionId);

  /// Stops renewal: an active plan runs to the end of its period.
  Future<AppUser> cancelSubscription(String token);

  /// Takes back a cancellation before the period ends.
  Future<AppUser> resumeSubscription(String token);

  Future<List<Invoice>> fetchInvoices(String token);

  /// Development servers only: pretend [days] have passed for this account
  /// and run billing, to demo renewals without waiting.
  Future<AppUser> advanceClock(String token, int days);
}
