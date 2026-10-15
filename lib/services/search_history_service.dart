import '../core/constants/app_constants.dart';
import 'local_store.dart';

/// Recent search terms, most recent first, per user.
class SearchHistoryService {
  SearchHistoryService(this._store);

  final LocalStore _store;

  List<String> load(String email) =>
      _store.readStringList(StorageKeys.recentSearches(email));

  Future<List<String>> add(String email, String term) async {
    final clean = term.trim();
    final list = load(email)
      ..removeWhere((t) => t.toLowerCase() == clean.toLowerCase())
      ..insert(0, clean);
    final trimmed = list.take(AppConstants.maxRecentSearches).toList();
    await _store.writeStringList(StorageKeys.recentSearches(email), trimmed);
    return trimmed;
  }

  Future<List<String>> remove(String email, String term) async {
    final list = load(email)..remove(term);
    await _store.writeStringList(StorageKeys.recentSearches(email), list);
    return list;
  }

  Future<void> clear(String email) =>
      _store.remove(StorageKeys.recentSearches(email));
}
