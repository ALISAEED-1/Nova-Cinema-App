import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
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

  /// True right after sign-in until the user has chosen a plan.
  bool get needsPlan => _user != null && _user!.planId == null;

  void restoreSession() {
    _user = _service.currentUser();
    _status =
        _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
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
        await _service.register(name: name, email: email, password: password);
        _user = await _service.login(email: email, password: password);
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
    final current = _user;
    if (current == null) return;
    _user = await _service.updateUser(current.copyWith(name: name.trim()));
    notifyListeners();
  }

  Future<void> selectPlan(String planId) async {
    final current = _user;
    if (current == null) return;
    _user = await _service.updateUser(current.copyWith(planId: planId));
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
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
}
