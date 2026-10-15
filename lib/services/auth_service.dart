import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import 'api/nova_api.dart';
import 'local_store.dart';

/// Accounts live on the nova-pay backend. This service keeps the session
/// token and a cached copy of the account on the device, so the app opens
/// signed in and works offline until the next refresh.
class AuthService {
  AuthService(this._store, this._api);

  final LocalStore _store;
  final NovaApi _api;

  /// Bearer token for the signed-in user, or null.
  String? get token =>
      _store.readJson(StorageKeys.session)?['token'] as String?;

  /// The cached account, if a session exists.
  AppUser? currentUser() {
    final session = _store.readJson(StorageKeys.session);
    final account = session?['account'];
    if (session?['token'] is! String || account is! Map<String, dynamic>) {
      return null;
    }
    try {
      return AppUser.fromAccountJson(account);
    } catch (_) {
      return null; // A session saved by an older version of the app.
    }
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String country,
  }) async => _save(
    await _api.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
      country: country,
    ),
  );

  Future<AppUser> login({
    required String email,
    required String password,
  }) async => _save(await _api.login(email: email.trim(), password: password));

  /// Fetches the latest account from the server. Returns null and clears the
  /// session when the server no longer accepts the token.
  Future<AppUser?> refresh() async {
    final token = this.token;
    if (token == null) return null;
    try {
      return _cache(token, await _api.fetchAccount(token));
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      await logout();
      return null;
    }
  }

  Future<AppUser> updateAccount({String? name, String? country}) async {
    final token = _requireToken();
    return _cache(
      token,
      await _api.updateAccount(token, name: name, country: country),
    );
  }

  /// Runs an account-changing call ([cancel], [resume], …) and caches the
  /// account the server returns.
  Future<AppUser> changeAccount(
    Future<AppUser> Function(NovaApi api, String token) call,
  ) async {
    final token = _requireToken();
    return _cache(token, await call(_api, token));
  }

  Future<void> logout() => _store.remove(StorageKeys.session);

  String _requireToken() {
    final token = this.token;
    if (token == null) {
      throw const ApiException('Your session has ended. Sign in again.');
    }
    return token;
  }

  Future<AppUser> _save(AuthResult result) => _cache(result.token, result.user);

  Future<AppUser> _cache(String token, AppUser user) async {
    await _store.writeJson(StorageKeys.session, {
      'token': token,
      'account': user.toAccountJson(),
    });
    return user;
  }
}
