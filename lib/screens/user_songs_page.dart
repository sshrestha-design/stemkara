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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show logger, audioHandler;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/utilities/song_filtering.dart';
import 'package:musify/utilities/sort_utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/sort_chips.dart';

enum OfflineSortType { default_, title, artist, dateAdded }

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List _getDisplayList(List songsList) {
    var list = filterSongsByQuery(songsList, _searchQueryNotifier.value);
    if (widget.page == 'offline') {
      list = _sortOfflineSongsLocal(list, _getCurrentOfflineSortType());
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  OfflineSortType _getCurrentOfflineSortType() {
    return OfflineSortType.values.firstWhere(
      (e) => e.name == offlineSortSetting,
      orElse: () => OfflineSortType.default_,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = getTitle(widget.page, context);
    final icon = getIcon(widget.page);
    final isOfflineSongs = title == context.l10n!.offlineSongs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder(
        valueListenable: widget.page == 'liked'
            ? userLikedSongsList
            : widget.page == 'offline'
            ? userOfflineSongs
            : userRecentlyPlayed,
        builder: (_, songsList, __) => _buildCustomScrollView(
          title,
          icon,
          songsList.length,
          isOfflineSongs,
        ),
      ),
    );
  }

  Widget _buildCustomScrollView(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
  ) {
    final isDesktop = isDesktopPlatform || MediaQuery.sizeOf(context).width >= 700;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: isDesktop
                ? const EdgeInsets.fromLTRB(28, 20, 28, 0)
                : const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackNavigationBar(context, title),
                const SizedBox(height: 20),
                _buildModernHeroHeader(
                  context,
                  title,
                  icon,
                  songsLength,
                  isOfflineSongs,
                  isDesktop,
                ),
                if (isOfflineSongs && songsLength > 1) ...[
                  const SizedBox(height: 16),
                  SortChips<OfflineSortType>(
                    currentSortType: _getCurrentOfflineSortType(),
                    sortTypes: OfflineSortType.values,
                    sortTypeToString: _getSortTypeDisplayText,
                    onSelected: (type) {
                      setState(() {
                        addOrUpdateData<String>(
                          'settings',
                          'offlineSortType',
                          type.name,
                        );
                        offlineSortSetting = type.name;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                if (isDesktop && songsLength > 0) _buildDesktopTableHeader(context),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: isDesktop
              ? const EdgeInsets.symmetric(horizontal: 28)
              : const EdgeInsets.symmetric(horizontal: 16),
          sliver: buildSongList(title),
        ),
        if (songsLength == 0)
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                  ? 320
                  : 280,
            ),
          ),
        const SliverMiniPlayerBottomSpace(),
      ],
    );
  }

  Widget _buildBackNavigationBar(BuildContext context, String currentTitle) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Material(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/library');
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.chevron_left_20_filled, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Library',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          FluentIcons.chevron_right_16_regular,
          size: 14,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          currentTitle,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildModernHeroHeader(
    BuildContext context,
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
    bool isDesktop,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecentlyPlayed = widget.page == 'recents';

    final (LinearGradient gradient, Color primaryAccent, String badgeLabel, String subtitle) = switch (widget.page) {
      'liked' => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF3366), Color(0xFFFF5E3A)],
          ),
          const Color(0xFFFF3366),
          'LIBRARY COLLECTION',
          '$songsLength liked songs • Curated by you',
        ),
      'offline' => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00C7BE), Color(0xFF007AFF)],
          ),
          const Color(0xFF00C7BE),
          'OFFLINE STORAGE',
          '$songsLength offline songs • 4-Stem ready',
        ),
      'recents' => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
          ),
          const Color(0xFFFF9500),
          'LISTENING HISTORY',
          '$songsLength recently played tracks',
        ),
      _ => (
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primary, colorScheme.primaryContainer],
          ),
          colorScheme.primary,
          'COLLECTION',
          '$songsLength tracks',
        ),
    };

    final heroArtwork = Container(
      width: isDesktop ? 144 : 112,
      height: isDesktop ? 144 : 112,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryAccent.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: isDesktop ? 54 : 44,
          color: Colors.white,
        ),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: primaryAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeLabel,
            style: TextStyle(
              color: primaryAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: isDesktop ? 32 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(FluentIcons.play_24_filled, size: 18),
              label: Text(context.l10n!.play, style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: songsLength == 0
                  ? null
                  : () {
                      final songsList = widget.page == 'liked'
                          ? userLikedSongsList.value
                          : widget.page == 'offline'
                          ? userOfflineSongs.value
                          : userRecentlyPlayed.value;
                      var sortedList = songsList;
                      if (isOfflineSongs) {
                        sortedList = _sortOfflineSongsLocal(
                          songsList,
                          _getCurrentOfflineSortType(),
                        );
                      }
                      final playlist = {
                        'ytid': '',
                        'title': title,
                        'source': 'user-created',
                        'list': sortedList,
                      };
                      audioHandler.playPlaylistSong(
                        playlist: playlist,
                        songIndex: 0,
                      );
                    },
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHigh,
                foregroundColor: colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(FluentIcons.arrow_shuffle_24_filled, size: 18),
              label: Text(context.l10n!.shuffle, style: const TextStyle(fontWeight: FontWeight.w600)),
              onPressed: songsLength == 0
                  ? null
                  : () async {
                      final songs = widget.page == 'liked'
                          ? userLikedSongsList.value
                          : widget.page == 'offline'
                          ? userOfflineSongs.value
                          : userRecentlyPlayed.value;
                      if (songs.isEmpty) return;
                      await audioHandler.addPlaylistToQueue(
                        List<Map>.from(songs.whereType<Map>()),
                        replace: true,
                        shuffle: true,
                      );
                    },
            ),
            if (isRecentlyPlayed && songsLength > 0)
              _buildClearRecentsButton(colorScheme.primary),
            SizedBox(
              width: isDesktop ? 220 : double.infinity,
              height: 38,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (val) => _searchQueryNotifier.value = val,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filter tracks...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  prefixIcon: const Icon(FluentIcons.search_20_regular, size: 16),
                  suffixIcon: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (_, query, __) {
                      if (query.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(FluentIcons.dismiss_16_regular, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          _searchQueryNotifier.value = '';
                        },
                      );
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heroArtwork,
          const SizedBox(width: 24),
          Expanded(child: details),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              heroArtwork,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: primaryAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          details,
        ],
      );
    }
  }

  Widget _buildDesktopTableHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: headerStyle)),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: Text('TITLE', style: headerStyle)),
          Expanded(flex: 3, child: Text('ARTIST', style: headerStyle)),
          SizedBox(
            width: 80,
            child: Text(
              'TIME',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String getTitle(String page, BuildContext context) {
    return switch (page) {
      'liked' => context.l10n!.likedSongs,
      'offline' => context.l10n!.offlineSongs,
      'recents' => context.l10n!.recentlyPlayed,
      _ => context.l10n!.playlist,
    };
  }

  IconData getIcon(String page) {
    return switch (page) {
      'liked' => FluentIcons.heart_24_filled,
      'offline' => FluentIcons.arrow_download_24_filled,
      'recents' => FluentIcons.history_24_filled,
      _ => FluentIcons.heart_24_filled,
    };
  }

  Widget _buildClearRecentsButton(Color primaryColor) {
    return IconButton.filledTonal(
      icon: Icon(FluentIcons.delete_24_regular, color: primaryColor),
      iconSize: 20,
      tooltip: context.l10n!.clearRecentlyPlayedQuestion,
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return ConfirmationDialog(
              confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
              submitMessage: context.l10n!.clear,
              isDangerous: true,
              onCancel: () => Navigator.pop(context),
              onSubmit: () {
                Navigator.pop(context);
                userRecentlyPlayed.value = [];
                addOrUpdateData<List>('user', 'recentlyPlayedSongs', []);
                showToast(context, context.l10n!.recentlyPlayedMsg);
              },
            );
          },
        );
      },
    );
  }

  Widget buildSongList(String title) {
    final isLikedSongs = title == context.l10n!.likedSongs;
    final isRecentlyPlayed = title == context.l10n!.recentlyPlayed;
    final isOfflineSongs = title == context.l10n!.offlineSongs;

    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (_, searchQuery, __) {
        final songsList = widget.page == 'liked'
            ? userLikedSongsList.value
            : widget.page == 'offline'
            ? userOfflineSongs.value
            : userRecentlyPlayed.value;
        final listKeyScope = 'user_song_${widget.page}';
        final isSearching = searchQuery.isNotEmpty;
        final displayList = _getDisplayList(songsList);
        var sortedList = songsList;
        if (isOfflineSongs) {
          sortedList = _sortOfflineSongsLocal(
            songsList,
            _getCurrentOfflineSortType(),
          );
        }
        final playlist = {
          'ytid': '',
          'title': title,
          'source': 'user-created',
          'list': sortedList,
        };

        if (displayList.isEmpty) {
          final emptyIcon = isLikedSongs
              ? FluentIcons.heart_24_regular
              : FluentIcons.text_bullet_list_24_filled;
          return SliverToBoxAdapter(
            child: EmptyPlaylistState(
              icon: emptyIcon,
              message: isSearching
                  ? 'No songs matching "$searchQuery"'
                  : context.l10n!.playlistEmpty,
            ),
          );
        }

        return SliverList(
          key: isOfflineSongs && !isSearching
              ? ValueKey(_getCurrentOfflineSortType())
              : null,
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = displayList[index];
            final borderRadius = getItemBorderRadius(index, displayList.length);
            return RepaintBoundary(
              key: listItemKey(listKeyScope, index, song),
              child: _buildSongBar(
                song,
                index,
                borderRadius,
                playlist,
                isRecentSong: isRecentlyPlayed,
              ),
            );
          }, childCount: displayList.length),
        );
      },
    );
  }

  Widget _buildSongBar(
    Map song,
    int index,
    BorderRadius borderRadius,
    Map playlist, {
    bool isRecentSong = false,
  }) {
    final isLikedSongs = playlist['title'] == context.l10n!.likedSongs;

    return SongBar(
      key: listItemKey('user_song', index, song),
      song,
      true,
      onPlay: () {
        final fullIndex = PlaylistUtils.findSongIndexByYtid(
          playlist,
          song['ytid'],
        );
        if (fullIndex == -1) {
          logger.log(
            'Warning: Song ${song['ytid']} not found in full song list',
          );
        }
        audioHandler.playPlaylistSong(
          playlist: playlist,
          songIndex: fullIndex != -1 ? fullIndex : index,
        );
      },
      borderRadius: borderRadius,
      isRecentSong: isRecentSong,
      isFromLikedSongs: isLikedSongs,
    );
  }

  String _getSortTypeDisplayText(OfflineSortType type) {
    return switch (type) {
      OfflineSortType.default_ => context.l10n!.default_,
      OfflineSortType.title => context.l10n!.name,
      OfflineSortType.artist => context.l10n!.artist,
      OfflineSortType.dateAdded => context.l10n!.dateAdded,
    };
  }

  List _sortOfflineSongsLocal(List list, OfflineSortType type) {
    return switch (type) {
      OfflineSortType.default_ => List<dynamic>.of(list),
      OfflineSortType.title => sortSongsByKey(list, 'title'),
      OfflineSortType.artist => sortSongsByKey(list, 'artist'),
      OfflineSortType.dateAdded => sortSongsByDateAdded(list),
    };
  }
}
