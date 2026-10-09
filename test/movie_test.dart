import 'package:flutter_test/flutter_test.dart';
import 'package:movie_downloader/models/movie.dart';

void main() {
  test('search results tolerate archive.org field shapes', () {
    final movie = Movie.fromSearchDoc({
      'identifier': 'his_girl_friday',
      'title': ['His_Girl_Friday'],
      'year': 1940,
      'downloads': '1308778',
    });
    expect(movie.title, 'His Girl Friday');
    expect(movie.year, '1940');
    expect(movie.downloads, 1308778);
    expect(movie.posterUrl, 'https://archive.org/services/img/his_girl_friday');
  });

  test('details pick a playable MP4 as the best file', () {
    final details = MovieDetails.fromMetadata('fest', {
      'metadata': {
        'title': 'Charlie Chaplin Festival',
        'date': '1938-01-01',
        'description': 'Four <b>shorts</b>.<br>Restored &amp; remastered.',
        'subject': 'comedy; silent film',
      },
      'files': [
        {
          'name': 'fest.mpeg',
          'format': 'MPEG2',
          'size': '2814887940',
          'height': '480',
        },
        {
          'name': 'fest_512kb.mp4',
          'format': '512Kb MPEG4',
          'size': '337713518',
          'height': '240',
        },
        {
          'name': 'fest.mp4',
          'format': 'h.264',
          'size': '483532211',
          'height': '480',
        },
        {
          'name': 'fest.ogv',
          'format': 'Ogg Video',
          'size': '329594705',
          'height': '304',
        },
        {'name': 'fest.jpg', 'format': 'JPEG'},
      ],
    }, downloads: 42);

    expect(details.movie.year, '1938');
    expect(details.movie.downloads, 42);
    expect(details.description, 'Four shorts.\nRestored & remastered.');
    expect(details.subjects, ['Comedy', 'Silent Film']);
    expect(details.files.map((f) => f.name), isNot(contains('fest.jpg')));
    expect(details.bestFile!.name, 'fest.mp4');
    expect(details.bestFile!.quality, '480p');
    expect(details.bestFile!.size, 483532211);
    expect(
      details.files.last.name,
      'fest.mpeg',
      reason: 'huge raw MPEG2 ranks last',
    );
  });

  test('file URLs are encoded per path segment', () {
    final file = MovieFile.fromJson('item', {
      'name': 'sub dir/My Film #1.mp4',
      'format': 'h.264',
    });
    expect(
      file.url,
      'https://archive.org/download/item/sub%20dir/My%20Film%20%231.mp4',
    );
    expect(file.fileName, 'My Film #1.mp4');
  });
}
