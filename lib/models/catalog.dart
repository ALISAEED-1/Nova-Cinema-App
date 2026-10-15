import 'movie.dart';

/// A named, curated row of titles (e.g. "Trending Now").
class CatalogSection {
  const CatalogSection({
    required this.id,
    required this.title,
    required this.movies,
  });

  final String id;
  final String title;
  final List<Movie> movies;
}

/// The full catalogue as loaded from `assets/data/catalog.json`.
class Catalog {
  const Catalog({
    required this.movies,
    required this.heroMovies,
    required this.sections,
    required this.genres,
  });

  final List<Movie> movies;
  final List<Movie> heroMovies;
  final List<CatalogSection> sections;

  /// Genres that actually occur in the data, in display order.
  final List<String> genres;

  factory Catalog.fromJson(Map<String, dynamic> json) {
    final defaultVideo = json['defaultVideo'] as String?;
    final movies = (json['movies'] as List<dynamic>)
        .map((m) => Movie.fromJson(
              m as Map<String, dynamic>,
              defaultVideo: defaultVideo,
            ))
        .toList();
    final byId = {for (final m in movies) m.id: m};

    List<Movie> resolve(List<dynamic>? ids) => (ids ?? const [])
        .map((id) => byId['$id'])
        .whereType<Movie>()
        .toList();

    final sections = (json['sections'] as List<dynamic>? ?? const [])
        .map((s) => s as Map<String, dynamic>)
        .map(
          (s) => CatalogSection(
            id: s['id'] as String,
            title: s['title'] as String,
            movies: resolve(s['movies'] as List<dynamic>?),
          ),
        )
        .where((s) => s.movies.isNotEmpty)
        .toList();

    final genreCounts = <String, int>{};
    for (final m in movies) {
      for (final g in m.genres) {
        genreCounts[g] = (genreCounts[g] ?? 0) + 1;
      }
    }
    final genres = genreCounts.keys.toList()
      ..sort((a, b) => genreCounts[b]!.compareTo(genreCounts[a]!));

    return Catalog(
      movies: movies,
      heroMovies: resolve(json['hero'] as List<dynamic>?),
      sections: sections,
      genres: genres,
    );
  }

  Movie? byId(String id) {
    for (final m in movies) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Movie> byGenre(String genre) =>
      movies.where((m) => m.genres.contains(genre)).toList();

  /// Titles sharing at least one genre, best matches first.
  List<Movie> similarTo(Movie movie, {int limit = 8}) {
    final scored = <(Movie, int)>[];
    for (final m in movies) {
      if (m.id == movie.id) continue;
      var score = m.genres.where(movie.genres.contains).length;
      if (m.type == movie.type) score += 1;
      if (score > 0) scored.add((m, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }
}
