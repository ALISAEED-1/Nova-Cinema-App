import '../core/constants/app_constants.dart';
import 'local_store.dart';

/// Per-user watchlist persistence.
///
/// The web app's "My List" was visual only; here it is stored on device so the
/// list survives restarts, scoped to the signed-in account.
class WatchlistService {
  WatchlistService(this._store);

  final LocalStore _store;

  List<String> load(String email) =>
      _store.readStringList(StorageKeys.watchlist(email));

  Future<void> save(String email, List<String> ids) =>
      _store.writeStringList(StorageKeys.watchlist(email), ids);
}
