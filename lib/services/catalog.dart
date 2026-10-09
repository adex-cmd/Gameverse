import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/movie.dart';

/// A labelled choice sent to a catalog, e.g. a category or a sort order.
class CatalogOption {
  const CatalogOption(this.label, this.value);
  final String label;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is CatalogOption && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}

class SearchPage {
  const SearchPage({
    required this.movies,
    required this.page,
    required this.hasMore,
    this.total,
  });

  final List<Movie> movies;
  final int page;
  final bool hasMore;

  /// Total matches, when the source reports it.
  final int? total;
}

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A library of free films the app can browse and download from.
abstract class MovieCatalog {
  MovieSource get source;

  /// The first entry is the default.
  List<CatalogOption> get categories;

  /// The first entry is the default; text searches use relevance instead.
  List<CatalogOption> get sorts;

  Future<List<Movie>> featured();

  Future<SearchPage> search({
    String query = '',
    required CatalogOption category,
    required CatalogOption sort,
    int page = 1,
  });

  Future<MovieDetails> details(Movie movie);
}

/// Removes characters that search engines treat as query syntax.
String cleanSearchTerms(String query) => query
    .replaceAll(RegExp(r'[+\-&|!(){}\[\]^"~*?:\\/]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Future<Map<String, dynamic>> fetchJson(
  http.Client client,
  Uri uri, {
  required String siteName,
  Map<String, String>? headers,
}) async {
  final http.Response res;
  try {
    res = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
  } catch (_) {
    throw CatalogException(
      'Couldn\'t reach $siteName. Check your internet connection.',
    );
  }
  if (res.statusCode != 200) {
    throw CatalogException(
      '$siteName is busy right now (error ${res.statusCode}). Try again.',
    );
  }
  final body = jsonDecode(utf8.decode(res.bodyBytes));
  return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
}
