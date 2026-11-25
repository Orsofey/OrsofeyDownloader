import 'package:flutter/material.dart';

import '../../core/models/download_task.dart';
import '../../core/services/app_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/app_scope.dart';
import '../../shared/widgets/ui.dart';

enum _TaskAction { pause, resume, retry, cancel, open, folder, remove }

class DownloadTaskCard extends StatelessWidget {
  const DownloadTaskCard({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final statusStyle = _statusStyle(task.status);
    final compact = MediaQuery.sizeOf(context).width < 620;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThumbnailView(
                url: task.thumbnailUrl,
                source: task.source,
                width: compact ? 86 : 116,
                height: compact ? 66 : 72,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SourceBadge(source: task.source, compact: true),
                        const SizedBox(width: 6),
                        StatusPill(
                          text: task.status.label,
                          color: statusStyle.$1,
                          background: statusStyle.$2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        task.qualityLabel,
                        if (task.uploader != null) task.uploader!,
                        if (task.playlistTitle != null) task.playlistTitle!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_TaskAction>(
                tooltip: 'Действия',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (action) =>
                    _handleAction(context, controller, action),
                itemBuilder: (context) => [
                  if (task.status == DownloadStatus.downloading ||
                      task.status == DownloadStatus.queued)
                    const PopupMenuItem(
                      value: _TaskAction.pause,
                      child: ListTile(
                        leading: Icon(Icons.pause_rounded),
                        title: Text('Пауза'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (task.status == DownloadStatus.paused)
                    const PopupMenuItem(
                      value: _TaskAction.resume,
                      child: ListTile(
                        leading: Icon(Icons.play_arrow_rounded),
                        title: Text('Продолжить'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (task.status == DownloadStatus.failed ||
                      task.status == DownloadStatus.canceled ||
                      task.status == DownloadStatus.completed)
                    const PopupMenuItem(
                      value: _TaskAction.retry,
                      child: ListTile(
                        leading: Icon(Icons.refresh_rounded),
                        title: Text('Скачать снова'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (task.status == DownloadStatus.completed &&
                      task.filePath != null &&
                      task.filePath!.isNotEmpty)
                    const PopupMenuItem(
                      value: _TaskAction.open,
                      child: ListTile(
                        leading: Icon(Icons.play_circle_outline_rounded),
                        title: Text('Открыть файл'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _TaskAction.folder,
                    child: ListTile(
                      leading: Icon(Icons.folder_outlined),
                      title: Text('Открыть папку'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (task.status.isActive)
                    const PopupMenuItem(
                      value: _TaskAction.cancel,
                      child: ListTile(
                        leading: Icon(Icons.close_rounded),
                        title: Text('Отменить'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _TaskAction.remove,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                      ),
                      title: Text('Убрать из списка'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (task.status.isActive ||
              task.status == DownloadStatus.paused ||
              task.status == DownloadStatus.processing) ...[
            const SizedBox(height: 16),
            if (task.status == DownloadStatus.processing)
              const LinearProgressIndicator(
                minHeight: 7,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              )
            else
              AnimatedProgressBar(value: task.progress),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  task.status == DownloadStatus.processing
                      ? 'Объединяем дорожки и обрабатываем файл…'
                      : task.status == DownloadStatus.paused
                      ? 'Частичный файл сохранён'
                      : '${(task.progress * 100).toStringAsFixed(0)}%'
                            '${task.downloadedBytes != null ? ' · ${formatBytes(task.downloadedBytes)}' : ''}'
                            '${task.totalBytes != null ? ' из ${formatBytes(task.totalBytes)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (task.speed != null)
                  Text(
                    '${formatBytes(task.speed)}/с',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (task.etaSeconds != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· ${formatEta(task.etaSeconds)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
          if (task.error != null && task.error!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (task.status == DownloadStatus.completed) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.filePath?.isNotEmpty == true
                        ? task.filePath!
                        : 'Файл сохранён в папку загрузок',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (task.filePath?.isNotEmpty == true)
                  FilledButton.tonalIcon(
                    onPressed: () => controller.openFile(task.filePath!),
                    icon: const Icon(Icons.play_arrow_rounded, size: 19),
                    label: const Text('Открыть'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _statusStyle(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.queued => (AppColors.primaryDeep, AppColors.primarySoft),
      DownloadStatus.downloading => (AppColors.primary, AppColors.primarySoft),
      DownloadStatus.processing => (AppColors.warning, AppColors.warningSoft),
      DownloadStatus.paused => (AppColors.warning, AppColors.warningSoft),
      DownloadStatus.completed => (AppColors.success, AppColors.successSoft),
      DownloadStatus.failed => (AppColors.danger, AppColors.dangerSoft),
      DownloadStatus.canceled => (AppColors.muted, AppColors.surfaceMuted),
    };
  }

  void _handleAction(
    BuildContext context,
    AppController controller,
    _TaskAction action,
  ) {
    switch (action) {
      case _TaskAction.pause:
        controller.pause(task.id);
      case _TaskAction.resume:
        controller.resume(task.id);
      case _TaskAction.retry:
        controller.retry(task.id);
      case _TaskAction.cancel:
        controller.cancel(task.id);
      case _TaskAction.open:
        if (task.filePath != null) controller.openFile(task.filePath!);
      case _TaskAction.folder:
        controller.openTaskFolder(task);
      case _TaskAction.remove:
        controller.removeTask(task.id);
    }
  }
}
