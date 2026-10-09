# CineVault

A Flutter app for browsing and downloading free, legal classic films, with a
built-in download manager.

## What it does

- **Two film libraries.** The [Internet Archive](https://archive.org) (about
  15,000 pre-1980 films) and [Wikimedia Commons](https://commons.wikimedia.org)
  (public-domain and freely licensed films, many in HD). Switch between them at
  the top of the Discover tab.
- **Search, categories and sorting**, with a carousel of hand-picked classics.
- **One-tap download** of the best version for a phone, or pick any available
  quality on a film's page.
- **Download from a link.** Tap **+** and paste a direct link to any video
  file, or a film page from either library.
- **Download manager.** Pause, resume, retry and cancel; three downloads run at
  once and the rest queue. Downloads survive closing the app and resume where
  they stopped.
- **Responsive layout.** Every size comes from `MediaQuery`
  (`lib/utils/responsive.dart`), from a 320pt phone up to a desktop window.

Files are saved to `Download/CineVault` on Android and `Downloads\CineVault` on
desktop.

## Sources and content

The app only lists sources that permit downloading. Internet Archive results
are limited to films from before 1980, where the catalogue is overwhelmingly
public domain. Both libraries are filtered to exclude adult material.
Streaming-only services (YouTube, Tubi, Pluto TV and similar) are not
supported: their terms do not allow downloading.

## Run it

```
flutter pub get
flutter run
```

Build an installable Android APK:

```
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

Building the Windows app additionally needs Visual Studio 2022 with the
"Desktop development with C++" workload, then `flutter build windows`.

## Tests

```
flutter test
```

The suite covers the download engine (pause and resume, restarts, file naming,
the concurrency limit, restoring after a restart), parsing for both libraries,
and the layout on seven screen sizes.

## Project layout

| Path | Contents |
| --- | --- |
| `lib/main.dart` | App entry, app-wide `MediaQuery` wrapper, navigation shell |
| `lib/screens/` | Discover, film details, Downloads, the paste-a-link sheet |
| `lib/services/` | The two catalog clients and the download manager |
| `lib/models/` | Film, film file and download task data |
| `lib/widgets/` | Shared UI: poster cards, carousel, download rows, buttons |
| `lib/utils/` | Screen-size helpers and number formatting |
