import 'package:http/http.dart' as http;

import '../models/movie.dart';
import 'catalog.dart';

/// Browses public‑domain and freely licensed films on Wikimedia Commons.
class CommonsApi implements MovieCatalog {
  CommonsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const pageSize = 30;

  /// Wikimedia asks API clients to identify themselves.
  static const _headers = {
    'User-Agent': 'CineVault/1.0 (personal film downloader; Flutter)',
  };

  /// Hand‑picked classics shown in the home carousel.
  static const featuredTitles = [
    'File:Nosferatu (1922).webm',
    'File:The Kid (1921).webm',
    'File:The General (1926).webm',
    'File:Safety Last (1923).webm',
    'File:Night of the Living Dead (1968).webm',
    'File:The Cabinet of Dr. Caligari (1920).webm',
  ];

  static const _safeFilter =
      '-deepcat:"Pornographic videos" -deepcat:"Pornographic films"';

  @override
  MovieSource get source => MovieSource.commons;

  /// The file-size floors (in KB) skip trailers and short clips.
  @override
  final List<CatalogOption> categories = const [
    CatalogOption('All films', 'deepcat:"Films" filesize:>150000'),
    CatalogOption('Silent Era', 'deepcat:"Silent films" filesize:>100000'),
    CatalogOption('Comedy', 'deepcat:"Comedy films" filesize:>50000'),
    CatalogOption(
      'Documentary',
      'deepcat:"Documentary films" filesize:>100000',
    ),
    CatalogOption('Animation', 'deepcat:"Animated films" filesize:>20000'),
  ];

  @override
  final List<CatalogOption> sorts = const [
    CatalogOption('Best known', 'incoming_links_desc'),
    CatalogOption('Recently added', 'create_timestamp_desc'),
  ];

  @override
  Future<SearchPage> search({
    String query = '',
    required CatalogOption category,
    required CatalogOption sort,
    int page = 1,
  }) async {
    final terms = cleanSearchTerms(query);
    final json = await _query({
      'generator': 'search',
      'gsrnamespace': '6',
      'gsrsearch': [
        if (terms.isNotEmpty) terms,
        'filetype:video',
        category.value,
        _safeFilter,
      ].join(' '),
      'gsrlimit': '$pageSize',
      'gsroffset': '${(page - 1) * pageSize}',
      'gsrsort': terms.isNotEmpty && sort == sorts.first
          ? 'relevance'
          : sort.value,
      'gsrinfo': 'totalhits',
      'prop': 'imageinfo',
      'iiprop': 'url|size',
      'iiurlwidth': '400',
    });
    final result = (json['query'] as Map?)?.cast<String, dynamic>();
    final pages = _pages(result)
      ..sort(
        (a, b) =>
            (firstInt(a['index']) ?? 0).compareTo(firstInt(b['index']) ?? 0),
      );
    final movies = pages.map(movieFromCommonsPage).toList();
    return SearchPage(
      movies: movies,
      page: page,
      total:
          firstInt((result?['searchinfo'] as Map?)?['totalhits']) ??
          (movies.isEmpty ? 0 : null),
      hasMore: movies.isNotEmpty && json['continue'] != null,
    );
  }

  @override
  Future<List<Movie>> featured() async {
    final json = await _query({
      'titles': featuredTitles.join('|'),
      'prop': 'imageinfo',
      'iiprop': 'url|size',
      'iiurlwidth': '400',
    });
    final byTitle = {
      for (final p in _pages((json['query'] as Map?)?.cast<String, dynamic>()))
        if (p['missing'] != true) p['title']: movieFromCommonsPage(p),
    };
    return [for (final t in featuredTitles) ?byTitle[t]];
  }

  @override
  Future<MovieDetails> details(Movie movie) async {
    final json = await _query({
      'titles': movie.id,
      'prop': 'videoinfo',
      'viprop': 'url|size|mime|extmetadata|derivatives',
      'viurlwidth': '400',
      'viextmetadatafilter':
          'ImageDescription|Artist|LicenseShortName|DateTimeOriginal',
    });
    final pages = _pages((json['query'] as Map?)?.cast<String, dynamic>());
    if (pages.isEmpty || pages.first['missing'] == true) {
      throw CatalogException('This film is no longer on Wikimedia Commons.');
    }
    return detailsFromCommonsPage(pages.first);
  }

  List<Map<String, dynamic>> _pages(Map<String, dynamic>? result) =>
      ((result?['pages'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => p.cast<String, dynamic>())
          .toList();

  Future<Map<String, dynamic>> _query(Map<String, String> params) async {
    final json = await fetchJson(
      _client,
      Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'formatversion': '2',
        ...params,
      }),
      siteName: 'Wikimedia Commons',
      headers: _headers,
    );
    final error = json['error'];
    if (error is Map)
      throw CatalogException(
        'Wikimedia Commons: ${error['info'] ?? 'request failed'}',
      );
    return json;
  }
}

// ---------------------------------------------------------------------------
// Parsing, kept public so it can be tested without the network.

