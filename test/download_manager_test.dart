import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movie_downloader/models/download_task.dart';
import 'package:movie_downloader/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> bytes(int n) => List<int>.generate(n, (i) => i % 251);

Future<void> waitFor(
  bool Function() condition, {
  String reason = 'condition',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $reason');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('cinevault_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  DownloadManager manager(http.Client client, {int maxConcurrent = 3}) =>
      DownloadManager(
        clientFactory: () => client,
        directoryProvider: () async => tmp,
        maxConcurrent: maxConcurrent,
      );

  test('downloads a file completely', () async {
    final data = bytes(100000);
    final client = MockClient.streaming(
      (req, _) async => http.StreamedResponse(
        Stream.fromIterable([data.sublist(0, 60000), data.sublist(60000)]),
        200,
        contentLength: data.length,
        headers: {'content-type': 'video/mp4'},
      ),
    );
    final m = manager(client);

    final task = await m.add(
      'https://example.com/films/His%20Girl%20Friday.mp4',
    );
    await waitFor(
      () => task.status == DownloadStatus.completed,
      reason: 'completion',
    );

    expect(task.fileName, 'His Girl Friday.mp4');
    expect(task.totalBytes, data.length);
    expect(await File(task.savePath).readAsBytes(), data);
  });

  test(
    'pauses, then resumes with a Range request from where it stopped',
    () async {
      final data = bytes(100000);
      final requests = <http.BaseRequest>[];
      final firstBody = StreamController<List<int>>();
      final client = MockClient.streaming((req, _) async {
        requests.add(req);
        if (requests.length == 1) {
          return http.StreamedResponse(
            firstBody.stream,
            200,
            contentLength: data.length,
          );
        }
        final start = int.parse(
          RegExp(r'bytes=(\d+)-').firstMatch(req.headers['Range']!)!.group(1)!,
        );
        return http.StreamedResponse(
          Stream.value(data.sublist(start)),
          206,
          contentLength: data.length - start,
          headers: {
            'content-range': 'bytes $start-${data.length - 1}/${data.length}',
          },
        );
      });
      final m = manager(client);

      final task = await m.add('https://example.com/a.mp4');
      await waitFor(() => requests.isNotEmpty, reason: 'first request');
      firstBody.add(data.sublist(0, 40000));
      await waitFor(() => task.receivedBytes == 40000, reason: 'first chunk');

      m.pause(task.id);
      await waitFor(
        () => task.status == DownloadStatus.paused,
        reason: 'pause',
      );
      await waitFor(
        () => File(task.savePath).lengthSync() == 40000,
        reason: 'partial file flushed',
      );

      m.resume(task.id);
      await waitFor(
        () => task.status == DownloadStatus.completed,
        reason: 'completion',
      );

      expect(requests, hasLength(2));
      expect(requests.last.headers['Range'], 'bytes=40000-');
      expect(await File(task.savePath).readAsBytes(), data);
    },
  );

  test(
    'starts over cleanly when the server ignores the Range header',
    () async {
      final data = bytes(50000);
      var calls = 0;
      final firstBody = StreamController<List<int>>();
      final client = MockClient.streaming((req, _) async {
        calls++;
        return calls == 1
            ? http.StreamedResponse(
                firstBody.stream,
                200,
                contentLength: data.length,
              )
            : http.StreamedResponse(
                Stream.value(data),
                200,
                contentLength: data.length,
              );
      });
      final m = manager(client);

      final task = await m.add('https://example.com/b.mp4');
      await waitFor(() => calls == 1);
      firstBody.add(data.sublist(0, 20000));
      await waitFor(() => task.receivedBytes == 20000);
      m.pause(task.id);
      await waitFor(() => task.status == DownloadStatus.paused);

      m.resume(task.id);
      await waitFor(() => task.status == DownloadStatus.completed);
      expect(
        await File(task.savePath).readAsBytes(),
        data,
        reason: 'must not append a second full copy',
      );
    },
  );

  test('rejects links that point to a web page instead of a file', () async {
    final client = MockClient(
      (req) async => http.Response(
        '<html>hello</html>',
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    );
    final m = manager(client);

    final task = await m.add('https://example.com/watch?v=123');
    await waitFor(() => task.status == DownloadStatus.failed);
    expect(task.error, contains('web page'));
  });

  test('reports a readable error for missing files', () async {
    final m = manager(
      MockClient((req) async => http.Response('not found', 404)),
    );
    final task = await m.add('https://example.com/missing.mp4');
    await waitFor(() => task.status == DownloadStatus.failed);
    expect(task.error, contains('404'));
  });

  test('uses the file name the server suggests', () async {
    final client = MockClient.streaming(
      (req, _) async => http.StreamedResponse(
        Stream.value(bytes(10)),
        200,
        contentLength: 10,
        headers: {
          'content-disposition':
              'attachment; filename="Night of the Living Dead.mp4"',
        },
      ),
    );
    final m = manager(client);

    final task = await m.add('https://example.com/get.php?id=7');
    await waitFor(() => task.status == DownloadStatus.completed);
    expect(task.fileName, 'Night of the Living Dead.mp4');
    expect(File(task.savePath).existsSync(), isTrue);
  });

  test('never overwrites an existing file', () async {
    File(
      '${tmp.path}${Platform.pathSeparator}movie.mp4',
    ).writeAsStringSync('keep me');
    final m = manager(
      MockClient.streaming(
        (req, _) async => http.StreamedResponse(
          Stream.value(bytes(5)),
          200,
          contentLength: 5,
        ),
      ),
    );

    final task = await m.add('https://example.com/movie.mp4');
    await waitFor(() => task.status == DownloadStatus.completed);
    expect(task.fileName, 'movie.mp4');
    expect(task.savePath, endsWith('movie (1).mp4'));
    expect(
      File('${tmp.path}${Platform.pathSeparator}movie.mp4').readAsStringSync(),
      'keep me',
    );
  });

  test('runs at most maxConcurrent downloads and queues the rest', () async {
    final bodies = <StreamController<List<int>>>[];
    final client = MockClient.streaming((req, _) async {
      final body = StreamController<List<int>>();
      bodies.add(body);
      return http.StreamedResponse(body.stream, 200, contentLength: 100);
    });
    final m = manager(client, maxConcurrent: 2);

    final a = await m.add('https://example.com/1.mp4');
    final b = await m.add('https://example.com/2.mp4');
    final c = await m.add('https://example.com/3.mp4');
    await waitFor(() => bodies.length == 2);
    expect(
      [a.status, b.status, c.status],
      [
        DownloadStatus.downloading,
        DownloadStatus.downloading,
        DownloadStatus.queued,
      ],
    );

    bodies[0]
      ..add(bytes(100))
      ..close();
    await waitFor(() => a.status == DownloadStatus.completed);
    await waitFor(
      () => c.status == DownloadStatus.downloading,
      reason: 'queued task to start',
    );

    m.pause(b.id);
    m.pause(c.id);
    await waitFor(
      () =>
          b.status == DownloadStatus.paused &&
          c.status == DownloadStatus.paused,
    );
  });

  test('restores saved downloads as paused after an app restart', () async {
    final body = StreamController<List<int>>();
    final client = MockClient.streaming(
      (req, _) async =>
          http.StreamedResponse(body.stream, 200, contentLength: 1000),
    );
    final first = manager(client);
    final task = await first.add(
      'https://example.com/long.mp4',
      title: 'Long Film',
    );
    await waitFor(() => task.status == DownloadStatus.downloading);
    body.add(bytes(300));
    await waitFor(() => task.receivedBytes == 300);
    first.pause(task.id);
    await waitFor(() => File(task.savePath).lengthSync() == 300);

    final second = manager(client);
    await second.init();
    final restored = second.tasks.single;
    expect(restored.title, 'Long Film');
    expect(restored.status, DownloadStatus.paused);
    expect(restored.receivedBytes, 300);
  });

  test('removing a download deletes its partial file', () async {
    final body = StreamController<List<int>>();
    final m = manager(
      MockClient.streaming(
        (req, _) async =>
            http.StreamedResponse(body.stream, 200, contentLength: 1000),
      ),
    );
    final task = await m.add('https://example.com/x.mp4');
    await waitFor(() => task.status == DownloadStatus.downloading);
    body.add(bytes(100));
    await waitFor(() => task.receivedBytes == 100);

    await m.remove(task.id, deleteFile: true);
    expect(m.tasks, isEmpty);
    expect(File(task.savePath).existsSync(), isFalse);
  });

  group('file names', () {
    test('come from the URL path, decoded', () {
      expect(
        fileNameFromUrl('https://a.org/download/x/My%20Film.mp4'),
        'My Film.mp4',
      );
      expect(fileNameFromUrl('https://a.org/'), 'download');
    });

    test('are made safe for Windows and Android', () {
      expect(
        sanitizeFileName('What? A "Film": Part 1/2.mp4'),
        'What_ A _Film__ Part 1_2.mp4',
      );
      expect(sanitizeFileName('  ..  '), 'download');
      final long = sanitizeFileName('${'a' * 300}.mp4');
      expect(long.length, 150);
      expect(long, endsWith('.mp4'));
    });
  });
}
