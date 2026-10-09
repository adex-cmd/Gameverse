import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_downloader/main.dart';
import 'package:movie_downloader/models/movie.dart';
import 'package:movie_downloader/services/download_manager.dart';

import 'fakes.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cinevault_widget'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CineVaultApp(
        catalogs: {
          MovieSource.archive: FakeCatalog(MovieSource.archive, archiveMovies),
          MovieSource.commons: FakeCatalog(MovieSource.commons, commonsMovies),
        },
        downloads: DownloadManager(directoryProvider: () async => tmp),
      ),
    );
    await tester.pump(); // Post-frame loads.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Discover shows the brand, featured films and the grid', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('CINEVAULT'), findsOneWidget);
    expect(find.text('FEATURED CLASSIC'), findsWidgets);
    expect(find.text('His Girl Friday'), findsWidgets);
    expect(find.text('2 films · All'), findsOneWidget);
  });

  testWidgets('Switching to Wikimedia Commons loads its films', (tester) async {
    await pumpApp(tester);
    expect(find.text('Nosferatu'), findsNothing);
    await tester.tap(find.text('Wikimedia Commons'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Nosferatu'), findsWidgets);
    expect(find.text('His Girl Friday'), findsNothing);
    expect(find.text('1 film · All'), findsOneWidget);
  });

  testWidgets('Downloads tab starts empty', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Downloads'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nothing downloading'), findsOneWidget);
    expect(find.text('In progress · 0'), findsOneWidget);
  });

  testWidgets('Link sheet rejects text that is not a URL', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Download from a link').last);
    await tester.pump(); // Starts the sheet's slide-in animation...
    await tester.pump(const Duration(milliseconds: 600)); // ...and finishes it.
    await tester.enterText(find.byType(TextField).last, 'not a link');
    await tester.tap(find.text('Start download'));
    await tester.pump();
    expect(find.textContaining('http:// or https://'), findsOneWidget);
  });
}
