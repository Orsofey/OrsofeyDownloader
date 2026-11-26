import 'package:flutter/material.dart';

import 'core/services/app_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/queue/queue_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/app_scope.dart';
import 'shared/widgets/ui.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'Orsofey Downloader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _handledNavigationRequest = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (controller.navigationRequest != _handledNavigationRequest) {
      _handledNavigationRequest = controller.navigationRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 1);
      });
    }
  }

  static const _destinations = [
    _Destination(
      icon: Icons.download_outlined,
      selectedIcon: Icons.download_rounded,
      label: 'Скачать',
    ),
    _Destination(
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt_rounded,
      label: 'Очередь',
    ),
    _Destination(
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      label: 'История',
    ),
    _Destination(
      icon: Icons.tune_rounded,
      selectedIcon: Icons.tune_rounded,
      label: 'Настройки',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (!controller.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 900;
    final body = IndexedStack(
      index: _index,
      children: const [
        HomeScreen(),
        QueueScreen(),
        HistoryScreen(),
        SettingsScreen(),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: BlurredBackdrop(intensity: 1.25)),
          SafeArea(
            child: compact
                ? body
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopSidebar(
                        currentIndex: _index,
                        onSelected: (value) => setState(() => _index = value),
                        destinations: _destinations,
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 20, 24, 20),
                              child: body,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: AppColors.surface.withValues(alpha: 0.96),
                indicatorColor: AppColors.primarySoft,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: 70,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primaryDeep : AppColors.muted,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<_Destination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 258,
      margin: const EdgeInsets.fromLTRB(20, 20, 8, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 22),
            child: Row(
              children: [
                const BrandMark(size: 46, radius: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orsofey',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Downloader',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < destinations.length; index++)
            _NavItem(
              destination: destinations[index],
              selected: currentIndex == index,
              onTap: () => onSelected(index),
            ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Локальная работа\nбез сервера',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 4,
                height: selected ? 22 : 0,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  key: ValueKey(selected),
                  color: selected ? AppColors.primary : AppColors.muted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primaryDeep : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
