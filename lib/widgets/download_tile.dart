import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_scope.dart';
import '../models/download_task.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';

class DownloadTile extends StatelessWidget {
  const DownloadTile({super.key, required this.task, this.showPoster = true});

  final DownloadTask task;
  final bool showPoster;

  @override
  Widget build(BuildContext context) {
    final done = task.status == DownloadStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          if (showPoster) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 80,
                child: task.posterUrl == null
                    ? const _FileIcon()
                    : NetworkPoster(task.posterUrl),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                if (!done) ...[
                  GradientProgressBar(
                    value: task.status == DownloadStatus.downloading
                        ? task.progress
                        : task.progress ?? 0,
                    muted: task.status != DownloadStatus.downloading,
                  ),
                  const SizedBox(height: 7),
                ],
                Text(
                  _statusLine(task),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: switch (task.status) {
                      DownloadStatus.failed => AppColors.danger,
                      DownloadStatus.completed => AppColors.success,
                      _ => AppColors.textDim,
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ..._actions(context),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    final cancel = IconButton(
      tooltip: 'Cancel',
      icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
      onPressed: () => _confirmCancel(context),
    );
    return switch (task.status) {
      DownloadStatus.downloading || DownloadStatus.queued => [
        _RoundAction(
          icon: Icons.pause_rounded,
          tooltip: 'Pause',
          onTap: () => downloads.pause(task.id),
        ),
        cancel,
      ],
      DownloadStatus.paused => [
        _RoundAction(
          icon: Icons.play_arrow_rounded,
          tooltip: 'Resume',
          onTap: () => downloads.resume(task.id),
        ),
        cancel,
      ],
      DownloadStatus.failed => [
        _RoundAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Retry',
          onTap: () => downloads.resume(task.id),
        ),
        cancel,
      ],
      DownloadStatus.completed => [
        _RoundAction(
          icon: Icons.play_arrow_rounded,
          tooltip: 'Play',
          filled: true,
          onTap: () => openDownload(context, task),
        ),
        _MoreMenu(task: task),
      ],
    };
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final downloads = AppScope.of(context).downloads;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel download?'),
        content: Text(
          '“${task.displayTitle}” will be removed and the partial file deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel download'),
          ),
        ],
      ),
    );
    if (ok == true) await downloads.remove(task.id, deleteFile: true);
  }
}

String _statusLine(DownloadTask t) {
  final pct = t.progress == null
      ? ''
      : ' · ${(t.progress! * 100).toStringAsFixed(0)}%';
  switch (t.status) {
    case DownloadStatus.queued:
      return 'Waiting to start…';
    case DownloadStatus.downloading:
      if (t.receivedBytes == 0 && t.speed < 1) return 'Connecting…';
      final eta = t.eta;
      return [
        t.totalBytes > 0
            ? '${formatBytes(t.receivedBytes)} of ${formatBytes(t.totalBytes)}'
            : formatBytes(t.receivedBytes),
        formatSpeed(t.speed),
        ?(eta == null ? null : formatEta(eta)),
      ].join(' · ');
    case DownloadStatus.paused:
      return 'Paused · ${formatBytes(t.receivedBytes)}$pct';
    case DownloadStatus.failed:
      return t.error ?? 'Download failed';
    case DownloadStatus.completed:
      return '${formatBytes(t.totalBytes)} · Ready to watch';
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        shape: const CircleBorder(),
        color: filled ? null : AppColors.surfaceHigh,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled ? AppColors.gradient : null,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 42,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MoreAction { showInFolder, removeFromList, deleteFile }

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    return PopupMenuButton<_MoreAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textDim),
      onSelected: (action) async {
        switch (action) {
          case _MoreAction.showInFolder:
            await showInFolder(task.savePath);
          case _MoreAction.removeFromList:
            await downloads.remove(task.id);
          case _MoreAction.deleteFile:
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete this movie?'),
                content: Text(
                  '“${task.fileName}” will be permanently deleted from this device.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok == true) await downloads.remove(task.id, deleteFile: true);
        }
      },
      itemBuilder: (context) => [
        if (canShowInFolder)
          const PopupMenuItem(
            value: _MoreAction.showInFolder,
            child: ListTile(
              leading: Icon(Icons.folder_open_rounded),
              title: Text('Show in folder'),
            ),
          ),
        const PopupMenuItem(
          value: _MoreAction.removeFromList,
          child: ListTile(
            leading: Icon(Icons.playlist_remove_rounded),
            title: Text('Remove from list'),
          ),
        ),
        const PopupMenuItem(
          value: _MoreAction.deleteFile,
          child: ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            title: Text(
              'Delete file',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.5),
            AppColors.accent2.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: const Icon(Icons.insert_drive_file_rounded, color: Colors.white),
    );
  }
}
