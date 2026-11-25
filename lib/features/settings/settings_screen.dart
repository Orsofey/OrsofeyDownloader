import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/app_settings.dart';
import '../../core/services/app_controller.dart';
import '../../core/models/media_info.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/app_scope.dart';
import '../../shared/widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _languagesController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _languagesController = TextEditingController(text: 'ru,en');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _languagesController.text = AppScope.of(context).settings.subtitleLanguages;
    _initialized = true;
  }

  @override
  void dispose() {
    _languagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    _showMessageIfNeeded(controller);
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
          const StaggeredItem(
            index: 0,
            child: SectionHeader(
              title: 'Настройки',
              subtitle: 'Форматы, папка, авторизация и компоненты',
            ),
          ),
          const SizedBox(height: 22),
          StaggeredItem(
            index: 1,
            child: _buildDirectorySection(context, controller, settings),
          ),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 2,
            child: _buildDefaultsSection(context, controller, settings),
          ),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 3,
            child: _buildSubtitlesSection(context, controller, settings),
          ),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 4,
            child: _buildCookiesSection(context, controller, settings),
          ),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 5,
            child: _buildEngineSection(context, controller),
          ),
          const SizedBox(height: 14),
          const StaggeredItem(index: 6, child: _AboutCard()),
        ],
      ),
    );
  }

  Widget _buildDirectorySection(
    BuildContext context,
    AppController controller,
    AppSettings settings,
  ) {
    return _SettingsCard(
      icon: Icons.folder_outlined,
      title: 'Папка сохранения',
      subtitle: 'Сюда попадают видео, аудио, обложки и субтитры',
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    settings.downloadDirectory.isEmpty
                        ? 'Определяется автоматически'
                        : settings.downloadDirectory,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: controller.chooseDownloadDirectory,
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Выбрать папку'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultsSection(
    BuildContext context,
    AppController controller,
    AppSettings settings,
  ) {
    return _SettingsCard(
      icon: Icons.tune_rounded,
      title: 'Загрузки по умолчанию',
      subtitle: 'Можно изменить для каждого видео перед скачиванием',
      child: Column(
        children: [
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                DropdownButtonFormField<DownloadKind>(
                  initialValue: settings.defaultKind,
                  decoration: const InputDecoration(labelText: 'Тип файла'),
                  items: const [
                    DropdownMenuItem(
                      value: DownloadKind.video,
                      child: Text('Видео'),
                    ),
                    DropdownMenuItem(
                      value: DownloadKind.audio,
                      child: Text('MP3'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        settings.copyWith(defaultKind: value),
                      );
                    }
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: settings.defaultQuality,
                  decoration: const InputDecoration(labelText: 'Качество'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Лучшее')),
                    DropdownMenuItem(value: 2160, child: Text('До 4K')),
                    DropdownMenuItem(value: 1440, child: Text('До 1440p')),
                    DropdownMenuItem(value: 1080, child: Text('До 1080p')),
                    DropdownMenuItem(value: 720, child: Text('До 720p')),
                    DropdownMenuItem(value: 480, child: Text('До 480p')),
                    DropdownMenuItem(value: 360, child: Text('До 360p')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        settings.copyWith(defaultQuality: value),
                      );
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: settings.videoContainer,
                  decoration: const InputDecoration(labelText: 'Видеоформат'),
                  items: const [
                    DropdownMenuItem(value: 'mp4', child: Text('MP4')),
                    DropdownMenuItem(value: 'webm', child: Text('WebM')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        settings.copyWith(videoContainer: value),
                      );
                    }
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: settings.audioBitrate,
                  decoration: const InputDecoration(labelText: 'Битрейт MP3'),
                  items: const [
                    DropdownMenuItem(value: 128, child: Text('128 кбит/с')),
                    DropdownMenuItem(value: 192, child: Text('192 кбит/с')),
                    DropdownMenuItem(value: 256, child: Text('256 кбит/с')),
                    DropdownMenuItem(value: 320, child: Text('320 кбит/с')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        settings.copyWith(audioBitrate: value),
                      );
                    }
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: settings.maxConcurrent,
                  decoration: const InputDecoration(labelText: 'Одновременно'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 загрузка')),
                    DropdownMenuItem(value: 2, child: Text('2 загрузки')),
                    DropdownMenuItem(value: 3, child: Text('3 загрузки')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateSettings(
                        settings.copyWith(maxConcurrent: value),
                      );
                    }
                  },
                ),
              ];
              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    for (final field in fields) ...[
                      field,
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final field in fields)
                    SizedBox(
                      width: (constraints.maxWidth - 24) / 3,
                      child: field,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesSection(
    BuildContext context,
    AppController controller,
    AppSettings settings,
  ) {
    return _SettingsCard(
      icon: Icons.subtitles_outlined,
      title: 'Обложка и субтитры',
      subtitle: 'Дополнительные файлы и постобработка',
      child: Column(
        children: [
          const SizedBox(height: 12),
          DropdownButtonFormField<ThumbnailMode>(
            initialValue: settings.thumbnailMode,
            decoration: const InputDecoration(labelText: 'Сохранение обложки'),
            items: const [
              DropdownMenuItem(
                value: ThumbnailMode.none,
                child: Text('Не сохранять'),
              ),
              DropdownMenuItem(
                value: ThumbnailMode.separate,
                child: Text('Отдельным файлом'),
              ),
              DropdownMenuItem(
                value: ThumbnailMode.embed,
                child: Text('Встроить в медиа'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.updateSettings(
                  settings.copyWith(thumbnailMode: value),
                );
              }
            },
          ),
          SwitchListTile.adaptive(
            value: settings.writeSubtitles,
            onChanged: (value) => controller.updateSettings(
              settings.copyWith(writeSubtitles: value),
            ),
            contentPadding: EdgeInsets.zero,
            title: const Text('Скачивать субтитры'),
          ),
          SwitchListTile.adaptive(
            value: settings.autoSubtitles,
            onChanged: (value) => controller.updateSettings(
              settings.copyWith(autoSubtitles: value),
            ),
            contentPadding: EdgeInsets.zero,
            title: const Text('Включая автоматические субтитры'),
          ),
          SwitchListTile.adaptive(
            value: settings.embedSubtitles,
            onChanged: (value) => controller.updateSettings(
              settings.copyWith(embedSubtitles: value),
            ),
            contentPadding: EdgeInsets.zero,
            title: const Text('Встраивать субтитры в видео'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _languagesController,
            decoration: const InputDecoration(
              labelText: 'Языки субтитров',
              hintText: 'ru,en или all',
              prefixIcon: Icon(Icons.translate_rounded),
            ),
            onChanged: (value) => controller.updateSettings(
              settings.copyWith(subtitleLanguages: value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookiesSection(
    BuildContext context,
    AppController controller,
    AppSettings settings,
  ) {
    return _SettingsCard(
      icon: Icons.verified_user_outlined,
      title: 'Авторизация и приватные видео',
      subtitle: 'Cookies хранятся локально в зашифрованном хранилище. Пароли не нужны.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: settings.hasCookies
                  ? AppColors.successSoft
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  settings.hasCookies
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: settings.hasCookies
                      ? AppColors.success
                      : AppColors.muted,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    settings.hasCookies
                        ? 'Cookies.txt импортирован и будет использован для новых загрузок'
                        : 'Cookies не добавлены. Публичные видео доступны без авторизации.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (Platform.isWindows && !settings.hasCookies) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: settings.cookiesBrowser,
              decoration: const InputDecoration(
                labelText: 'Или использовать текущую сессию браузера',
                helperText: 'yt-dlp читает cookies локально. Закройте браузер, если база заблокирована.',
              ),
              items: const [
                DropdownMenuItem(
                  value: '',
                  child: Text('Не использовать браузер'),
                ),
                DropdownMenuItem(value: 'chrome', child: Text('Google Chrome')),
                DropdownMenuItem(value: 'edge', child: Text('Microsoft Edge')),
                DropdownMenuItem(
                  value: 'firefox',
                  child: Text('Mozilla Firefox'),
                ),
                DropdownMenuItem(value: 'brave', child: Text('Brave')),
                DropdownMenuItem(value: 'opera', child: Text('Opera')),
                DropdownMenuItem(value: 'vivaldi', child: Text('Vivaldi')),
                DropdownMenuItem(value: 'chromium', child: Text('Chromium')),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(
                    settings.copyWith(cookiesBrowser: value),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.importCookiesFile,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  settings.hasCookies
                      ? 'Заменить cookies.txt'
                      : 'Импортировать cookies.txt',
                ),
              ),
              if (settings.hasCookies)
                OutlinedButton.icon(
                  onPressed: controller.clearCookies,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Удалить cookies'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineSection(BuildContext context, AppController controller) {
    final status = controller.engineStatus;
    final available = status?.available ?? false;
    return _SettingsCard(
      icon: Icons.memory_rounded,
      title: 'Компоненты загрузчика',
      subtitle:
          'yt-dlp, FFmpeg и JavaScript runtime работают только на устройстве',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: available ? AppColors.successSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Icon(
                  available
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: available ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        available
                            ? 'Движок готов к работе'
                            : 'Нужна проверка компонентов',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status == null
                            ? 'Проверяем…'
                            : 'Версия ${status.version} · ${status.description}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.updatingEngine
                    ? null
                    : controller.updateEngine,
                icon: controller.updatingEngine
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt_rounded),
                label: Text(
                  controller.updatingEngine ? 'Обновляем…' : 'Обновить движок',
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.refreshEngineStatus,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Проверить снова'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageIfNeeded(AppController controller) {
    final message = controller.actionMessage;
    if (message == null || message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.actionMessage != message) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      controller.consumeActionMessage();
    });
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 44, radius: 15),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orsofey Downloader',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  'Версия 1.0.0 · GPL-3.0\nСкачивайте только материалы, которые имеете право сохранять.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.64)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
