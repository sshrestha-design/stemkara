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
import 'package:musify/database/radio_stations.db.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_cube.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    if (offlineMode.value) {
      final hasUserContent =
          userPlaylistFolders.value.isNotEmpty ||
          userPlaylists.value.isNotEmpty ||
          userCustomPlaylists.value.isNotEmpty;
      final hasOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value
          .any((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p));
      final hasOfflineArtists = getLikedArtistItems(offlineOnly: true).isNotEmpty;
      final hasOfflineSongs = userOfflineSongs.value.isNotEmpty;

      if (!hasUserContent &&
          !hasOfflinePlaylists &&
          !hasOfflineArtists &&
          !hasOfflineSongs) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: isDesktopPlatform
              ? null
              : AppBar(title: Text(context.l10n!.library)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FluentIcons.cloud_off_24_regular,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n!.offlineMode,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n!.noOfflineLibraryContent,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: Text(context.l10n!.library),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          pinnedPlaylistIds,
          offlineMode,
          userCustomPlaylists,
          userPlaylistFolders,
          offlinePlaylistService.offlinePlaylists,
          userLikedPlaylists,
          onlinePlaylists,
          userPlaylists,
          userOfflineSongs,
          userLikedSongsList,
          userRecentlyPlayed,
        ]),
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktopPlatform ? 40 : 16,
              vertical: isDesktopPlatform ? 24 : 16,
            ),
            child: CustomScrollView(
              slivers: [
                _buildHeaderSliver(context),
                _buildHubDeckSliver(context),
                _buildRecentTracksSliver(context),
                ..._buildPinnedSlivers(),
                ..._buildUserPlaylistsSlivers(),
                if (!offlineMode.value) ..._buildLikedPlaylistsSlivers(),
                ..._buildLikedArtistsSlivers(),
                const SliverMiniPlayerBottomSpace(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSliver(BuildContext context) {
    if (!isDesktopPlatform) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = offlineMode.value;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n!.library,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Playlists, liked tracks, offline stems, and saved radio',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (!isOffline) ...[
              OutlinedButton.icon(
                onPressed: _showCreateFolderDialog,
                icon: const Icon(FluentIcons.folder_add_20_regular, size: 18),
                label: Text(context.l10n!.createFolder),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => showCreatePlaylistDialog(context),
                icon: const Icon(FluentIcons.add_20_filled, size: 18),
                label: Text(context.l10n!.addPlaylist),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHubDeckSliver(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 1100 ? 4 : (width > 680 ? 2 : 1);
    final likedCount = userLikedSongsList.value.length;
    final recentsCount = userRecentlyPlayed.value.length;
    final offlineCount = userOfflineSongs.value.length;
    final radioCount = radioStationsDB.length;

    final cards = [
      _LibraryHubCard(
        title: context.l10n!.likedSongs,
        subtitle: likedCount > 0 ? '$likedCount tracks saved' : 'No favorites yet',
        badgeText: likedCount > 0 ? '$likedCount' : null,
        icon: FluentIcons.heart_24_filled,
        iconColor: Colors.white,
        accentGradient: const [Color(0xFFFF7E79), Color(0xFFE5354B)],
        onTap: () => NavigationManager.router.go('/library/userSongs/liked'),
        onPlayTap: likedCount > 0
            ? () {
                audioHandler.playPlaylistSong(
                  playlist: {
                    'title': context.l10n!.likedSongs,
                    'list': userLikedSongsList.value,
                  },
                  songIndex: 0,
                );
              }
            : null,
      ),
      _LibraryHubCard(
        title: context.l10n!.recentlyPlayed,
        subtitle: recentsCount > 0
            ? '$recentsCount tracks listened'
            : 'Listening history',
        badgeText: recentsCount > 0 ? '$recentsCount' : null,
        icon: FluentIcons.history_24_filled,
        iconColor: Colors.white,
        accentGradient: const [Color(0xFFFFB347), Color(0xFFFF7A00)],
        onTap: () => NavigationManager.router.go('/library/userSongs/recents'),
        onPlayTap: recentsCount > 0
            ? () {
                audioHandler.playPlaylistSong(
                  playlist: {
                    'title': context.l10n!.recentlyPlayed,
                    'list': userRecentlyPlayed.value,
                  },
                  songIndex: 0,
                );
              }
            : null,
      ),
      _LibraryHubCard(
        title: context.l10n!.offlineSongs,
        subtitle: offlineCount > 0
            ? '$offlineCount offline • 4-Stem ready'
            : 'On-device cache',
        badgeText: offlineCount > 0 ? '$offlineCount' : null,
        icon: FluentIcons.arrow_download_24_filled,
        iconColor: Colors.white,
        accentGradient: const [Color(0xFF26C6DA), Color(0xFF00897B)],
        onTap: () => NavigationManager.router.go('/library/userSongs/offline'),
        onPlayTap: offlineCount > 0
            ? () {
                audioHandler.playPlaylistSong(
                  playlist: {
                    'title': context.l10n!.offlineSongs,
                    'list': userOfflineSongs.value,
                  },
                  songIndex: 0,
                );
              }
            : null,
      ),
      _LibraryHubCard(
        title: context.l10n!.radioStations,
        subtitle: '$radioCount curated live channels',
        badgeText: '$radioCount',
        icon: FluentIcons.sound_source_24_filled,
        iconColor: Colors.white,
        accentGradient: const [Color(0xFFAB47BC), Color(0xFF6A1B9A)],
        onTap: () => NavigationManager.router.go('/library/radioStations'),
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 36),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisExtent: 130,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => cards[index],
          childCount: cards.length,
        ),
      ),
    );
  }

  Widget _buildRecentTracksSliver(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recents = userRecentlyPlayed.value;
    if (recents.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final displayList = recents.take(12).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      FluentIcons.receipt_play_24_filled,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'JUMP BACK IN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () =>
                      NavigationManager.router.go('/library/userSongs/recents'),
                  child: Text(
                    'View All (${recents.length})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 195,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final song = displayList[index];
                  return _RecentTrackCard(
                    song: song,
                    onTap: () {
                      audioHandler.playPlaylistSong(
                        playlist: {
                          'title': context.l10n!.recentlyPlayed,
                          'list': recents,
                        },
                        songIndex: index,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPinnedSlivers() {
    final ids = pinnedPlaylistIds.value;
    if (ids.isEmpty) return [];

    final isOff = offlineMode.value;
    final items = resolvePinnedPlaylists(ids).where((p) {
      return !isOff ||
          offlinePlaylistService.isPlaylistDownloaded(
            p['ytid']?.toString() ?? '',
          );
    }).toList();

    if (items.isEmpty) return [];

    final colorScheme = Theme.of(context).colorScheme;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Icon(
                FluentIcons.pin_24_filled,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n!.pinnedPlaylists.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      _buildSliverPlaylistGrid(items),
      const SliverToBoxAdapter(child: SizedBox(height: 36)),
    ];
  }

  List<Widget> _buildUserPlaylistsSlivers() {
    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = offlineMode.value;

    final rawOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value;
    final visibleOfflinePlaylists = rawOfflinePlaylists
        .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
        .toList();
    final folders = isOffline
        ? userPlaylistFolders.value
              .where(PlaylistUtils.folderHasOfflinePlaylists)
              .toList()
        : userPlaylistFolders.value;

    final offlinePlaylistsNotInFolders =
        PlaylistUtils.filterOfflinePlaylistsNotInFolders(
          visibleOfflinePlaylists,
          folders,
        );

    final offlineIdsNotInFolders = PlaylistUtils.offlinePlaylistIdsNotInFolders(
      visibleOfflinePlaylists,
      folders,
    );

    final allPlaylistsNotInFolders = getPlaylistsNotInFolders();
    final playlistsNotInFolders = PlaylistUtils.excludePlaylistsWithIds(
      allPlaylistsNotInFolders,
      offlineIdsNotInFolders,
    );

    final hasFolders = folders.isNotEmpty;
    final hasCustomPlaylists = playlistsNotInFolders.isNotEmpty;
    final totalPlaylistsCount =
        playlistsNotInFolders.length + (userPlaylists.value.length);

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.text_bullet_list_square_24_filled,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n!.customPlaylists.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                  if (totalPlaylistsCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalPlaylistsCount',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!isOffline)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: _showCreateFolderDialog,
                      icon: Icon(
                        FluentIcons.folder_add_24_regular,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: context.l10n!.createFolder,
                    ),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => showCreatePlaylistDialog(context),
                      icon: Icon(
                        FluentIcons.add_24_regular,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: context.l10n!.addPlaylist,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ];

    if (hasFolders) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final folder in folders)
                  _buildFolderChip(context, folder),
              ],
            ),
          ),
        ),
      );
    }

    if (hasCustomPlaylists) {
      slivers.add(_buildSliverPlaylistGrid(playlistsNotInFolders));
    } else if (!hasFolders && !isOffline) {
      slivers.add(_buildEmptyPlaylistsCard(context));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 36)));

    if (offlinePlaylistsNotInFolders.isNotEmpty) {
      slivers
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.cloud_off_24_filled,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n!.offlinePlaylists.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        ..add(
          _buildSliverPlaylistGrid(
            offlinePlaylistsNotInFolders,
            isOfflinePlaylists: true,
          ),
        )
        ..add(const SliverToBoxAdapter(child: SizedBox(height: 36)));
    }

    if (!offlineMode.value && userPlaylists.value.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.add_circle_24_filled,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n!.addedPlaylists.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              AsyncLoader<List<dynamic>>(
                future: getUserPlaylistsNotInFolders(),
                builder: (context, playlists) =>
                    _buildPlaylistGridWidget(playlists),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      );
    }

    return slivers;
  }

  List<Widget> _buildLikedPlaylistsSlivers() {
    final likedPlaylists = getLikedPlaylistItems();
    if (likedPlaylists.isEmpty) return [];
    final colorScheme = Theme.of(context).colorScheme;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Icon(
                FluentIcons.heart_24_filled,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n!.likedPlaylists.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      _buildSliverPlaylistGrid(likedPlaylists),
      const SliverToBoxAdapter(child: SizedBox(height: 36)),
    ];
  }

  List<Widget> _buildLikedArtistsSlivers() {
    final likedArtists = getLikedArtistItems(offlineOnly: offlineMode.value);
    if (likedArtists.isEmpty) return [];
    final colorScheme = Theme.of(context).colorScheme;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Icon(
                FluentIcons.person_24_filled,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n!.artist.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      _buildSliverPlaylistGrid(likedArtists),
      const SliverToBoxAdapter(child: SizedBox(height: 36)),
    ];
  }

  Widget _buildSliverPlaylistGrid(
    List playlists, {
    bool isOfflinePlaylists = false,
  }) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 270,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, index) {
          final playlist = playlists[index];
          final isArtist = playlist['source']?.toString() == 'youtube-artist';

          return PlaylistCube(
            playlist,
            playlistData: isArtist ||
                    playlist['source'] == 'user-created' ||
                    playlist['source'] == 'user-youtube' ||
                    isOfflinePlaylists
                ? playlist
                : null,
            cubeIcon: isArtist
                ? FluentIcons.person_24_filled
                : FluentIcons.text_bullet_list_24_filled,
            showMetadata: true,
          );
        },
        childCount: playlists.length,
      ),
    );
  }

  Widget _buildPlaylistGridWidget(List playlists) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 270,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return PlaylistCube(
          playlist,
          playlistData: playlist,
          showMetadata: true,
        );
      },
    );
  }

  Widget _buildFolderChip(BuildContext context, Map folder) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final count = (folder['playlists'] as List?)?.length ?? 0;
    final name = (folder['name'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push(
            '/home/folder/${folder['id']}/${Uri.encodeComponent(name)}',
          );
        },
        onLongPress: () => _showDeleteFolderDialog(folder),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.folder_20_filled,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaylistsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerLow.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                FluentIcons.add_24_filled,
                size: 22,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n!.addPlaylist,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Build custom 4-stem mixes, curated playlists, and offline queues',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: () => showCreatePlaylistDialog(context),
              child: Text(context.l10n!.create),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() => showDialog(
        context: context,
        builder: (BuildContext context) {
          var folderName = '';
          final colorScheme = Theme.of(context).colorScheme;

          return AlertDialog(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.folder_add_24_regular,
                color: colorScheme.primary,
                size: 32,
              ),
            ),
            title: Text(
              context.l10n!.createFolder,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: TextField(
              decoration: InputDecoration(
                labelText: context.l10n!.folderName,
                hintText: context.l10n!.newFolder,
                prefixIcon: Icon(
                  FluentIcons.folder_20_regular,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
              ),
              onChanged: (value) {
                folderName = value;
              },
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n!.cancel),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (folderName.trim().isNotEmpty) {
                    final result =
                        createPlaylistFolder(folderName.trim(), context);
                    showToast(context, result);
                  } else {
                    showToast(context, context.l10n!.enterFolderName);
                  }
                  Navigator.pop(context);
                },
                icon: const Icon(FluentIcons.add_20_regular),
                label: Text(context.l10n!.create),
              ),
            ],
          );
        },
      );

  void _showDeleteFolderDialog(Map folder) => showDialog(
        context: context,
        builder: (BuildContext context) {
          return ConfirmationDialog(
            confirmationMessage: context.l10n!.deleteFolderQuestion,
            submitMessage: context.l10n!.delete,
            onCancel: () {
              Navigator.of(context).pop();
            },
            onSubmit: () {
              final result = deletePlaylistFolder(folder['id'], context);
              Navigator.of(context).pop();
              showToast(context, result);
            },
          );
        },
      );
}

