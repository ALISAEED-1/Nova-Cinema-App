import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../../services/api/nova_api.dart';
import '../../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Session state: who is signed in and whether an auth request is running.
class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// True while the signed-in user has no active paid plan.
  bool get needsPlan => _user != null && !_user!.hasActivePlan;

  /// Opens with the cached account, then refreshes it from the server in the
  /// background.
  void restoreSession() {
    _user = _service.currentUser();
    _status =
        _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
    if (_user != null) unawaited(refreshAccount());
  }

  /// Pulls the latest account (plan, renewal date) from the server. Keeps the
  /// cached copy when offline; signs out if the server rejects the session.
  Future<void> refreshAccount() async {
    try {
      final fresh = await _service.refresh();
      if (fresh == null) {
        _user = null;
        _status = AuthStatus.unauthenticated;
      } else {
        _user = fresh;
      }
      notifyListeners();
    } on ApiException {
      // Offline or server down: the cached account stays in use.
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) =>
      _run(() async {
        _user = await _service.login(email: email, password: password);
        _status = AuthStatus.authenticated;
      });

  /// Creates the account and signs straight into it, so first-run users go on
  /// to pick a plan rather than being sent back to the login form.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(() async {
        _user = await _service.register(
          name: name,
          email: email,
          password: password,
          country: _deviceCountry(),
        );
        _status = AuthStatus.authenticated;
      });

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    _user = await _service.updateAccount(name: name.trim());
    notifyListeners();
  }

  /// Changes the billing country, which changes the currency plans are priced in.
  Future<void> updateCountry(String country) async {
    _user = await _service.updateAccount(country: country);
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Starting guess for the billing country; the plan screen lets the user change it.
  static String _deviceCountry() =>
      PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? 'US';
}
