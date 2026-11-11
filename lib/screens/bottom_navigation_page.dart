/*
 *     Copyright (C) 2026 Stemkara Authors
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Stemkara is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Stemkara is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:ui' show ImageFilter;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musify/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  late final _miniPlayerVisibilityStream = audioHandler.mediaItem
      .map((mediaItem) => mediaItem != null)
      .distinct();

  bool? _previousOfflineMode;

  /// Track the previously selected shell branch to detect reselects.
  int? _previousShellIndex;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.child.currentIndex;
        if (currentIndex != 0) {
          widget.child.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: offlineMode,
        builder: (context, isOfflineMode, _) {
          if (_previousOfflineMode != null &&
              _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          return LayoutBuilder(
            builder: (context, constraints) {
              final colorScheme = Theme.of(context).colorScheme;
              final isLargeScreen = MediaQuery.of(context).size.width >= 600;
              final items = _getNavigationItems(isOfflineMode);

              return Scaffold(
                backgroundColor: colorScheme.surface,
                body: SafeArea(
                  child: Row(
                    children: [
                      if (isLargeScreen)
                        _DesktopSidebar(
                          items: items,
                          currentIndex: _getCurrentIndex(items, isOfflineMode),
                          onDestinationSelected: (index) =>
                              _onTabTapped(index, items),
                        ),
                      Expanded(
                        child: ColoredBox(
                          color: colorScheme.surface,
                          child: StreamBuilder<bool>(
                            initialData: audioHandler.mediaItem.value != null,
                            stream: _miniPlayerVisibilityStream,
                            builder: (context, snapshot) {
                              final mediaQuery = MediaQuery.of(context);
                              final isMiniPlayerVisible = snapshot.data ?? false;
                              final bottomPadding = !isMiniPlayerVisible
                                  ? mediaQuery.padding.bottom
                                  : mediaQuery.padding.bottom +
                                        miniPlayerTotalHeight;

                              return Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  MediaQuery(
                                    data: mediaQuery.copyWith(
                                      padding: mediaQuery.padding.copyWith(
                                        bottom: bottomPadding,
                                      ),
                                    ),
                                    child: widget.child,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: MiniPlayer(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: !isLargeScreen
                    ? NavigationBar(
                        selectedIndex: _getCurrentIndex(items, isOfflineMode),
                        labelBehavior: languageSetting == const Locale('en', '')
                            ? NavigationDestinationLabelBehavior
                                  .onlyShowSelected
                            : NavigationDestinationLabelBehavior.alwaysHide,
                        onDestinationSelected: (index) =>
                            _onTabTapped(index, items),
                        destinations: items
                            .map(
                              (item) => NavigationDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
                                label: item.label,
                              ),
                            )
                            .toList(),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: FluentIcons.home_24_regular,
        selectedIcon: FluentIcons.home_24_filled,
        label: context.l10n?.home ?? 'Home',
        shellIndex: 0,
      ),
    ];

    // Only add search tab in online mode
    if (!isOfflineMode) {
      items.add(
        _NavigationItem(
          icon: FluentIcons.search_24_regular,
          selectedIcon: FluentIcons.search_24_filled,
          label: context.l10n?.search ?? 'Search',
          shellIndex: 1,
        ),
      );
    }

    items.addAll([
      _NavigationItem(
        icon: FluentIcons.book_24_regular,
        selectedIcon: FluentIcons.book_24_filled,
        label: context.l10n?.library ?? 'Library',
        shellIndex: 2,
      ),
      _NavigationItem(
        icon: FluentIcons.settings_24_regular,
        selectedIcon: FluentIcons.settings_24_filled,
        label: context.l10n?.settings ?? 'Settings',
        shellIndex: 3,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    final currentRoute = GoRouterState.of(context).matchedLocation;

    // If we're switching to offline mode and currently on search tab
    if (isOfflineMode && currentRoute.startsWith('/search')) {
      // Navigate to home
      widget.child.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];
      final isReselect = _previousShellIndex == item.shellIndex;

      // Close any open bottom sheet before switching tabs
      closeCurrentBottomSheet();

      // If user taps the same tab again, reset it to initial state.
      // Otherwise, preserve the branch state.
      if (isReselect) {
        widget.child.goBranch(item.shellIndex, initialLocation: true);
      } else {
        widget.child.goBranch(item.shellIndex);
      }

      _previousShellIndex = item.shellIndex;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.child.currentIndex;

    if (items.isEmpty) return 0;

    // Try to find the current shell index in the available items
    final matchedIndex = items.indexWhere(
      (item) => item.shellIndex == currentShellIndex,
    );
    if (matchedIndex != -1) return matchedIndex;

    // If the Search branch (1) is active but Search is hidden in offline mode,
    // fall back to the Home tab.
    if (isOfflineMode && currentShellIndex == 1) return 0;

    // Final fallback: return the first tab to keep UI in a valid state.
    return 0;
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shellIndex,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int shellIndex;
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.items,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final List<_NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final searchItem = items.where((i) => i.shellIndex == 1).firstOrNull;
    final homeItem = items.where((i) => i.shellIndex == 0).firstOrNull;
    final libraryItem = items.where((i) => i.shellIndex == 2).firstOrNull;
    final settingsItem = items.where((i) => i.shellIndex == 3).firstOrNull;

    return ClipRect(
      child: SizedBox(
        width: 80,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161618).withValues(alpha: 0.72)
                        : const Color(0xFFF6F6F8).withValues(alpha: 0.82),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.02),
                              Colors.black.withValues(alpha: 0.20),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.90),
                              const Color(0xFFECECEC).withValues(alpha: 0.80),
                            ],
                    ),
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.09),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -15,
              left: -10,
              width: 100,
              height: 100,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark
                                ? const Color(0xFFE5354B)
                                : const Color(0xFFFF9E99))
                            .withValues(alpha: isDark ? 0.14 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.15,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/musify_icon.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (searchItem != null) ...[
                  _SidebarItemWidget(
                    item: searchItem,
                    isSelected: items.indexOf(searchItem) == currentIndex,
                    onTap: () =>
                        onDestinationSelected(items.indexOf(searchItem)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 44,
                    height: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ],
                if (homeItem != null) ...[
                  _SidebarItemWidget(
                    item: homeItem,
                    isSelected: items.indexOf(homeItem) == currentIndex,
                    onTap: () => onDestinationSelected(items.indexOf(homeItem)),
                  ),
                  const SizedBox(height: 10),
                ],
                if (libraryItem != null) ...[
                  _SidebarItemWidget(
                    item: libraryItem,
                    isSelected: items.indexOf(libraryItem) == currentIndex,
                    onTap: () =>
                        onDestinationSelected(items.indexOf(libraryItem)),
                  ),
                  const SizedBox(height: 10),
                ],
                const Spacer(),
                if (settingsItem != null) ...[
                  _SidebarItemWidget(
                    item: settingsItem,
                    isSelected: items.indexOf(settingsItem) == currentIndex,
                    onTap: () =>
                        onDestinationSelected(items.indexOf(settingsItem)),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItemWidget extends StatefulWidget {
  const _SidebarItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? colorScheme.primary.withValues(
                          alpha: colorScheme.brightness == Brightness.light
                              ? 0.12
                              : 0.22,
                        )
                      : (_isHovered
                          ? colorScheme.onSurface.withValues(
                              alpha: colorScheme.brightness == Brightness.light
                                  ? 0.06
                                  : 0.10,
                            )
                          : Colors.transparent),
                ),
                child: Icon(
                  isSelected ? widget.item.selectedIcon : widget.item.icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
