import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'app_scope.dart';
import 'models/download_task.dart';
import 'models/movie.dart';
import 'screens/movie_detail_screen.dart';

void openMovie(BuildContext context, Movie movie) {
  Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => MovieDetailScreen(movie: movie),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Downloads [file], or the best available file when [file] is null.
Future<void> downloadMovie(
  BuildContext context,
  Movie movie, {
  MovieFile? file,
  MovieDetails? details,
}) async {
  final scope = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  void viewDownloads() {
    navigator.popUntil((route) => route.isFirst);
    scope.tab.value = 1;
  }

  try {
    var chosen = file;
    if (chosen == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Finding the best copy of “${movie.title}”…'),
          duration: const Duration(seconds: 2),
        ),
      );
      final d = details ?? await scope.catalogFor(movie.source).details(movie);
      chosen = d.bestFile;
    }
    if (chosen == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('“${movie.title}” has no downloadable video.'),
          ),
        );
      return;
    }

    final alreadyDone =
        scope.downloads.findByUrl(chosen.url)?.status ==
        DownloadStatus.completed;
    final year = movie.year == null ? '' : ' (${movie.year})';
    await scope.downloads.add(
      chosen.url,
      fileName: '${movie.title}$year - ${chosen.quality}.${chosen.extension}',
      title: movie.title,
      posterUrl: movie.posterUrl,
      movieId: movie.id,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            alreadyDone
                ? 'You already have “${movie.title}”.'
                : 'Downloading “${movie.title}”',
          ),
          action: SnackBarAction(label: 'View', onPressed: viewDownloads),
        ),
      );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> openDownload(BuildContext context, DownloadTask task) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await OpenFilex.open(task.savePath);
  if (result.type == ResultType.done) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(switch (result.type) {
        ResultType.noAppToOpen =>
          'No video player found. Install one (e.g. VLC) to watch this file.',
        ResultType.fileNotFound => 'The file was moved or deleted.',
        _ => 'Couldn\'t open the file: ${result.message}',
      }),
    ),
  );
}

bool get canShowInFolder =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<void> showInFolder(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', ['/select,', path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [File(path).parent.path]);
  }
}
