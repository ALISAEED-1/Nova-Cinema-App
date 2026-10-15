import '../core/constants/app_constants.dart';

/// Where a user left off in a title.
class PlaybackProgress {
  const PlaybackProgress({
    required this.movieId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String movieId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get fraction => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  bool get isWatched => fraction >= AppConstants.watchedThreshold;
  bool get isInProgress =>
      fraction >= AppConstants.resumeMinFraction && !isWatched;

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'position': position.inMilliseconds,
        'duration': duration.inMilliseconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlaybackProgress.fromJson(Map<String, dynamic> json) =>
      PlaybackProgress(
        movieId: json['movieId'] as String,
        position: Duration(milliseconds: (json['position'] as num).toInt()),
        duration: Duration(milliseconds: (json['duration'] as num).toInt()),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
