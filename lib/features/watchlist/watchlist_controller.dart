import 'package:flutter/foundation.dart';

import '../../models/movie.dart';
import '../../services/watchlist_service.dart';

/// The signed-in user's watchlist, newest first.
class WatchlistController extends ChangeNotifier {
  WatchlistController(this._service);

  final WatchlistService _service;

  String? _email;
  List<String> _ids = [];

  List<String> get ids => List.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(String movieId) => _ids.contains(movieId);

  /// Rebinds to a different account (or none after sign-out).
  void setUser(String? email) {
    if (email == _email) return;
    _email = email;
    _ids = email == null ? [] : _service.load(email);
    notifyListeners();
  }

  /// Adds or removes [movie]; returns true when it was added.
  Future<bool> toggle(Movie movie) async {
    final added = !_ids.contains(movie.id);
    if (added) {
      _ids = [movie.id, ..._ids];
    } else {
      _ids = _ids.where((id) => id != movie.id).toList();
    }
    notifyListeners();
    await _persist();
    return added;
  }

  Future<void> remove(String movieId) async {
    if (!_ids.contains(movieId)) return;
    _ids = _ids.where((id) => id != movieId).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final email = _email;
    if (email != null) await _service.save(email, _ids);
  }
}
