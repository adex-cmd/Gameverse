import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_downloader/main.dart';
import 'package:movie_downloader/models/movie.dart';
import 'package:movie_downloader/services/download_manager.dart';

import 'fakes.dart';

/// Screen shapes the app must lay out without a single overflow.
/// [fontScale] is the system setting; the app clamps it to 0.85–1.3.
const devices =
    <({String name, Size size, double fontScale, int columns, bool rail})>[
      (
        name: 'tiny phone, largest fonts',
        size: Size(320, 568),
        fontScale: 2.0,
        columns: 2,
        rail: false,
      ),
      (
        name: 'small phone',
        size: Size(360, 740),
        fontScale: 1.0,
        columns: 3,
        rail: false,
      ),
      (
        name: 'large phone',
        size: Size(412, 915),
        fontScale: 1.15,
        columns: 3,
        rail: false,
      ),
      (
        name: 'phone in landscape',
        size: Size(740, 360),
        fontScale: 1.0,
        columns: 4,
        rail: false,
      ),
      (
        name: 'tablet',
        size: Size(800, 1280),
        fontScale: 1.3,
        columns: 4,
        rail: false,
      ),
      (
        name: 'laptop window',
        size: Size(1280, 800),
        fontScale: 1.0,
        columns: 5,
        rail: true,
      ),
      (
        name: 'full HD desktop, large fonts',
        size: Size(1920, 1080),
        fontScale: 1.5,
        columns: 8,
        rail: true,
      ),
    ];

void main() {
  late Directory tmp;
  setUp(
    () => tmp = Directory.systemTemp.createTempSync('cinevault_responsive'),
  );
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester, Size size, double fontScale) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = fontScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // Name the widget behind any layout error, so a failure says what to fix.
    final report = FlutterError.onError;
    FlutterError.onError = (details) {
      final info =
          details.informationCollector
              ?.call()
              .map((n) => n.toString())
              .join('\n') ??
          '';
      debugPrint(
        'LAYOUT ERROR: ${details.exceptionAsString().split('\n').first}\n$info',
      );
      report?.call(details);
    };
    addTearDown(() => FlutterError.onError = report);

    await tester.pumpWidget(
      CineVaultApp(
        catalogs: {
          MovieSource.archive: FakeCatalog(MovieSource.archive, manyMovies),
          MovieSource.commons: FakeCatalog(MovieSource.commons, commonsMovies),
        },
        downloads: DownloadManager(directoryProvider: () async => tmp),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final d in devices) {
    testWidgets(
      'every screen fits on a ${d.name} (${d.size.width.toInt()}x${d.size.height.toInt()})',
      (tester) async {
        await pumpApp(tester, d.size, d.fontScale);
        expect(tester.takeException(), isNull, reason: 'Discover');

        // Navigation follows the screen width.
        expect(
          find.byType(VerticalDivider),
          d.rail ? findsOneWidget : findsNothing,
        );
        // The grid can start below the fold (e.g. in landscape), so look off-screen too.
        final grid = tester.widget<SliverGrid>(
          find.byType(SliverGrid, skipOffstage: false),
        );
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          d.columns,
        );

        await tester.tap(find.text('Downloads'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Nothing downloading'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Downloads');

        await tester.tap(find.byTooltip('Download from a link').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Start download'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Link sheet');
        await tester.tapAt(const Offset(4, 4)); // Dismiss via the barrier.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.text('Discover'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('FEATURED CLASSIC').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 300));
        // On short screens the body starts below the fold, so look off-screen too.
        expect(find.text('All files', skipOffstage: false), findsOneWidget);
        expect(find.text('Public domain', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Movie details');
      },
    );
  }

  testWidgets('the app-wide MediaQuery keeps extreme font settings in range', (
    tester,
  ) async {
    await pumpApp(tester, const Size(412, 915), 3.0);
    final context = tester.element(find.text('CINEVAULT'));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, 0.01));
    expect(
      MediaQuery.sizeOf(context),
      const Size(412, 915),
      reason: 'real screen size passes through',
    );
  });
}
