import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin JSON-aware wrapper over SharedPreferences.
///
/// This is the mobile counterpart of the web app's `localStorage` usage.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  List<String> readStringList(String key) => _prefs.getStringList(key) ?? [];

  Future<void> writeStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  bool readBool(String key) => _prefs.getBool(key) ?? false;

  Future<void> writeBool(String key, bool value) =>
      _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
