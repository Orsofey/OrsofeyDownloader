import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/models/media_info.dart';
import '../../core/theme/app_colors.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.color = AppColors.surface,
    this.borderColor,
    this.gradient,
    this.shadows,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Material(
      color: gradient == null ? color : Colors.transparent,
      elevation: shadows == null ? 1 : 0,
      shadowColor: AppColors.ink.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: borderColor ?? AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: width,
        height: height,
        decoration: BoxDecoration(gradient: gradient),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class StaggeredItem extends StatefulWidget {
  const StaggeredItem({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelayMs = 35,
  });

  final Widget child;
  final int index;
  final int baseDelayMs;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: widget.index * widget.baseDelayMs),
      () {
        if (mounted) setState(() => _visible = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.035),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42, this.radius = 14});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(Icons.south_rounded, color: Colors.white, size: size * 0.52),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.source,
    this.compact = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final MediaSource source;
  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;

  Color get _tint => switch (source) {
    MediaSource.youtube => const Color(0xFFFFE7E9),
    MediaSource.tiktok => const Color(0xFFE4F6F1),
    MediaSource.vk => const Color(0xFFE7F0FF),
    MediaSource.unknown => AppColors.surfaceMuted,
  };

  Color get _foreground => switch (source) {
    MediaSource.youtube => const Color(0xFFA9333F),
    MediaSource.tiktok => const Color(0xFF186F5E),
    MediaSource.vk => const Color(0xFF2B5D9B),
    MediaSource.unknown => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final background = backgroundColor ?? _tint;
    final color = foregroundColor ?? _foreground;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (source) {
              MediaSource.youtube => Icons.play_arrow_rounded,
              MediaSource.tiktok => Icons.music_note_rounded,
              MediaSource.vk => Icons.video_library_rounded,
              MediaSource.unknown => Icons.link_rounded,
            },
            size: compact ? 12 : 14,
            color: color,
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              source.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    required this.background,
    this.icon,
  });

  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ThumbnailView extends StatelessWidget {
  const ThumbnailView({
    super.key,
    this.url,
    required this.source,
    this.width = 132,
    this.height = 78,
    this.radius = 16,
  });

  final String? url;
  final MediaSource source;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: switch (source) {
                    MediaSource.youtube => [
                      AppColors.peach,
                      AppColors.lavender,
                    ],
                    MediaSource.tiktok => [
                      AppColors.mint,
                      AppColors.primarySoft,
                    ],
                    MediaSource.vk => [AppColors.sky, AppColors.primarySoft],
                    MediaSource.unknown => [
                      AppColors.surfaceMuted,
                      AppColors.lavender,
                    ],
                  },
                ),
              ),
              child: Icon(
                switch (source) {
                  MediaSource.youtube => Icons.play_arrow_rounded,
                  MediaSource.tiktok => Icons.music_note_rounded,
                  MediaSource.vk => Icons.video_library_rounded,
                  MediaSource.unknown => Icons.link_rounded,
                },
                color: AppColors.ink.withValues(alpha: 0.14),
                size: 34,
              ),
            ),
            if (url != null && url!.isNotEmpty)
              Image.network(
                url!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSync) {
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 7,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.surfaceStrong,
  });

  final double value;
  final double height;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            ColoredBox(color: backgroundColor, child: const SizedBox.expand()),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: safeValue),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedValue,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.78), color],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BlurredBackdrop extends StatelessWidget {
  const BlurredBackdrop({super.key, this.intensity = 1});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80 * intensity,
            left: -50 * intensity,
            child: _Blob(
              size: 260 * intensity,
              color: AppColors.lavender.withValues(alpha: 0.72),
            ),
          ),
          Positioned(
            top: 120 * intensity,
            right: -90 * intensity,
            child: _Blob(
              size: 220 * intensity,
              color: AppColors.peach.withValues(alpha: 0.62),
            ),
          ),
          Positioned(
            bottom: -110 * intensity,
            left: 100 * intensity,
            child: _Blob(
              size: 250 * intensity,
              color: AppColors.mint.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
        child: const SizedBox.expand(),
      ),
    );
  }
}
