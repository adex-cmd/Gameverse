import 'package:flutter/widgets.dart';

import 'models/movie.dart';
import 'services/catalog.dart';
import 'services/download_manager.dart';

/// Makes the app's services reachable from any widget.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.catalogs,
    required this.downloads,
    required this.tab,
    required super.child,
  });

  final Map<MovieSource, MovieCatalog> catalogs;
  final DownloadManager downloads;

  /// Selected bottom-navigation tab (0 = Discover, 1 = Downloads).
  final ValueNotifier<int> tab;

  MovieCatalog catalogFor(MovieSource source) => catalogs[source]!;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) =>
      catalogs != old.catalogs || downloads != old.downloads || tab != old.tab;
}