class _LibraryHubCard extends StatefulWidget {
  const _LibraryHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.accentGradient,
    required this.onTap,
    this.badgeText,
    this.onPlayTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Color> accentGradient;
  final VoidCallback onTap;
  final String? badgeText;
  final VoidCallback? onPlayTap;

  @override
  State<_LibraryHubCard> createState() => _LibraryHubCardState();
}

class _LibraryHubCardState extends State<_LibraryHubCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? (_isHovered
                    ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.70)
                    : colorScheme.surfaceContainerLow.withValues(alpha: 0.65))
                : (_isHovered
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? (_isHovered
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08))
                  : (_isHovered
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06)),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark
                      ? (_isHovered ? 0.30 : 0.15)
                      : (_isHovered ? 0.08 : 0.03),
                ),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.accentGradient,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color:
                              widget.accentGradient.first.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: 22, color: widget.iconColor),
                  ),
                  if (widget.onPlayTap != null)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: GestureDetector(
                        onTap: widget.onPlayTap,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : Colors.black.withValues(alpha: 0.85),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            FluentIcons.play_20_filled,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (widget.badgeText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.5,
                            vertical: 1.5,
                          ),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.09)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.badgeText!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTrackCard extends StatefulWidget {
  const _RecentTrackCard({required this.song, required this.onTap});
  final dynamic song;
  final VoidCallback onTap;

  @override
  State<_RecentTrackCard> createState() => _RecentTrackCardState();
}

class _RecentTrackCardState extends State<_RecentTrackCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final title = (widget.song['title'] ?? '').toString();
    final artist = (widget.song['artist'] ?? '').toString();
    final image = widget.song['image']?.toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: _isHovered ? 1.03 : 1.0,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isHovered ? 0.35 : 0.15,
                        ),
                        blurRadius: _isHovered ? 12 : 6,
                        offset: Offset(0, _isHovered ? 4 : 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        if (image != null && image.isNotEmpty)
                          Image(
                            image: ArtworkProvider.get(image),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildSongFallback(colorScheme),
                          )
                        else
                          _buildSongFallback(colorScheme),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _isHovered ? 1.0 : 0.0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF1E1E20)
                                        .withValues(alpha: 0.92)
                                    : Colors.black.withValues(alpha: 0.85),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                FluentIcons.play_20_filled,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                artist,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurfaceVariant,
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

  Widget _buildSongFallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        FluentIcons.music_note_2_24_regular,
        color: colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}