Movie movieFromCommonsPage(Map<String, dynamic> page) {
  final pageTitle = page['title'] as String? ?? '';
  final info = _firstInfo(page);
  final parsed = parseCommonsTitle(pageTitle);
  return Movie(
    id: pageTitle,
    title: parsed.title,
    year: parsed.year,
    source: MovieSource.commons,
    runtime: formatDuration(info['duration']),
    posterUrl: firstString(info['thumburl']),
  );
}

MovieDetails detailsFromCommonsPage(Map<String, dynamic> page) {
  final pageTitle = page['title'] as String? ?? '';
  final info = _firstInfo(page);
  final meta =
      (info['extmetadata'] as Map?)?.cast<String, dynamic>() ?? const {};
  String? metaText(String key) {
    final value = (meta[key] as Map?)?['value'];
    final text = value == null ? '' : stripHtml(value.toString());
    return text.isEmpty ? null : text;
  }

  final base = movieFromCommonsPage(page);
  final name = commonsBaseName(pageTitle);
  final originalExt =
      RegExp(
        r'\.([A-Za-z0-9]{2,5})$',
      ).firstMatch(pageTitle)?.group(1)?.toLowerCase() ??
      'webm';
  final original = firstString(info['url']);

  final files = <MovieFile>[
    if (original != null)
      MovieFile(
        name: '$name.$originalExt',
        format: 'Original · ${_formatLabel(info['mime'])}',
        url: original.split('?').first,
        size: firstInt(info['size']),
        height: firstInt(info['height']),
      ),
    for (final d in (info['derivatives'] as List? ?? const []).whereType<Map>())
      if ((d['transcodekey'] as String? ?? '').isNotEmpty && d['src'] is String)
        MovieFile(
          name: '$name.${d['transcodekey']}',
          format: _formatLabel(d['type']),
          url: _absolute(d['src'] as String),
          height: firstInt(d['height']),
        ),
  ]..sort((a, b) => b.score.compareTo(a.score));

  final dateYear = RegExp(
    r'\b(1[89]\d\d|20\d\d)\b',
  ).firstMatch(metaText('DateTimeOriginal') ?? '')?.group(1);
  return MovieDetails(
    movie: Movie(
      id: pageTitle,
      title: base.title,
      source: MovieSource.commons,
      year: base.year ?? dateYear,
      runtime: base.runtime,
      posterUrl: firstString(info['thumburl']),
    ),
    description: metaText('ImageDescription') ?? '',
    subjects: const [],
    files: files,
    creator: metaText('Artist'),
    license: metaText('LicenseShortName'),
  );
}

/// "File:Safety_Last_(1923).webm" → "Safety Last (1923)".
String commonsBaseName(String pageTitle) => pageTitle
    .replaceFirst(RegExp(r'^File:'), '')
    .replaceAll('_', ' ')
    .replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Splits a Commons file title into a display title and release year.
({String title, String? year}) parseCommonsTitle(String pageTitle) {
  final name = commonsBaseName(pageTitle);
  const year = r'(1[89]\d\d|20\d\d)';
  final paren = RegExp('^(.*?)\\s*\\($year\\b[^)]*\\)').firstMatch(name);
  if (paren != null && paren.group(1)!.trim().isNotEmpty) {
    return (title: paren.group(1)!.trim(), year: paren.group(2));
  }
  final trailing = RegExp('^(.*?)[\\s,._-]+$year\$').firstMatch(name);
  if (trailing != null && trailing.group(1)!.trim().isNotEmpty) {
    return (title: trailing.group(1)!.trim(), year: trailing.group(2));
  }
  return (title: name, year: RegExp('\\b$year\\b').firstMatch(name)?.group(1));
}

/// 4361.9 → "1:12:42"; 1253 → "20:53".
String? formatDuration(Object? seconds) {
  final total = seconds is num
      ? seconds.round()
      : double.tryParse('${seconds ?? ''}')?.round();
  if (total == null || total <= 0) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

Map<String, dynamic> _firstInfo(Map<String, dynamic> page) {
  final list = (page['videoinfo'] ?? page['imageinfo']) as List?;
  final first = list == null || list.isEmpty ? null : list.first;
  return first is Map ? first.cast<String, dynamic>() : const {};
}

String _absolute(String url) => url.startsWith('//') ? 'https:$url' : url;

/// 'video/webm; codecs="vp9, opus"' → "WebM · VP9".
String _formatLabel(Object? type) {
  final t = '${type ?? ''}'.toLowerCase();
  final container = t.contains('webm')
      ? 'WebM'
      : t.contains('quicktime')
      ? 'MOV'
      : t.contains('mp4')
      ? 'MP4'
      : t.contains('ogg')
      ? 'Ogg'
      : 'Video';
  final codec = t.contains('vp9')
      ? 'VP9'
      : t.contains('vp8')
      ? 'VP8'
      : t.contains('av01')
      ? 'AV1'
      : t.contains('mp4v')
      ? 'MPEG‑4'
      : t.contains('avc') || t.contains('h264')
      ? 'H.264'
      : t.contains('theora')
      ? 'Theora'
      : null;
  return codec == null ? container : '$container · $codec';
}
