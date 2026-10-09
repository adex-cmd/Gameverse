import 'package:http/http.dart' as http;

import '../models/movie.dart';
import 'catalog.dart';

/// Talks to the Internet Archive's public search and metadata APIs.
///
/// Results are limited to older films (pre‑1980), where the catalogue is
/// overwhelmingly public domain, and adult‑tagged uploads are excluded.
class ArchiveApi implements MovieCatalog {
  ArchiveApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const pageSize = 30;

  /// Hand‑picked public‑domain classics shown in the home carousel.
  static const featuredIds = [
    'his_girl_friday',
    'Night.Of.The.Living.Dead_1080p',
    'Nosferatu_most_complete_version_93_mins.',
    'CarnivalofSouls',
    'TheGeneral_201312',
    'charlie_chaplin_film_fest',
  ];

  static const _safeFilter =
      'year:[1890 TO 1979] AND '
      '-subject:(porn OR pornography OR erotic OR erotica OR xxx OR sexploitation OR nudity)';

  static const _fields = [
    'identifier',
    'title',
    'year',
    'downloads',
    'runtime',
  ];

  @override
  MovieSource get source => MovieSource.archive;

  @override
  final List<CatalogOption> categories = const [
    CatalogOption('All', 'feature_films'),
    CatalogOption('Sci‑Fi & Horror', 'SciFi_Horror'),
    CatalogOption('Film Noir', 'Film_Noir'),
    CatalogOption('Comedy', 'Comedy_Films'),
    CatalogOption('Silent Era', 'silent_films'),
    CatalogOption('Cartoons', 'animationandcartoons'),
    CatalogOption('Classic TV', 'classic_tv'),
  ];

  @override
  final List<CatalogOption> sorts = const [
    CatalogOption('Most popular', 'downloads desc'),
    CatalogOption('A – Z', 'titleSorter asc'),
    CatalogOption('Oldest first', 'year asc'),
  ];

  @override
  Future<SearchPage> search({
    String query = '',
    required CatalogOption category,
    required CatalogOption sort,
    int page = 1,
  }) async {
    final terms = cleanSearchTerms(query);
    final q = [
      if (terms.isNotEmpty) '($terms)',
      'collection:(${category.value})',
      'mediatype:(movies)',
      _safeFilter,
    ].join(' AND ');

    final json = await _getJson(
      Uri.https('archive.org', '/advancedsearch.php', {
        'q': q,
        'fl[]': _fields,
        // A text search with the default sort is ranked by relevance instead.
        if (terms.isEmpty || sort != sorts.first) 'sort[]': sort.value,
        'rows': '$pageSize',
        'page': '$page',
        'output': 'json',
      }),
    );

    final response = (json['response'] as Map?)?.cast<String, dynamic>();
    if (response == null)
      throw CatalogException('Unexpected response from archive.org');
    final docs = (response['docs'] as List? ?? const []).whereType<Map>();
    final movies = docs
        .map((d) => Movie.fromSearchDoc(d.cast<String, dynamic>()))
        .where((m) => m.id.isNotEmpty)
        .toList();
    final total = firstInt(response['numFound']) ?? 0;
    return SearchPage(
      movies: movies,
      page: page,
      total: total,
      hasMore: movies.isNotEmpty && page * pageSize < total,
    );
  }

  @override
  Future<List<Movie>> featured() async {
    final ids = featuredIds.map((id) => '"$id"').join(' OR ');
    final json = await _getJson(
      Uri.https('archive.org', '/advancedsearch.php', {
        'q': 'identifier:($ids)',
        'fl[]': _fields,
        'rows': '${featuredIds.length}',
        'output': 'json',
      }),
    );
    final docs = ((json['response'] as Map?)?['docs'] as List? ?? const [])
        .whereType<Map>();
    final byId = {
      for (final d in docs)
        firstString(d['identifier']): Movie.fromSearchDoc(
          d.cast<String, dynamic>(),
        ),
    };
    return [for (final id in featuredIds) ?byId[id]];
  }

  @override
  Future<MovieDetails> details(Movie movie) async {
    final json = await _getJson(
      Uri.https('archive.org', '/metadata/${movie.id}'),
    );
    if (json.isEmpty || json['metadata'] == null) {
      throw CatalogException(
        'This title is no longer available on archive.org.',
      );
    }
    return MovieDetails.fromMetadata(
      movie.id,
      json,
      downloads: movie.downloads,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) =>
      fetchJson(_client, uri, siteName: 'archive.org');
}
