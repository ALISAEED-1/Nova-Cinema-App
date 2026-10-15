import 'package:flutter_test/flutter_test.dart';
import 'package:nova_cinema/models/movie.dart';
import 'package:nova_cinema/services/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalog.json', () {
    test('loads, parses and resolves every referenced title', () async {
      final catalog = await const CatalogService().load();

      expect(catalog.movies, isNotEmpty);
      expect(catalog.heroMovies, isNotEmpty);
      expect(catalog.sections, isNotEmpty);

      final ids = catalog.movies.map((m) => m.id).toSet();
      expect(ids.length, catalog.movies.length, reason: 'ids must be unique');

      for (final movie in catalog.movies) {
        expect(movie.title, isNotEmpty);
        expect(movie.genres, isNotEmpty, reason: '${movie.id} has no genres');
        expect(movie.synopsis, isNotEmpty, reason: '${movie.id} has no synopsis');
        expect(movie.isPlayable, isTrue, reason: '${movie.id} has no stream');
        expect(movie.year, greaterThan(1900));
      }
    });

    test('genre rows only contain genres that exist in the data', () async {
      final catalog = await const CatalogService().load();
      for (final genre in catalog.genres) {
        expect(catalog.byGenre(genre), isNotEmpty);
      }
    });

    test('similar titles never include the title itself', () async {
      final catalog = await const CatalogService().load();
      final dune = catalog.byId('dune')!;
      final similar = catalog.similarTo(dune);
      expect(similar, isNotEmpty);
      expect(similar.contains(dune), isFalse);
      expect(similar.first.genres.any(dune.genres.contains), isTrue);
    });

    test('series and movies are both represented', () async {
      final catalog = await const CatalogService().load();
      expect(catalog.movies.any((m) => m.type == MediaType.series), isTrue);
      expect(catalog.movies.any((m) => m.type == MediaType.movie), isTrue);
    });
  });
}
