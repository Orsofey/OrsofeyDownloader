import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/media_info.dart';
import '../../core/services/app_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/app_scope.dart';
import '../../shared/widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _linkController = TextEditingController();
  final _subtitleController = TextEditingController(text: 'ru,en');
  bool _initialized = false;
  late DownloadKind _kind;
  late int _quality;
  late String _container;
  late int _audioBitrate;
  late ThumbnailMode _thumbnailMode;
  late bool _writeSubtitles;
  late bool _autoSubtitles;
  late bool _embedSubtitles;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final settings = AppScope.of(context).settings;
    _kind = settings.defaultKind;
    _quality = settings.defaultQuality;
    _container = settings.videoContainer;
    _audioBitrate = settings.audioBitrate;
    _thumbnailMode = settings.thumbnailMode;
    _writeSubtitles = settings.writeSubtitles;
    _autoSubtitles = settings.autoSubtitles;
    _embedSubtitles = settings.embedSubtitles;
    _subtitleController.text = settings.subtitleLanguages;
    _initialized = true;
  }

  @override
  void dispose() {
    _linkController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 8,
          compact ? 18 : 8,
          compact ? 20 : 8,
          compact ? 28 : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredItem(index: 0, child: _buildHeader(context, controller)),
            const SizedBox(height: 24),
            StaggeredItem(index: 1, child: _buildLinkCard(context, controller)),
            if (controller.analyzing) ...[
              const SizedBox(height: 18),
              const StaggeredItem(index: 2, child: _AnalyzingCard()),
            ],
            if (controller.inspectError != null) ...[
              const SizedBox(height: 16),
              StaggeredItem(
                index: 2,
                child: _ErrorCard(message: controller.inspectError!),
              ),
            ],
            if (controller.preview != null) ...[
              const SizedBox(height: 18),
              StaggeredItem(
                index: 2,
                child: _buildPreview(context, controller),
              ),
            ],
            if (!controller.hasPreview &&
                !controller.analyzing &&
                controller.inspectError == null) ...[
              const SizedBox(height: 24),
              StaggeredItem(index: 2, child: _buildFeatureStrip(context)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppController controller) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                const Row(
                  children: [
                    BrandMark(size: 38, radius: 13),
                    SizedBox(width: 10),
                    Text(
                      'Orsofey',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ТВОЯ БИБЛИОТЕКА ВИДЕО',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.primaryDeep),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                compact
                    ? 'Сохраняйте видео\nв один клик'
                    : 'Сохраняйте видео.\nБез лишнего.',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontSize: compact ? 31 : 38, height: 1.15),
              ),
              const SizedBox(height: 12),
              Text(
                'Вставьте ссылку — выберите качество — готово.\nВсе загрузки остаются на вашем устройстве.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: compact ? 14.5 : 16),
              ),
            ],
          ),
        ),
        if (!compact) ...[const SizedBox(width: 20), const _FloatingLogo()],
      ],
    );
  }

  Widget _buildLinkCard(BuildContext context, AppController controller) {
    final analyzing = controller.analyzing;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: 24,
      shadows: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.09),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final field = TextField(
            controller: _linkController,
            enabled: !analyzing,
            autofocus: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'https://youtube.com/watch... или ссылка TikTok / VK',
              prefixIcon: const Icon(Icons.link_rounded, size: 23),
              suffixIcon: IconButton(
                tooltip: 'Вставить из буфера',
                onPressed: analyzing ? null : _pasteLink,
                icon: const Icon(Icons.content_paste_rounded, size: 20),
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: analyzing ? null : (_) => _analyze(),
          );
          final button = PressableScale(
            enabled: !analyzing,
            onTap: analyzing ? null : _analyze,
            child: FilledButton.icon(
              onPressed: analyzing ? null : _analyze,
              icon: analyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 21),
              label: Text(analyzing ? 'Анализ...' : 'Получить видео'),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [field, const SizedBox(height: 10), button],
            );
          }
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureStrip(BuildContext context) {
    final items = [
      (Icons.high_quality_outlined, 'До 4K', 'Выбирайте разрешение'),
      (Icons.audio_file_outlined, 'Видео и MP3', 'Нужный формат'),
      (Icons.playlist_add_rounded, 'Плейлисты', 'Сохраняйте серию'),
      (Icons.shield_outlined, 'Без сервера', 'Только ваше устройство'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 680 ? 2 : 4;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.$1,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPreview(BuildContext context, AppController controller) {
    final info = controller.preview as MediaInfo;
    final heights = info.availableHeights;
    final qualities = <int>{0, ...heights}.toList();
    if (qualities.length == 1) qualities.addAll([1080, 720, 480, 360]);
    if (!qualities.contains(_quality)) _quality = 0;
    final extensions = info.availableVideoExtensions;
    if (!extensions.contains(_container)) _container = extensions.first;

    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Настройка загрузки',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: controller.clearPreview,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MediaHeader(info: info),
          if (info.isPlaylist) ...[
            const SizedBox(height: 20),
            _PlaylistSelector(controller: controller, info: info),
          ],
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _buildTypeSelector(),
          const SizedBox(height: 20),
          if (_kind == DownloadKind.video) ...[
            Text('Качество', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final quality in qualities)
                  ChoiceChip(
                    label: _QualityLabel(
                      quality: quality,
                      size: info.estimatedSize(quality, _container),
                    ),
                    selected: _quality == quality,
                    onSelected: (_) => setState(() => _quality = quality),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Контейнер', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final extension in extensions)
                  ChoiceChip(
                    label: Text(extension.toUpperCase()),
                    selected: _container == extension,
                    onSelected: (_) => setState(() => _container = extension),
                  ),
              ],
            ),
          ] else ...[
            Text('Битрейт MP3', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final bitrate in [128, 192, 256, 320])
                  ChoiceChip(
                    label: Text('$bitrate кбит/с'),
                    selected: _audioBitrate == bitrate,
                    onSelected: (_) => setState(() => _audioBitrate = bitrate),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _AdvancedOptions(
            thumbnailMode: _thumbnailMode,
            onThumbnailModeChanged: (value) =>
                setState(() => _thumbnailMode = value),
            writeSubtitles: _writeSubtitles,
            onWriteSubtitlesChanged: (value) =>
                setState(() => _writeSubtitles = value),
            autoSubtitles: _autoSubtitles,
            onAutoSubtitlesChanged: (value) =>
                setState(() => _autoSubtitles = value),
            embedSubtitles: _embedSubtitles,
            onEmbedSubtitlesChanged: (value) =>
                setState(() => _embedSubtitles = value),
            subtitleController: _subtitleController,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.settings.downloadDirectory.isEmpty
                        ? 'Папка будет выбрана автоматически'
                        : controller.settings.downloadDirectory,
                    maxLines: 1,
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
          const SizedBox(height: 18),
          PressableScale(
            onTap: () => _enqueue(controller),
            child: FilledButton.icon(
              onPressed: () => _enqueue(controller),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                info.isPlaylist
                    ? 'Скачать выбранные (${controller.selectedPlaylistEntries.length})'
                    : 'Скачать ${_kind == DownloadKind.audio ? 'аудио' : 'видео'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<DownloadKind>(
      segments: const [
        ButtonSegment(
          value: DownloadKind.video,
          label: Text('Видео'),
          icon: Icon(Icons.video_file_outlined),
        ),
        ButtonSegment(
          value: DownloadKind.audio,
          label: Text('Только звук'),
          icon: Icon(Icons.audio_file_outlined),
        ),
      ],
      selected: {_kind},
      onSelectionChanged: (selection) =>
          setState(() => _kind = selection.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceMuted,
        selectedBackgroundColor: AppColors.surface,
        selectedForegroundColor: AppColors.primaryDeep,
        foregroundColor: AppColors.muted,
        side: BorderSide.none,
        visualDensity: VisualDensity.standard,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _linkController.text = data!.text!.trim();
      _linkController.selection = TextSelection.collapsed(
        offset: _linkController.text.length,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    await AppScope.of(context).analyze(_linkController.text);
  }

  Future<void> _enqueue(AppController controller) async {
    FocusScope.of(context).unfocus();
    final created = await controller.enqueue(
      kind: _kind,
      quality: _quality,
      container: _container,
      audioBitrate: _audioBitrate,
      thumbnailMode: _thumbnailMode,
      writeSubtitles: _writeSubtitles || _embedSubtitles,
      autoSubtitles: _autoSubtitles,
      embedSubtitles: _embedSubtitles,
      subtitleLanguages: _subtitleController.text,
    );
    if (!mounted || created.isEmpty) return;
    controller.openQueue();
    _linkController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created.length == 1
              ? 'Видео добавлено в очередь загрузки'
              : 'Добавлено в очередь: ${created.length} видео',
        ),
        action: SnackBarAction(label: 'ОК', onPressed: () {}),
      ),
    );
  }
}

class _QualityLabel extends StatelessWidget {
  const _QualityLabel({required this.quality, this.size});

  final int quality;
  final int? size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(quality == 0 ? 'Лучшее' : '${quality}p'),
        if (size != null)
          Text(
            '≈ ${formatBytes(size)}',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontSize: 9, letterSpacing: 0),
          ),
      ],
    );
  }
}

class _FloatingLogo extends StatelessWidget {
  const _FloatingLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarySoft, AppColors.lavender],
        ),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 19,
            right: 19,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Center(child: BrandMark(size: 66, radius: 22)),
        ],
      ),
    );
  }
}

