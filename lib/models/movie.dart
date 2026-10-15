import '../core/constants/app_constants.dart';

enum MediaType {
  movie,
  series;

  static MediaType fromJson(String? value) =>
      value == 'series' ? MediaType.series : MediaType.movie;

  String get label => this == MediaType.series ? 'Series' : 'Movie';
}

/// A title in the catalogue — movie or series.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.type,
    required this.year,
    required this.duration,
    required this.ageRating,
    required this.genres,
    required this.synopsis,
    required this.image,
    this.storyline,
    this.tag,
    this.cast = const [],
    this.castImages = const [],
    this.director,
    this.mood,
    this.videoAsset,
    this.trailerAsset,
    this.videoSeconds,
    this.trailerSeconds,
  });

  final String id;
  final String title;
  final MediaType type;
  final int year;

  /// Human-readable runtime, e.g. `2h 35m` or `6 Seasons`.
  final String duration;

  /// Age rating badge, e.g. `13+`.
  final String ageRating;
  final List<String> genres;
  final String synopsis;
  final String? storyline;

  /// Short marketing tag, e.g. `NEW RELEASE`.
  final String? tag;
  final List<String> cast;

  /// Optional asset names (without extension) matching [cast] by index.
  final List<String> castImages;
  final String? director;
  final String? mood;

  /// Image asset name without extension.
  final String image;
  final String? videoAsset;
  final String? trailerAsset;

  /// Runtime in seconds, used only when the media container reports no usable
  /// duration of its own (fragmented MP4s report a few milliseconds).
  final int? videoSeconds;
  final int? trailerSeconds;

  Duration? fallbackDuration({required bool trailer}) {
    final s = trailer ? trailerSeconds : videoSeconds;
    return s == null ? null : Duration(seconds: s);
  }

  String get imagePath => AssetPaths.image(image);
  bool get isSeries => type == MediaType.series;
  bool get isPlayable => videoAsset != null;
  bool get hasTrailer => trailerAsset != null;
  String get genreLine => genres.join(' • ');
  String get primaryGenre => genres.isEmpty ? '' : genres.first;

  /// [defaultVideo] is applied when the entry has no `video` of its own — the
  /// web app played one shared demo stream for every title.
  factory Movie.fromJson(Map<String, dynamic> json, {String? defaultVideo}) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const []).map((e) => '$e').toList();

    return Movie(
      id: json['id'] as String,
      title: json['title'] as String,
      type: MediaType.fromJson(json['type'] as String?),
      year: (json['year'] as num?)?.toInt() ?? 0,
      duration: json['duration'] as String? ?? '',
      ageRating: json['ageRating'] as String? ?? '',
      genres: strings('genres'),
      synopsis: json['synopsis'] as String? ?? '',
      storyline: json['storyline'] as String?,
      tag: json['tag'] as String?,
      cast: strings('cast'),
      castImages: strings('castImages'),
      director: json['director'] as String?,
      mood: json['mood'] as String?,
      image: json['image'] as String,
      videoAsset: json['video'] as String? ?? defaultVideo,
      trailerAsset: json['trailer'] as String?,
      videoSeconds: (json['videoDuration'] as num?)?.toInt(),
      trailerSeconds: (json['trailerDuration'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) => other is Movie && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
