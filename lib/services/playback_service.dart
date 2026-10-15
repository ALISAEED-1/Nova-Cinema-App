import '../core/constants/app_constants.dart';
import '../models/playback_progress.dart';
import '../models/playback_settings.dart';
import 'local_store.dart';

/// Stores resume positions and playback preferences per user.
class PlaybackService {
  PlaybackService(this._store);

  final LocalStore _store;

  Map<String, PlaybackProgress> loadProgress(String email) {
    final json = _store.readJson(StorageKeys.progress(email)) ?? {};
    final result = <String, PlaybackProgress>{};
    json.forEach((id, value) {
      if (value is Map<String, dynamic>) {
        try {
          result[id] = PlaybackProgress.fromJson(value);
        } catch (_) {
          // Skip corrupt entries rather than failing the whole map.
        }
      }
    });
    return result;
  }

  Future<void> saveProgress(
    String email,
    Map<String, PlaybackProgress> progress,
  ) =>
      _store.writeJson(
        StorageKeys.progress(email),
        progress.map((id, p) => MapEntry(id, p.toJson())),
      );

  PlaybackSettings loadSettings(String email) {
    final json = _store.readJson(StorageKeys.playbackSettings(email));
    return json == null
        ? const PlaybackSettings()
        : PlaybackSettings.fromJson(json);
  }

  Future<void> saveSettings(String email, PlaybackSettings settings) =>
      _store.writeJson(StorageKeys.playbackSettings(email), settings.toJson());
}
