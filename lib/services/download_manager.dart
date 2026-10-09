import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';

class DownloadException implements Exception {
  DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloads files in the background with pause/resume (HTTP Range requests),
/// a concurrency limit, live speed/ETA, and persistence across app restarts.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? directoryProvider,
    this.maxConcurrent = 3,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _directoryProvider = directoryProvider ?? defaultDownloadDirectory;

  static const _prefsKey = 'cinevault.downloads.v1';
  static const _tickInterval = Duration(milliseconds: 400);

  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _directoryProvider;
  final int maxConcurrent;

  final List<DownloadTask> _tasks = [];
  final Map<String, _ActiveDownload> _active = {};
  Directory? _dir;
  Timer? _ticker;
  int _idCounter = 0;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  int get activeCount => _tasks.where((t) => t.isActive).length;
  double get totalSpeed => _tasks.fold(0, (sum, t) => sum + t.speed);

  Future<Directory> get directory async => _dir ??= await _directoryProvider();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
        _tasks.add(DownloadTask.fromJson(j));
      }
    } catch (_) {
      return; // Corrupt data: start fresh rather than crash.
    }
    for (final t in _tasks) {
      final file = File(t.savePath);
      final exists = file.existsSync();
      if (t.status == DownloadStatus.completed) {
        if (!exists) {
          t
            ..status = DownloadStatus.failed
            ..receivedBytes = 0
            ..error = 'File not found. It may have been moved or deleted.';
        }
        continue;
      }
      // Anything interrupted by closing the app waits for the user to resume.
      if (t.isActive) t.status = DownloadStatus.paused;
      t.receivedBytes = exists ? file.lengthSync() : 0;
    }
    notifyListeners();
  }

  DownloadTask? findByUrl(String url) {
    for (final t in _tasks) {
      if (t.url == url) return t;
    }
    return null;
  }

  /// The most recent download of any file belonging to [movieId].
  DownloadTask? findByMovie(String movieId) {
    for (final t in _tasks) {
      if (t.movieId == movieId) return t;
    }
    return null;
  }

  /// Starts downloading [url], or returns the existing task for it.
  Future<DownloadTask> add(
    String url, {
    String? fileName,
    String? title,
    String? posterUrl,
    String? movieId,
  }) async {
    final existing = findByUrl(url);
    if (existing != null) {
      if (existing.status == DownloadStatus.paused ||
          existing.status == DownloadStatus.failed) {
        resume(existing.id);
      }
      return existing;
    }

    final dir = await directory;
    final name = sanitizeFileName(fileName ?? fileNameFromUrl(url));
    final task = DownloadTask(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}',
      url: url,
      fileName: name,
      savePath: _uniquePath(dir.path, name),
      title: title,
      posterUrl: posterUrl,
      movieId: movieId,
    );
    _tasks.insert(0, task);
    notifyListeners();
    _save();
    _pump();
    return task;
  }

  void pause(String id) {
    final task = _find(id);
    if (task == null) return;
    final active = _active[id];
    if (active != null) {
      active.abort(_AbortReason.paused);
    } else if (task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.paused;
      notifyListeners();
      _save();
    }
  }

  void resume(String id) {
    final task = _find(id);
    if (task == null || _active.containsKey(id)) return;
    if (task.status == DownloadStatus.completed) return;
    task
      ..status = DownloadStatus.queued
      ..error = null;
    notifyListeners();
    _save();
    _pump();
  }

  Future<void> remove(String id, {bool deleteFile = false}) async {
    final task = _find(id);
    if (task == null) return;
    final active = _active[id];
    _tasks.remove(task);
    notifyListeners();
    _save();
    if (active != null) {
      active.abort(_AbortReason.removed);
      await active.done.future;
    }
    if (deleteFile || task.status != DownloadStatus.completed) {
      try {
        final f = File(task.savePath);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // File in use or already gone; nothing more to do.
      }
    }
  }

  DownloadTask? _find(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _pump() {
    for (final t in _tasks.reversed) {
      if (_active.length >= maxConcurrent) break;
      if (t.status == DownloadStatus.queued && !_active.containsKey(t.id)) {
        _run(t);
      }
    }
  }

  Future<void> _run(DownloadTask task) async {
    final active = _ActiveDownload(_clientFactory());
    _active[task.id] = active;
    task
      ..status = DownloadStatus.downloading
      ..error = null
      ..speed = 0;
    _ensureTicker();
    notifyListeners();

    IOSink? sink;
    try {
      final file = File(task.savePath);
      var existing = await file.exists() ? await file.length() : 0;

      final request = http.Request('GET', Uri.parse(task.url))
        ..headers['User-Agent'] = 'CineVault/1.0 (Flutter)';
      if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
      final response = await active.client.send(request);
      active.throwIfAborted();

      if (response.statusCode == 416 && existing > 0) {
        // The server has nothing past what we already have: it's complete.
        task
          ..totalBytes = existing
          ..receivedBytes = existing
          ..status = DownloadStatus.completed;
        return;
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw DownloadException(_httpErrorMessage(response.statusCode));
      }
      final type = response.headers['content-type'] ?? '';
      if (type.startsWith('text/html')) {
        throw DownloadException(
          'That link opens a web page, not a file. Paste a direct download link.',
        );
      }

      final resumed = response.statusCode == 206;
      if (!resumed) {
        existing = 0; // Server ignored our Range header; start over.
        if (task.receivedBytes == 0)
          _applyServerFileName(task, response.headers);
      }
      task
        ..receivedBytes = existing
        ..totalBytes = _totalFromHeaders(response, existing);

      await file.parent.create(recursive: true);
      sink = File(
        task.savePath,
      ).openWrite(mode: resumed ? FileMode.append : FileMode.write);

      active.subscription = response.stream.listen(
        (chunk) {
          sink!.add(chunk);
          task.receivedBytes += chunk.length;
          active.bytesSinceTick += chunk.length;
        },
        onError: (Object e) => active.finish(e),
        onDone: () => active.finish(),
        cancelOnError: true,
      );
      await active.finished.future;
      await sink.flush();
      await sink.close();
      sink = null;

      if (task.totalBytes > 0 && task.receivedBytes < task.totalBytes) {
        throw DownloadException(
          'Connection dropped. Tap retry to continue where it stopped.',
        );
      }
      if (task.totalBytes == 0) task.totalBytes = task.receivedBytes;
      task.status = DownloadStatus.completed;
    } catch (e) {
      switch (active.reason) {
        case _AbortReason.paused:
          task.status = DownloadStatus.paused;
        case _AbortReason.removed:
          break;
        case null:
          task
            ..status = DownloadStatus.failed
            ..error = _friendlyError(e);
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      active.client.close();
      task.speed = 0;
      _active.remove(task.id);
      active.done.complete();
      if (active.reason != _AbortReason.removed) {
        notifyListeners();
        _save();
      }
      _pump();
    }
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(_tickInterval, (_) {
      if (_active.isEmpty) {
        _ticker?.cancel();
        _ticker = null;
        return;
      }
      final seconds = _tickInterval.inMilliseconds / 1000;
      for (final entry in _active.entries) {
        final task = _find(entry.key);
        if (task == null) continue;
        final instant = entry.value.bytesSinceTick / seconds;
        entry.value.bytesSinceTick = 0;
        task.speed = task.speed == 0
            ? instant
            : task.speed * 0.75 + instant * 0.25;
      }
      notifyListeners();
    });
  }

  int _totalFromHeaders(http.StreamedResponse response, int existing) {
    final range = response.headers['content-range'];
    final match = range == null ? null : RegExp(r'/(\d+)$').firstMatch(range);
    if (match != null) return int.parse(match.group(1)!);
    final length = response.contentLength;
    return length == null || length <= 0 ? 0 : existing + length;
  }

  void _applyServerFileName(DownloadTask task, Map<String, String> headers) {
    final cd = headers['content-disposition'];
    if (cd == null) return;
    final match =
        RegExp(
          r"filename\*=(?:UTF-8'')?([^;]+)",
          caseSensitive: false,
        ).firstMatch(cd) ??
        RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd);
    if (match == null) return;
    final name = sanitizeFileName(Uri.decodeComponent(match.group(1)!.trim()));
    if (name == task.fileName) return;
    task
      ..fileName = name
      ..savePath = _uniquePath(p.dirname(task.savePath), name, ignore: task);
  }

  String _uniquePath(String dir, String name, {DownloadTask? ignore}) {
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var candidate = p.join(dir, name);
    var n = 1;
    bool taken(String path) =>
        File(path).existsSync() ||
        _tasks.any((t) => !identical(t, ignore) && p.equals(t.savePath, path));
    while (taken(candidate)) {
      candidate = p.join(dir, '$base ($n)$ext');
      n++;
    }
    return candidate;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_tasks.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      // Persistence is best-effort; downloads still work without it.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final a in _active.values) {
      a.abort(_AbortReason.paused);
    }
    super.dispose();
  }
}

