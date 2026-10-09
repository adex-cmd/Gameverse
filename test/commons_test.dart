import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movie_downloader/models/movie.dart';
import 'package:movie_downloader/services/catalog.dart';
import 'package:movie_downloader/services/commons_api.dart';

void main() {
  group('parseCommonsTitle', () {
    test('reads "Title (Year)" names, ignoring extra notes', () {
      expect(parseCommonsTitle('File:Safety Last (1923).webm'), (
        title: 'Safety Last',
        year: '1923',
      ));
      expect(
        parseCommonsTitle('File:Nosferatu (1922, English titles 1947).webm'),
        (title: 'Nosferatu', year: '1922'),
      );
      expect(
        parseCommonsTitle(
          'File:Her Boyfriend (1924) - Larry Semon - 16mm - Silent - UHD.webm',
        ),
        (title: 'Her Boyfriend', year: '1924'),
      );
    });

    test('reads a trailing year and handles names without one', () {
      expect(parseCommonsTitle('File:West_of_Zanzibar_1928.webm'), (
        title: 'West of Zanzibar',
        year: '1928',
      ));
      expect(parseCommonsTitle('File:The Iron Horse.webm'), (
        title: 'The Iron Horse',
        year: null,
      ));
    });
  });

  test('formatDuration matches the archive runtime style', () {
    expect(formatDuration(4361.968), '1:12:42');
    expect(formatDuration(1253), '20:53');
    expect(formatDuration(null), isNull);
    expect(formatDuration(0), isNull);
  });

  test('details prefer a 720p version over a multi-GB 1080p original', () {
    final details = detailsFromCommonsPage({
      'title': 'File:Nosferatu (1922).webm',
      'videoinfo': [
        {
          'url':
              'https://upload.wikimedia.org/wikipedia/commons/a/ab/Nosferatu_(1922).webm?utm_source=x',
          'size': 4794000000,
          'height': 1080,
          'duration': 5520.2,
          'mime': 'video/webm',
          'thumburl': 'https://upload.wikimedia.org/thumb.jpg',
          'extmetadata': {
            'ImageDescription': {
              'value': '<i>Nosferatu</i> is a 1922 silent horror film.',
            },
            'Artist': {'value': '<a href="x">F. W. Murnau</a>'},
            'LicenseShortName': {'value': 'Public domain'},
          },
          'derivatives': [
            {
              'src': 'https://upload.wikimedia.org/o.webm',
              'type': 'video/webm; codecs="vp9"',
              'height': 1080,
            },
            {
              'src':
                  'https://upload.wikimedia.org/t/Nosferatu.webm.1080p.vp9.webm',
              'type': 'video/webm; codecs="vp9, opus"',
              'transcodekey': '1080p.vp9.webm',
              'height': 1080,
            },
            {
              'src': '//upload.wikimedia.org/t/Nosferatu.webm.720p.vp9.webm',
              'type': 'video/webm; codecs="vp9, opus"',
              'transcodekey': '720p.vp9.webm',
              'height': 720,
            },
            {
              'src':
                  'https://upload.wikimedia.org/t/Nosferatu.webm.360p.mpeg4.mov',
              'type': 'video/quicktime; codecs="mp4v"',
              'transcodekey': '360p.mpeg4.mov',
              'height': 360,
            },
          ],
        },
      ],
    });

    expect(details.movie.title, 'Nosferatu');
    expect(details.movie.year, '1922');
    expect(details.movie.runtime, '1:32:00');
    expect(details.movie.posterUrl, 'https://upload.wikimedia.org/thumb.jpg');
    expect(details.description, 'Nosferatu is a 1922 silent horror film.');
    expect(details.creator, 'F. W. Murnau');
    expect(details.license, 'Public domain');

    expect(
      details.files,
      hasLength(4),
      reason: 'original + 3 transcodes; the untagged duplicate is skipped',
    );
    final best = details.bestFile!;
    expect(best.quality, '720p');
    expect(
      best.url,
      'https://upload.wikimedia.org/t/Nosferatu.webm.720p.vp9.webm',
    );
    expect(best.format, 'WebM · VP9');
    expect(best.extension, 'webm');

    final original = details.files.firstWhere(
      (f) => f.format.startsWith('Original'),
    );
    expect(original.url, isNot(contains('utm_source')));
    expect(original.size, 4794000000);
    expect(
      details.files.firstWhere((f) => f.extension == 'mov').format,
      'MOV · MPEG‑4',
    );
  });

  test(
    'search sends a safe, feature-length query and keeps result order',
    () async {
      late Uri requested;
      final api = CommonsApi(
        client: MockClient((req) async {
          requested = req.url;
          return http.Response(
            jsonEncode({
              'continue': {'gsroffset': 30},
              'query': {
                'searchinfo': {'totalhits': 1847},
                'pages': [
                  {
                    'title': 'File:Go West (1925).webm',
                    'index': 2,
                    'imageinfo': [
                      {'duration': 4080},
                    ],
                  },
                  {
                    'title': 'File:The Jazz Singer (1927).webm',
                    'index': 1,
                    'imageinfo': [
                      {'thumburl': 'https://t/j.jpg'},
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final page = await api.search(
        category: api.categories[1],
        sort: api.sorts.first,
      );

      final q = requested.queryParameters['gsrsearch']!;
      expect(q, contains('filetype:video'));
      expect(q, contains('deepcat:"Silent films"'));
      expect(q, contains('-deepcat:"Pornographic videos"'));
      expect(requested.queryParameters['gsrsort'], 'incoming_links_desc');
      expect(page.movies.map((m) => m.title), ['The Jazz Singer', 'Go West']);
      expect(page.movies.first.source, MovieSource.commons);
      expect(page.movies.last.runtime, '1:08:00');
      expect(page.total, 1847);
      expect(page.hasMore, isTrue);
    },
  );

  test('a text search with the default sort is ranked by relevance', () async {
    late Uri requested;
    final api = CommonsApi(
      client: MockClient((req) async {
        requested = req.url;
        return http.Response('{"query":{"searchinfo":{"totalhits":0}}}', 200);
      }),
    );
    final page = await api.search(
      query: 'nosferatu',
      category: api.categories.first,
      sort: api.sorts.first,
    );
    expect(requested.queryParameters['gsrsort'], 'relevance');
    expect(requested.queryParameters['gsrsearch'], startsWith('nosferatu '));
    expect(page.movies, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('API errors become readable messages', () async {
    final api = CommonsApi(
      client: MockClient(
        (req) async =>
            http.Response('{"error":{"info":"Search is disabled"}}', 200),
      ),
    );
    expect(
      () => api.search(category: api.categories.first, sort: api.sorts.first),
      throwsA(
        isA<CatalogException>().having(
          (e) => e.message,
          'message',
          contains('Search is disabled'),
        ),
      ),
    );
  });
}
