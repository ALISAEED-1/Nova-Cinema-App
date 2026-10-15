import 'package:flutter/foundation.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/debouncer.dart';
import '../../models/catalog.dart';
import '../../models/movie.dart';
import '../../services/search_history_service.dart';

/// Search & browse state. Filtering runs in memory over the loaded catalogue,
/// exactly as the web search page did, with a debounce on typing.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._history);

  final SearchHistoryService _history;
  final Debouncer _debounce = Debouncer(AppDurations.searchDebounce);

  Catalog? _catalog;
  String? _email;
  String _query = '';
  String _appliedQuery = '';
  MediaType? _typeFilter;
  String? _genreFilter;
  List<String> _recent = [];
  bool _pending = false;

  String get query => _query;
  MediaType? get typeFilter => _typeFilter;
  String? get genreFilter => _genreFilter;
  List<String> get recentSearches => List.unmodifiable(_recent);
  List<String> get genres => _catalog?.genres ?? const [];

  /// True while a typed query is waiting for the debounce to fire.
  bool get isPending => _pending;
  bool get hasQuery => _appliedQuery.isNotEmpty;
  bool get hasFilters => _typeFilter != null || _genreFilter != null;
  bool get isBrowsing => !hasQuery && !hasFilters;

  void attach(Catalog? catalog) {
    if (identical(catalog, _catalog)) return;
    _catalog = catalog;
    notifyListeners();
  }

  void setUser(String? email) {
    if (email == _email) return;
    _email = email;
    _recent = email == null ? [] : _history.load(email);
    notifyListeners();
  }

  List<Movie> get results {
    final all = _catalog?.movies ?? const <Movie>[];
    final q = _appliedQuery.toLowerCase();
    return all.where((m) {
      if (_typeFilter != null && m.type != _typeFilter) return false;
      if (_genreFilter != null && !m.genres.contains(_genreFilter)) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.genres.any((g) => g.toLowerCase().contains(q)) ||
          m.cast.any((c) => c.toLowerCase().contains(q));
    }).toList();
  }

  /// Title suggestions while typing, before results are applied.
  List<Movie> get suggestions {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty || q == _appliedQuery.toLowerCase()) return const [];
    return (_catalog?.movies ?? const <Movie>[])
        .where((m) => m.title.toLowerCase().contains(q))
        .take(5)
        .toList();
  }

  void setQuery(String value) {
    _query = value;
    _pending = value.trim().isNotEmpty;
    notifyListeners();
    _debounce(() {
      _appliedQuery = value.trim();
      _pending = false;
      notifyListeners();
    });
  }

  /// Applies the query immediately (submit / suggestion tap) and records it.
  Future<void> commit(String value) async {
    _debounce.cancel();
    _query = value;
    _appliedQuery = value.trim();
    _pending = false;
    notifyListeners();
    final email = _email;
    if (email != null && _appliedQuery.isNotEmpty) {
      _recent = await _history.add(email, _appliedQuery);
      notifyListeners();
    }
  }

  void clearQuery() {
    _debounce.cancel();
    _query = '';
    _appliedQuery = '';
    _pending = false;
    notifyListeners();
  }

  void setTypeFilter(MediaType? type) {
    _typeFilter = _typeFilter == type ? null : type;
    notifyListeners();
  }

  void setGenreFilter(String? genre) {
    _genreFilter = _genreFilter == genre ? null : genre;
    notifyListeners();
  }

  void clearFilters() {
    _typeFilter = null;
    _genreFilter = null;
    notifyListeners();
  }

  Future<void> removeRecent(String term) async {
    final email = _email;
    if (email == null) return;
    _recent = await _history.remove(email, term);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    final email = _email;
    if (email == null) return;
    await _history.clear(email);
    _recent = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }
}
