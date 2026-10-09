import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/download_task.dart';
import '../services/download_manager.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';
import '../widgets/download_tile.dart';
import 'add_link_sheet.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _segment = 0;
  String? _folder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_folder == null) {
      AppScope.of(context).downloads.directory.then((dir) {
        if (mounted) setState(() => _folder = dir.path);
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final downloads = scope.downloads;
    return SafeArea(
      bottom: false,
      child: Builder(
        builder: (context) {
          // Phones use the standard gutter; wide screens centre an 860pt column.
          final hPad = math.max(context.gutter, (context.pageWidth - 860) / 2);
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return ListenableBuilder(
            listenable: downloads,
            builder: (context, _) {
              final active = downloads.tasks
                  .where((t) => t.status != DownloadStatus.completed)
                  .toList();
              final done = downloads.tasks
                  .where((t) => t.status == DownloadStatus.completed)
                  .toList();
              final list = _segment == 0 ? active : done;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
                    sliver: SliverToBoxAdapter(child: _buildHeader(context)),
                  ),
                  if (downloads.activeCount > 0)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: _SpeedBanner(downloads: downloads),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 8),
                    sliver: SliverToBoxAdapter(
                      child: _Segments(
                        selected: _segment,
                        labels: [
                          'In progress · ${active.length}',
                          'Completed · ${done.length}',
                        ],
                        onChanged: (i) => setState(() => _segment = i),
                      ),
                    ),
                  ),
                  if (list.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: _segment == 0
                            ? EmptyState(
                                icon: Icons.download_rounded,
                                title: 'Nothing downloading',
                                message:
                                    'Pick a classic from Discover, or paste a link to any video file.',
                                action: GradientButton(
                                  label: 'Discover movies',
                                  icon: Icons.explore_rounded,
                                  onPressed: () => scope.tab.value = 0,
                                ),
                              )
                            : const EmptyState(
                                icon: Icons.video_library_rounded,
                                title: 'No movies yet',
                                message:
                                    'Finished downloads land here, ready to watch offline.',
                              ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        hPad,
                        8,
                        hPad,
                        bottomInset + 32,
                      ),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => DownloadTile(
                          key: ValueKey(list[i].id),
                          task: list[i],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DOWNLOADS', style: displayStyle(context.rs(34))),
              if (_folder != null)
                Row(
                  children: [
                    const Icon(
                      Icons.folder_rounded,
                      size: 14,
                      color: AppColors.textDim,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _folder!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GlassIconButton(
          icon: Icons.add_link_rounded,
          tooltip: 'Download from a link',
          onPressed: () => showAddLinkSheet(context),
        ),
      ],
    );
  }
}

class _SpeedBanner extends StatelessWidget {
  const _SpeedBanner({required this.downloads});
  final DownloadManager downloads;

  @override
  Widget build(BuildContext context) {
    final count = downloads.activeCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.28),
            AppColors.accent2.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradient,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'Downloading 1 file'
                      : 'Downloading $count files',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Keep the app open for the fastest speed',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatSpeed(downloads.totalSpeed),
            style: displayStyle(context.rs(30)),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: i == selected ? AppColors.gradient : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: i == selected ? Colors.white : AppColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
