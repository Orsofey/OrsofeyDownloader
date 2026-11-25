import 'package:flutter/material.dart';

import '../../core/services/app_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/app_scope.dart';
import '../../shared/widgets/ui.dart';
import '../queue/download_task_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final history = controller.historyTasks.where((task) {
      if (_query.isEmpty) return true;
      final query = _query.toLowerCase();
      return task.title.toLowerCase().contains(query) ||
          task.source.label.toLowerCase().contains(query) ||
          (task.uploader?.toLowerCase().contains(query) ?? false);
    }).toList();
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
              title: 'История',
              subtitle: 'Все завершённые загрузки на этом устройстве',
              trailing: controller.historyTasks.isEmpty
                  ? null
                  : TextButton.icon(
                      onPressed: () => _confirmClear(context, controller),
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      label: const Text('Очистить'),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          if (controller.historyTasks.isNotEmpty)
            StaggeredItem(
              index: 1,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию или автору',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (controller.historyTasks.isEmpty)
            const SizedBox(
              height: 420,
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Здесь появится история',
                message: 'Скачанные файлы сохраняются в списке только на этом устройстве.',
              ),
            )
          else if (history.isEmpty)
            const SizedBox(
              height: 300,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Ничего не найдено',
                message: 'Попробуйте изменить поисковый запрос.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                pluralFiles(history.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var index = 0; index < history.length; index++) ...[
              StaggeredItem(
                index: index + 2,
                child: DownloadTaskCard(task: history[index]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
          'Записи будут удалены из приложения. Скачанные файлы останутся на устройстве.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearFinished();
  }
}
