import 'package:flutter/material.dart';

import '../../core/models/download_task.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/app_scope.dart';
import '../../shared/widgets/ui.dart';
import 'download_task_card.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final queue = controller.tasks
        .where((task) => task.status != DownloadStatus.completed)
        .toList();
    final active = controller.activeTasks.length;
    final paused = controller.tasks
        .where((task) => task.status == DownloadStatus.paused)
        .length;
    final compact = MediaQuery.sizeOf(context).width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 8,
        compact ? 22 : 8,
        compact ? 20 : 8,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredItem(
            index: 0,
            child: SectionHeader(
              title: 'Очередь загрузок',
              subtitle: queue.isEmpty
                  ? 'Новые загрузки появятся здесь'
                  : 'Следите за прогрессом и управляйте файлами',
            ),
          ),
          const SizedBox(height: 22),
          StaggeredItem(
            index: 1,
            child: _QueueSummary(
              active: active,
              paused: paused,
              completedToday: controller.completedToday,
            ),
          ),
          const SizedBox(height: 20),
          if (queue.isEmpty)
            const SizedBox(
              height: 390,
              child: EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Очередь пока пуста',
                message: 'Вернитесь на главный экран, вставьте ссылку и выберите нужный формат.',
              ),
            )
          else
            for (var index = 0; index < queue.length; index++) ...[
              StaggeredItem(
                index: index + 2,
                child: DownloadTaskCard(task: queue[index]),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.active,
    required this.paused,
    required this.completedToday,
  });

  final int active;
  final int paused;
  final int completedToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarySoft, Color(0xFFF4F1FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.65)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final items = [
            (Icons.downloading_rounded, '$active', 'Активных'),
            (Icons.pause_circle_outline_rounded, '$paused', 'На паузе'),
            (
              Icons.check_circle_outline_rounded,
              '$completedToday',
              'Сегодня готово',
            ),
          ];
          return Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                Expanded(
                  child: Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (!compact) ...[
                        Icon(
                          items[index].$1,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Column(
                        crossAxisAlignment: compact
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[index].$2,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: AppColors.primaryDeep),
                          ),
                          Text(
                            items[index].$3,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.primaryDeep,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (index < items.length - 1)
                  Container(width: 1, height: 40, color: AppColors.lavender),
              ],
            ],
          );
        },
      ),
    );
  }
}