enum _AbortReason { paused, removed }

class _ActiveDownload {
  _ActiveDownload(this.client) {
    // Pausing before the stream is listened to must not surface as an
    // unhandled error; _run still observes it when it awaits [finished].
    finished.future.ignore();
  }

  final http.Client client;
  StreamSubscription<List<int>>? subscription;
  final Completer<void> finished = Completer<void>();
  final Completer<void> done = Completer<void>();
  _AbortReason? reason;
  int bytesSinceTick = 0;

  void finish([Object? error]) {
    if (finished.isCompleted) return;
    error == null ? finished.complete() : finished.completeError(error);
  }

  void abort(_AbortReason why) {
    if (reason != null) return;
    reason = why;
    subscription?.cancel();
    client.close(); // Also interrupts a request that is still connecting.
    finish(const _Aborted());
  }

  void throwIfAborted() {
    if (reason != null) throw const _Aborted();
  }
}

class _Aborted implements Exception {
  const _Aborted();
}

String _httpErrorMessage(int code) => switch (code) {
  401 || 403 => 'The server refused access to this file (error $code).',
  404 || 410 =>
    'File not found on the server (error $code). The link may have expired.',
  >= 500 => 'The server is having problems (error $code). Try again later.',
  _ => 'Download failed: the server responded with error $code.',
};

