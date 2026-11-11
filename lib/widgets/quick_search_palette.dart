/*
 *     Copyright (C) 2026 Stemkara Authors
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

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/widgets/no_artwork_cube.dart';

class QuickSearchPalette extends StatefulWidget {
  const QuickSearchPalette({super.key});

  static bool _isShowing = false;

  static void toggle(BuildContext context) {
    if (_isShowing) {
      final navContext =
          NavigationManager.parentNavigatorKey.currentContext ?? context;
      Navigator.of(navContext, rootNavigator: true).pop();
    } else {
      show(context);
    }
  }

  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;

    final targetContext =
        NavigationManager.parentNavigatorKey.currentContext ?? context;

    await showGeneralDialog(
      context: targetContext,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black.withValues(alpha: 0.50),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) => const QuickSearchPalette(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

    _isShowing = false;
  }

  @override
  State<QuickSearchPalette> createState() => _QuickSearchPaletteState();
}

class _QuickSearchPaletteState extends State<QuickSearchPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _results = [];
  bool _isLoading = false;
  int _selectedIndex = 0;
  Timer? _debounce;
  int _searchRequestId = 0;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _focusNode.requestFocus();
  }

  void _loadRecentSearches() {
    try {
      final history =
          Hive.box('user').get('searchHistory', defaultValue: []) as List;
      _recentSearches = history.map((e) => e.toString()).take(6).toList();
    } catch (_) {
      _recentSearches = [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _selectedIndex = 0;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final reqId = ++_searchRequestId;
      try {
        final songs = await fetchSongsList(trimmed);
        if (!mounted || reqId != _searchRequestId) return;
        setState(() {
          _results = songs;
          _isLoading = false;
          _selectedIndex = 0;
        });
      } catch (_) {
        if (!mounted || reqId != _searchRequestId) return;
        setState(() {
          _results = [];
          _isLoading = false;
          _selectedIndex = 0;
        });
      }
    });
  }

  void _playSong(Map song) {
    audioHandler.playSong(song);
    if (mounted) Navigator.of(context).pop();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1).clamp(0, _results.length - 1);
        });
        _scrollToSelected();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1).clamp(0, _results.length - 1);
        });
        _scrollToSelected();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_results.isNotEmpty &&
          _selectedIndex >= 0 &&
          _selectedIndex < _results.length) {
        final song = _results[_selectedIndex];
        if (song is Map) {
          _playSong(song);
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 58.0;
    final targetOffset = (_selectedIndex * itemHeight) - 80.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  String _getImageUrl(Map song) {
    for (final k in ['lowResImage', 'image', 'highResImage', 'artworkPath']) {
      final v = song[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _getDurationText(Map song) {
    final d = song['duration'];
    if (d is String && d.isNotEmpty) return d;
    if (d is int && d > 0) {
      final m = d ~/ 60;
      final s = d % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final width = clampDouble(mediaQuery.size.width * 0.65, 480, 640);
    final maxHeight = mediaQuery.size.height * 0.70;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 72, left: 16, right: 16),
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: width,
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchField(colorScheme),
                      if (_isLoading)
                        LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: colorScheme.primary,
                        )
                      else
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.15),
                        ),
                      Flexible(child: _buildResultsList(colorScheme)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            FluentIcons.search_20_regular,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.60),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                FluentIcons.dismiss_16_regular,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                _searchController.clear();
                _onQueryChanged('');
              },
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList(ColorScheme colorScheme) {
    final query = _searchController.text.trim();

    if (query.isNotEmpty) {
      if (_results.isEmpty && !_isLoading) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          child: Center(
            child: Text(
              'No results for "$query"',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final item = _results[i];
          if (item is! Map) return const SizedBox.shrink();

          final isSelected = i == _selectedIndex;
          final title = item['title'] ?? 'Unknown';
          final artist = item['artist'] ?? '';
          final duration = _getDurationText(item);
          final imgUrl = _getImageUrl(item);

          return InkWell(
            onTap: () => _playSong(item),
            borderRadius: BorderRadius.circular(10),
            hoverColor: colorScheme.surfaceContainerHighest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const NullArtworkWidget(
                                    size: 40,
                                    borderRadius: 7,
                                    iconSize: 16,
                                  ),
                            )
                          : const NullArtworkWidget(
                              size: 40,
                              borderRadius: 7,
                              iconSize: 16,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (artist.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    if (_recentSearches.isNotEmpty) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              'Recent searches',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ..._recentSearches.map((term) {
            return InkWell(
              onTap: () {
                _searchController.text = term;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: term.length),
                );
                _onQueryChanged(term);
              },
              borderRadius: BorderRadius.circular(10),
              hoverColor: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.history_20_regular,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        term,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: Text(
          'Type to search music',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.60),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
