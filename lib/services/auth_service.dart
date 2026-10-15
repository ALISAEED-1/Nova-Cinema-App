import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import 'local_store.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Local account store.
///
/// Reproduces the web app's behaviour: accounts live in a `novaUsers` map keyed
/// by lower-cased email and the active session in `novaUser`. Passwords are
/// stored as the web app stored them (plain text, on-device only) — the
/// original project has no server to authenticate against.
class AuthService {
  AuthService(this._store);

  final LocalStore _store;

  Map<String, dynamic> _users() => _store.readJson(StorageKeys.users) ?? {};

  Future<void> _saveUsers(Map<String, dynamic> users) =>
      _store.writeJson(StorageKeys.users, users);

  AppUser? currentUser() {
    final json = _store.readJson(StorageKeys.session);
    return json == null ? null : AppUser.fromJson(json);
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final users = _users();
    if (users.containsKey(key)) {
      throw const AuthException('An account with this email already exists.');
    }
    users[key] = {'name': name.trim(), 'password': password};
    await _saveUsers(users);
    return AppUser(name: name.trim(), email: key);
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final account = _users()[key];
    if (account is! Map<String, dynamic> || account['password'] != password) {
      throw const AuthException('Invalid email or password.');
    }
    final user = AppUser(
      name: account['name'] as String? ?? '',
      email: key,
      planId: account['plan'] as String?,
    );
    await _store.writeJson(StorageKeys.session, user.toJson());
    return user;
  }

  Future<void> logout() => _store.remove(StorageKeys.session);

  /// Persists a change to the signed-in user (name, plan) in both the session
  /// and the account record.
  Future<AppUser> updateUser(AppUser user) async {
    await _store.writeJson(StorageKeys.session, user.toJson());
    final users = _users();
    final account = users[user.email];
    if (account is Map<String, dynamic>) {
      account['name'] = user.name;
      if (user.planId != null) account['plan'] = user.planId;
      await _saveUsers(users);
    }
    return user;
  }
}
