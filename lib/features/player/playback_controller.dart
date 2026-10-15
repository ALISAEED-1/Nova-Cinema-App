import 'package:flutter/foundation.dart';

import '../../models/playback_progress.dart';
import '../../models/playback_settings.dart';
import '../../services/playback_service.dart';

/// Resume positions, watch history and playback preferences for the
/// signed-in user.
class PlaybackController extends ChangeNotifier {
  PlaybackController(this._service);

  final PlaybackService _service;

  String? _email;
  Map<String, PlaybackProgress> _progress = {};
  PlaybackSettings _settings = const PlaybackSettings();

  PlaybackSettings get settings => _settings;

  void setUser(String? email) {
    if (email == _email) return;
    _email = email;
    _progress = email == null ? {} : _service.loadProgress(email);
    _settings =
        email == null ? const PlaybackSettings() : _service.loadSettings(email);
    notifyListeners();
  }

  PlaybackProgress? progressFor(String movieId) => _progress[movieId];

  /// Position to resume from, or zero when the title is new or finished.
  Duration resumePositionFor(String movieId) {
    final p = _progress[movieId];
    return p != null && p.isInProgress ? p.position : Duration.zero;
  }

  /// Titles started but not finished, most recent first.
  List<PlaybackProgress> get continueWatching => _sorted.where((p) => p.isInProgress).toList();

  /// Titles watched to completion, most recent first.
  List<PlaybackProgress> get watched =>
      _sorted.where((p) => p.isWatched).toList();

  /// Everything the user has played, most recent first.
  List<PlaybackProgress> get recentlyWatched => _sorted;

  List<PlaybackProgress> get _sorted => _progress.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> save({
    required String movieId,
    required Duration position,
    required Duration duration,
  }) async {
    if (duration <= Duration.zero) return;
    _progress = {
      ..._progress,
      movieId: PlaybackProgress(
        movieId: movieId,
        position: position,
        duration: duration,
        updatedAt: DateTime.now(),
      ),
    };
    notifyListeners();
    final email = _email;
    if (email != null) await _service.saveProgress(email, _progress);
  }

  Future<void> clearProgress(String movieId) async {
    if (!_progress.containsKey(movieId)) return;
    _progress = {..._progress}..remove(movieId);
    notifyListeners();
    final email = _email;
    if (email != null) await _service.saveProgress(email, _progress);
  }

  Future<void> updateSettings(PlaybackSettings settings) async {
    _settings = settings;
    notifyListeners();
    final email = _email;
    if (email != null) await _service.saveSettings(email, settings);
  }
}