String _friendlyError(Object e) {
  if (e is DownloadException) return e.message;
  if (e is SocketException || e is http.ClientException || e is HttpException) {
    return 'Network problem. Check your connection and tap retry.';
  }
  if (e is FileSystemException) {
    return 'Couldn\'t save the file: ${e.osError?.message ?? e.message}';
  }
  if (e is FormatException || e is ArgumentError)
    return 'That doesn\'t look like a valid link.';
  return 'Download failed: $e';
}

String fileNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final segments =
      uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
  return segments.isEmpty ? 'download' : segments.last;
}

String sanitizeFileName(String name) {
  var clean = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  clean = clean.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  if (clean.isEmpty) clean = 'download';
  if (clean.length > 150) {
    final ext = p.extension(clean);
    clean = clean.substring(0, 150 - ext.length) + ext;
  }
  return clean;
}

/// Android: the public Download/CineVault folder (falls back to app storage).
/// Desktop: ~/Downloads/CineVault.
Future<Directory> defaultDownloadDirectory() async {
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      final idx = external.path.indexOf('/Android/');
      if (idx > 0) {
        final public = Directory(
          p.join(external.path.substring(0, idx), 'Download', 'CineVault'),
        );
        try {
          await public.create(recursive: true);
          final probe = File(p.join(public.path, '.cinevault_probe'));
          await probe.writeAsString('ok');
          await probe.delete();
          return public;
        } catch (_) {
          // Older Android without storage permission: use app storage below.
        }
      }
      return Directory(p.join(external.path, 'Movies')).create(recursive: true);
    }
  }
  final base =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  return Directory(p.join(base.path, 'CineVault')).create(recursive: true);
}
