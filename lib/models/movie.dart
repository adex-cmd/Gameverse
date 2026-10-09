/// Where a film is hosted.
enum MovieSource {
  archive('Internet Archive', 'Archive'),
  commons('Wikimedia Commons', 'Commons');

  const MovieSource(this.label, this.shortLabel);
  final String label;

  /// For narrow screens.
  final String shortLabel;
}

/// A film listed in one of the free catalogs.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    this.source = MovieSource.archive,
    this.year,
    this.downloads = 0,
    this.runtime,
    String? posterUrl,
  }) : _posterUrl = posterUrl;

  /// Archive identifier, or a Commons page title such as "File:Nosferatu (1922).webm".
  final String id;
  final String title;
  final MovieSource source;
  final String? year;
  final int downloads;
  final String? runtime;
  final String? _posterUrl;

  String? get posterUrl =>
      _posterUrl ??
      (source == MovieSource.archive
          ? 'https://archive.org/services/img/$id'
          : null);

  factory Movie.fromSearchDoc(Map<String, dynamic> doc) {
    final id = firstString(doc['identifier']) ?? '';
    return Movie(
      id: id,
      title: cleanTitle(firstString(doc['title']) ?? id),
      year: firstString(doc['year']),
      downloads: firstInt(doc['downloads']) ?? 0,
      runtime: firstString(doc['runtime']),
    );
  }
}

/// Full metadata for a single film, including its downloadable video files.
class MovieDetails {
  const MovieDetails({
    required this.movie,
    required this.description,
    required this.subjects,
    required this.files,
    this.creator,
    this.language,
    this.license,
  });

  final Movie movie;
  final String description;
  final List<String> subjects;
  final List<MovieFile> files;
  final String? creator;
  final String? language;

  /// e.g. "Public domain", when the source states it.
  final String? license;

  /// The file most people want: a widely playable MP4 at the best quality.
  MovieFile? get bestFile => files.isEmpty ? null : files.first;

  /// [downloads] comes from search results; the metadata endpoint omits it.
  factory MovieDetails.fromMetadata(
    String id,
    Map<String, dynamic> json, {
    int downloads = 0,
  }) {
    final meta =
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawFiles = (json['files'] as List?) ?? const [];

    final files =
        rawFiles
            .whereType<Map>()
            .map((f) => MovieFile.fromJson(id, f.cast<String, dynamic>()))
            .where((f) => f.isVideo)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final subjects = <String>{};
    for (final s in asList(meta['subject'])) {
      for (final part in s.split(RegExp(r'[;,]'))) {
        final t = part.trim();
        if (t.isNotEmpty && t.length < 30) subjects.add(_titleCase(t));
      }
    }

    return MovieDetails(
      movie: Movie(
        id: id,
        title: cleanTitle(firstString(meta['title']) ?? id),
        year:
            firstString(meta['year']) ??
            _yearFromDate(firstString(meta['date'])),
        downloads: downloads,
        runtime: firstString(meta['runtime']),
      ),
      description: stripHtml(asList(meta['description']).join('\n\n')),
      subjects: subjects.take(8).toList(),
      files: files,
      creator: firstString(meta['creator']),
      language: firstString(meta['language']),
    );
  }
}

/// One downloadable video file inside an Internet Archive item.
class MovieFile {
  const MovieFile({
    required this.name,
    required this.format,
    required this.url,
    this.size,
    this.height,
  });

  final String name;
  final String format;
  final String url;
  final int? size;
  final int? height;

  static const _videoExtensions = {
    'mp4',
    'm4v',
    'mkv',
    'avi',
    'ogv',
    'webm',
    'mpeg',
    'mpg',
    'mov',
  };

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isVideo => _videoExtensions.contains(extension);

  String get fileName => name.split('/').last;

  /// e.g. "480p", or "SD" when the archive doesn't report a height.
  String get quality {
    final h = height;
    if (h == null || h <= 0) return format.contains('512Kb') ? 'Low' : 'SD';
    if (h >= 2000) return '4K';
    if (h >= 1000) return '1080p';
    if (h >= 700) return '720p';
    return '${h}p';
  }

  /// Higher is better: prefers MP4, then up to 720p (bigger files rank lower
  /// so phones don't default to multi-GB downloads), avoiding raw MPEG2.
  int get score {
    final h = height ?? 240;
    var s = h <= 720 ? h : 720 - (h - 720) ~/ 4;
    if (extension == 'mp4' || extension == 'm4v') s += 5000;
    if (extension == 'mkv' || extension == 'webm') s += 3000;
    if (format.contains('512Kb')) s -= 200;
    if (format.toUpperCase().contains('MPEG2')) s -= 4000;
    return s;
  }

  factory MovieFile.fromJson(String id, Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final encoded = name.split('/').map(Uri.encodeComponent).join('/');
    return MovieFile(
      name: name,
      format: json['format'] as String? ?? '',
      url: 'https://archive.org/download/$id/$encoded',
      size: firstInt(json['size']),
      height: firstInt(json['height']),
    );
  }
}

// ---------------------------------------------------------------------------
// Parsing helpers: archive.org fields may be a string, a number, or a list.

List<String> asList(Object? v) {
  if (v == null) return const [];
  if (v is List) return v.map((e) => e.toString()).toList();
  return [v.toString()];
}

String? firstString(Object? v) {
  final list = asList(v);
  if (list.isEmpty) return null;
  final s = list.first.trim();
  return s.isEmpty ? null : s;
}

int? firstInt(Object? v) {
  final s = firstString(v);
  return s == null ? null : int.tryParse(s) ?? double.tryParse(s)?.round();
}

String cleanTitle(String title) =>
    title.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String stripHtml(String html) {
  final text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String? _yearFromDate(String? date) {
  if (date == null) return null;
  return RegExp(r'\d{4}').firstMatch(date)?.group(0);
}

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
