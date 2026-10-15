import 'package:flutter/foundation.dart';

import '../../models/catalog.dart';
import '../../models/movie.dart';
import '../../services/catalog_service.dart';

enum LoadState { idle, loading, ready, error }

/// Owns the catalogue and its load/error lifecycle.
class CatalogController extends ChangeNotifier {
  CatalogController(this._service);

  final CatalogService _service;

  LoadState _state = LoadState.idle;
  Catalog? _catalog;
  String? _errorMessage;

  LoadState get state => _state;
  Catalog? get catalog => _catalog;
  String? get errorMessage => _errorMessage;
  bool get isReady => _state == LoadState.ready && _catalog != null;

  /// Minimum number of titles a genre needs before it earns its own row.
  static const int _minGenreRowSize = 4;

  Future<void> load() async {
    if (_state == LoadState.loading) return;
    _state = LoadState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _catalog = await _service.load();
      _state = LoadState.ready;
    } on CatalogException catch (e) {
      _errorMessage = e.message;
      _state = LoadState.error;
    } catch (_) {
      _errorMessage = 'Unable to load the catalogue right now.';
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Movie? byId(String id) => _catalog?.byId(id);

  List<Movie> byIds(Iterable<String> ids) =>
      ids.map(byId).whereType<Movie>().toList();

  /// Genre rows derived from the data — only genres with enough titles.
  List<CatalogSection> get genreSections {
    final catalog = _catalog;
    if (catalog == null) return const [];
    return [
      for (final genre in catalog.genres)
        if (catalog.byGenre(genre).length >= _minGenreRowSize)
          CatalogSection(
            id: 'genre_$genre',
            title: genre,
            movies: catalog.byGenre(genre),
          ),
    ];
  }
}
