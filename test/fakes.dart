import 'package:movie_downloader/models/movie.dart';
import 'package:movie_downloader/services/catalog.dart';

/// An in-memory catalog so widget tests never touch the network.
class FakeCatalog implements MovieCatalog {
  FakeCatalog(this.source, this.movies);

  @override
  final MovieSource source;
  final List<Movie> movies;

  @override
  final List<CatalogOption> categories = const [
    CatalogOption('All', 'all'),
    CatalogOption('Sci‑Fi & Horror', 'scifi'),
    CatalogOption('Film Noir', 'noir'),
  ];

  @override
  final List<CatalogOption> sorts = const [
    CatalogOption('Most popular', 'popular'),
  ];

  @override
  Future<List<Movie>> featured() async => movies.take(4).toList();

  @override
  Future<SearchPage> search({
    String query = '',
    required CatalogOption category,
    required CatalogOption sort,
    int page = 1,
  }) async => SearchPage(
    movies: movies,
    page: page,
    hasMore: false,
    total: movies.length,
  );

  @override
  Future<MovieDetails> details(Movie movie) async => MovieDetails(
    movie: movie,
    description:
        'A fast-talking newspaper editor tries to win back his ex-wife. ' * 12,
    subjects: const ['Comedy', 'Romance', 'Screwball', 'Newspaper', 'Classic'],
    files: const [
      MovieFile(
        name: 'film.mp4',
        format: 'h.264',
        url: 'https://example.com/film.mp4',
        size: 483532211,
        height: 480,
      ),
      MovieFile(
        name: 'film_512kb.mp4',
        format: '512Kb MPEG4',
        url: 'https://example.com/film_512kb.mp4',
        size: 337713518,
        height: 240,
      ),
    ],
    creator: 'Howard Hawks',
    language: 'eng',
    license: 'Public domain',
  );
}

const archiveMovies = [
  Movie(
    id: 'his_girl_friday',
    title: 'His Girl Friday',
    year: '1940',
    downloads: 1300000,
    runtime: '1:31:48',
  ),
  Movie(
    id: 'CarnivalofSouls',
    title: 'Carnival of Souls',
    year: '1962',
    downloads: 470000,
  ),
];

const commonsMovies = [
  Movie(
    id: 'File:Nosferatu (1922).webm',
    title: 'Nosferatu',
    year: '1922',
    source: MovieSource.commons,
  ),
];

/// A fuller list with awkwardly long titles, for layout tests.
final manyMovies = [
  const Movie(
    id: 'long',
    title:
        'Das Kabinett des Doktor Caligari (The Cabinet of Dr. Caligari) Restored Edition',
    year: '1919',
    downloads: 1234567,
    runtime: '1:17:26',
  ),
  ...archiveMovies,
  for (var i = 0; i < 12; i++)
    Movie(
      id: 'film$i',
      title: 'Voyage to the Planet of Prehistoric Women $i',
      year: '19${50 + i}',
      downloads: 9000 * i,
    ),
];