class _MediaHeader extends StatelessWidget {
  const _MediaHeader({required this.info});

  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SourceBadge(source: info.source),
        const SizedBox(height: 10),
        Text(
          info.title,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (info.uploader != null) info.uploader!,
            if (info.duration != null) formatDuration(info.duration),
            if (info.isPlaylist) pluralFiles(info.entries.length),
          ].join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThumbnailView(
            url: info.thumbnailUrl,
            source: info.source,
            width: double.infinity,
            height: 170,
            radius: 18,
          ),
          const SizedBox(height: 16),
          details,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThumbnailView(
          url: info.thumbnailUrl,
          source: info.source,
          width: 190,
          height: 112,
          radius: 18,
        ),
        const SizedBox(width: 18),
        Expanded(child: details),
      ],
    );
  }
}

class _PlaylistSelector extends StatelessWidget {
  const _PlaylistSelector({required this.controller, required this.info});

  final AppController controller;
  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Плейлист · ${pluralFiles(info.entries.length)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => controller.selectAllPlaylistEntries(true),
                  child: const Text('Все'),
                ),
                TextButton(
                  onPressed: () => controller.selectAllPlaylistEntries(false),
                  child: const Text('Снять'),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: info.entries.length,
              itemBuilder: (context, index) {
                final entry = info.entries[index];
                final selected = controller.selectedPlaylistEntries.contains(
                  entry.index,
                );
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => controller.togglePlaylistEntry(entry.index),
                  dense: true,
                  activeColor: AppColors.primary,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  title: Text(
                    '${entry.index}. ${entry.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.ink),
                  ),
                  subtitle: entry.duration != null
                      ? Text(formatDuration(entry.duration))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  const _AdvancedOptions({
    required this.thumbnailMode,
    required this.onThumbnailModeChanged,
    required this.writeSubtitles,
    required this.onWriteSubtitlesChanged,
    required this.autoSubtitles,
    required this.onAutoSubtitlesChanged,
    required this.embedSubtitles,
    required this.onEmbedSubtitlesChanged,
    required this.subtitleController,
  });

  final ThumbnailMode thumbnailMode;
  final ValueChanged<ThumbnailMode> onThumbnailModeChanged;
  final bool writeSubtitles;
  final ValueChanged<bool> onWriteSubtitlesChanged;
  final bool autoSubtitles;
  final ValueChanged<bool> onAutoSubtitlesChanged;
  final bool embedSubtitles;
  final ValueChanged<bool> onEmbedSubtitlesChanged;
  final TextEditingController subtitleController;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: AppColors.primary,
      title: Text(
        'Дополнительно',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        'Обложка, субтитры',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        const SizedBox(height: 14),
        Text('Обложка', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Не сохранять'),
              selected: thumbnailMode == ThumbnailMode.none,
              onSelected: (_) => onThumbnailModeChanged(ThumbnailMode.none),
            ),
            ChoiceChip(
              label: const Text('Отдельным файлом'),
              selected: thumbnailMode == ThumbnailMode.separate,
              onSelected: (_) => onThumbnailModeChanged(ThumbnailMode.separate),
            ),
            ChoiceChip(
              label: const Text('Встроить'),
              selected: thumbnailMode == ThumbnailMode.embed,
              onSelected: (_) => onThumbnailModeChanged(ThumbnailMode.embed),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          value: writeSubtitles,
          onChanged: onWriteSubtitlesChanged,
          contentPadding: EdgeInsets.zero,
          title: const Text('Сохранить субтитры'),
          subtitle: const Text('Скачать доступные языки отдельно'),
        ),
        SwitchListTile.adaptive(
          value: autoSubtitles,
          onChanged: onAutoSubtitlesChanged,
          contentPadding: EdgeInsets.zero,
          title: const Text('Включая автоматические'),
          subtitle: const Text('Если созданы площадкой'),
        ),
        SwitchListTile.adaptive(
          value: embedSubtitles,
          onChanged: onEmbedSubtitlesChanged,
          contentPadding: EdgeInsets.zero,
          title: const Text('Встроить субтитры в видео'),
        ),
        if (writeSubtitles || embedSubtitles || autoSubtitles) ...[
          const SizedBox(height: 8),
          TextField(
            controller: subtitleController,
            decoration: const InputDecoration(
              labelText: 'Языки субтитров',
              hintText: 'ru,en или all',
              helperText: 'Через запятую. Для всех языков укажите all.',
              prefixIcon: Icon(Icons.subtitles_outlined),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 112,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Container(height: 17, color: AppColors.surfaceMuted),
                    const SizedBox(height: 12),
                    Container(height: 12, color: AppColors.surfaceMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Получаем информацию и доступные форматы…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
