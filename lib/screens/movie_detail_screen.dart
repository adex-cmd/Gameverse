import 'dart:ui';

import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_scope.dart';
import '../models/download_task.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';
import '../widgets/download_tile.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});
  final Movie movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Future<MovieDetails>? _future;
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<MovieDetails> _load() => AppScope.of(
    context,
  ).catalogFor(widget.movie.source).details(widget.movie);

  @override
  Widget build(BuildContext context) {
    // This page covers the whole screen (including the side rail), so it
    // measures the full width.
    final wide = context.screen.width >= Breakpoints.tablet;
    return Scaffold(
      body: FutureBuilder<MovieDetails>(
        future: _future,
        builder: (context, snap) {
          final details = snap.data;
          final movie = details?.movie ?? widget.movie;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(movie: movie, details: details, wide: wide),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.gutter,
                        4,
                        context.gutter,
                        MediaQuery.paddingOf(context).bottom + 40,
                      ),
                      child: switch (snap) {
                        AsyncSnapshot(hasError: true) => EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Couldn\'t load this film',
                          message: '${snap.error}',
                          action: GradientButton(
                            label: 'Try again',
                            icon: Icons.refresh_rounded,
                            onPressed: () => setState(() => _future = _load()),
                          ),
                        ),
                        AsyncSnapshot(hasData: true) => _buildBody(details!),
                        _ => const _BodySkeleton(),
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(MovieDetails details) {
    final description = details.description;
    final long = description.length > 320;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrimaryAction(details: details),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 30),
          const SectionTitle('About'),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: Text(
              description,
              maxLines: _expanded || !long ? null : 5,
              overflow: _expanded || !long ? null : TextOverflow.fade,
              style: const TextStyle(
                color: Color(0xFFCFCFE0),
                height: 1.55,
                fontSize: 14.5,
              ),
            ),
          ),
          if (long)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.accent2,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'Read more'),
            ),
        ],
        if (details.subjects.isNotEmpty) ...[
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in details.subjects) Pill(s)],
          ),
        ],
        if (details.files.isNotEmpty) ...[
          const SizedBox(height: 30),
          SectionTitle(
            'All files',
            trailing: Text(
              '${details.files.length} ${details.files.length == 1 ? 'version' : 'versions'}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          for (final f in details.files)
            _FileRow(file: f, movie: details.movie),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 16,
              color: AppColors.textDim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(switch (details.movie.source) {
                MovieSource.archive =>
                  'Hosted by the Internet Archive. Most films from this era are in the public domain.',
                MovieSource.commons =>
                  'Hosted on Wikimedia Commons, which only accepts public‑domain and freely licensed media.',
              }, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.movie,
    required this.details,
    required this.wide,
  });
  final Movie movie;
  final MovieDetails? details;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final posterWidth = wide ? 180.0 : context.rs(124);
    final gutter = context.gutter;
    // The backdrop stretches to whatever height the content needs, so long
    // titles and large fonts can never overflow the header.
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Transform.scale(
                scale: 1.4,
                child: NetworkPoster(movie.posterUrl),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x6608080E), Color(0xB308080E), AppColors.bg],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                // Breathing room that lets the blurred backdrop show.
                SizedBox(
                  height: wide ? context.screen.height * 0.12 : context.rs(72),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Hero(
                            tag: 'poster-${movie.id}',
                            child: Container(
                              width: posterWidth,
                              height: posterWidth * 1.5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black87,
                                    blurRadius: 30,
                                    offset: Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: NetworkPoster(movie.posterUrl),
                              ),
                            ),
                          ),
                          SizedBox(width: wide ? 28 : 18),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  movie.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: displayStyle(
                                    context.rs(wide ? 46 : 34),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (movie.year != null)
                                      Pill(
                                        movie.year!,
                                        icon: Icons.calendar_today_rounded,
                                      ),
                                    if (movie.runtime != null)
                                      Pill(
                                        movie.runtime!,
                                        icon: Icons.schedule_rounded,
                                      ),
                                    if (movie.downloads > 0)
                                      Pill(
                                        formatCount(movie.downloads),
                                        icon: Icons.download_rounded,
                                      ),
                                    if (details?.language != null)
                                      Pill(details!.language!.toUpperCase()),
                                    if (details?.license != null)
                                      Pill(
                                        details!.license!,
                                        icon: Icons.verified_rounded,
                                        highlighted: true,
                                      ),
                                  ],
                                ),
                                if (details?.creator != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    details!.creator!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textDim,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The big download button, which turns into live progress and then "Play".
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.details});
  final MovieDetails details;

  @override
  Widget build(BuildContext context) {
    final best = details.bestFile;
    if (best == null) {
      return const _Notice(
        icon: Icons.info_outline_rounded,
        text:
            'This title has no downloadable video files. It may be streaming‑only on archive.org.',
      );
    }
    final downloads = AppScope.of(context).downloads;
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final task = downloads.findByUrl(best.url);
        if (task == null) {
          final size = best.size == null ? '' : ' · ${formatBytes(best.size!)}';
          return SizedBox(
            width: double.infinity,
            child: GradientButton(
              expand: true,
              height: 56,
              icon: Icons.download_rounded,
              label:
                  'Download  ${best.quality} ${best.extension.toUpperCase()}$size',
              onPressed: () =>
                  downloadMovie(context, details.movie, file: best),
            ),
          );
        }
        if (task.status == DownloadStatus.completed) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GradientButton(
                height: 56,
                icon: Icons.play_arrow_rounded,
                label: 'Play movie',
                onPressed: () => openDownload(context, task),
              ),
              if (canShowInFolder)
                GhostButton(
                  height: 56,
                  icon: Icons.folder_open_rounded,
                  label: 'Show in folder',
                  onPressed: () => showInFolder(task.savePath),
                ),
            ],
          );
        }
        return DownloadTile(task: task, showPoster: false);
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.movie});
  final MovieFile file;
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              file.extension.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent2,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${file.quality} · ${file.format.isEmpty ? file.extension.toUpperCase() : file.format}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (file.size != null) formatBytes(file.size!),
                    file.fileName,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: downloads,
            builder: (context, _) {
              final task = downloads.findByUrl(file.url);
              if (task == null) {
                return IconButton(
                  tooltip: 'Download this version',
                  icon: const Icon(
                    Icons.download_rounded,
                    color: AppColors.text,
                  ),
                  onPressed: () => downloadMovie(context, movie, file: file),
                );
              }
              return switch (task.status) {
                DownloadStatus.completed => IconButton(
                  tooltip: 'Play',
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.success,
                  ),
                  onPressed: () => openDownload(context, task),
                ),
                DownloadStatus.failed => IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.danger,
                  ),
                  onPressed: () => downloads.resume(task.id),
                ),
                DownloadStatus.paused => IconButton(
                  tooltip: 'Resume',
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.text,
                  ),
                  onPressed: () => downloads.resume(task.id),
                ),
                DownloadStatus.queued ||
                DownloadStatus.downloading => IconButton(
                  tooltip: 'Pause',
                  onPressed: () => downloads.pause(task.id),
                  icon: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      value: task.progress,
                      strokeWidth: 2.6,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
              };
            },
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDim),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer(height: 56, radius: 28),
        SizedBox(height: 30),
        Shimmer(height: 22, width: 120, radius: 8),
        SizedBox(height: 14),
        Shimmer(height: 14, radius: 6),
        SizedBox(height: 8),
        Shimmer(height: 14, radius: 6),
        SizedBox(height: 8),
        Shimmer(height: 14, width: 220, radius: 6),
      ],
    );
  }
}
