import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/download_task.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';

class PosterCard extends StatefulWidget {
  const PosterCard({super.key, required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  /// Height of the title/subtitle block under the poster.
  static const captionHeight = 50.0;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final subtitle = [
      ?movie.year,
      if (movie.downloads > 0) '${formatCount(movie.downloads)} downloads',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: AnimatedScale(
            scale: _hover ? 1.04 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_hover ? AppColors.accent : Colors.black)
                        .withValues(alpha: _hover ? 0.35 : 0.4),
                    blurRadius: _hover ? 24 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'poster-${movie.id}',
                      child: NetworkPoster(movie.posterUrl),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xAA000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _DownloadBadge(movie.id),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: widget.onTap,
                        onHover: (h) => setState(() => _hover = h),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          movie.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
      ],
    );
  }
}

/// Shows whether a film is downloading or already saved.
class _DownloadBadge extends StatelessWidget {
  const _DownloadBadge(this.movieId);
  final String movieId;

  @override
  Widget build(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final task = downloads.findByMovie(movieId);
        if (task == null) return const SizedBox.shrink();
        final Widget child = switch (task.status) {
          DownloadStatus.completed => const Icon(
            Icons.check_rounded,
            size: 16,
            color: Colors.white,
          ),
          DownloadStatus.failed => const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Colors.white,
          ),
          DownloadStatus.paused => const Icon(
            Icons.pause_rounded,
            size: 16,
            color: Colors.white,
          ),
          _ => SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              value: task.progress,
              strokeWidth: 2.4,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        };
        return Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (task.status) {
              DownloadStatus.completed => AppColors.success,
              DownloadStatus.failed => AppColors.danger,
              _ => Colors.black.withValues(alpha: 0.6),
            },
          ),
          child: child,
        );
      },
    );
  }
}
