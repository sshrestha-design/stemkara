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

import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/listening_recap_card.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/recommended_songs_section.dart';
import 'package:musify/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List> _suggestedPlaylistsFuture;
  late Future<List> _recommendedSongsFuture;

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    externalRecommendations.addListener(_refreshRecommendedSongs);
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final playlistContainerHeight = max<double>(250, screenHeight * 0.32);
    final isDesktop = isDesktopPlatform || MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isDesktop
          ? null
          : AppBar(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'assets/icons/musify_icon.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Stemkara',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'STUDIO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: SingleChildScrollView(
        padding: isDesktop
            ? const EdgeInsets.fromLTRB(16, 20, 16, 0)
            : commonSingleChildScrollViewPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: announcementURL,
              builder: (_, _url, __) {
                if (_url == null || isSponsorshipAnnouncementUrl(_url)) {
                  return const SizedBox.shrink();
                }
                return AnnouncementBox(
                  message: context.l10n!.newAnnouncement,
                  url: _url,
                  icon: FluentIcons.megaphone_24_filled,
                  onDismiss: () async {
                    announcementURL.value = null;
                  },
                );
              },
            ),
            _buildStudioFeatureShowcase(context),
            const SizedBox(height: 48),
            _buildSuggestedPlaylists(playlistContainerHeight),
            const SizedBox(height: 48),
            _buildSuggestedPlaylists(playlistContainerHeight, showOnlyLiked: true),
            const SizedBox(height: 48),
            _buildCurrentMonthRecapSection(),
            const SizedBox(height: 48),
            _buildRecommendedSongsSection(),
            const SizedBox(height: 48),
            _buildSuggestedArtistsSection(context),
            const SizedBox(height: 16),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioFeatureShowcase(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.sparkle_24_filled,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Studio Superpowers',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isDesktop)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildStemCard(context)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildKaraokeCard(context)),
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(
                    width: 320,
                    child: _buildStemCard(context),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 320,
                    child: _buildKaraokeCard(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStemCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showToast(
            context,
            'Play any track and open the Stem Console to isolate channels.',
            icon: FluentIcons.data_histogram_24_filled,
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(
              alpha: colorScheme.brightness == Brightness.light ? 0.85 : 0.70,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.brightness == Brightness.light
                  ? Colors.white.withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: colorScheme.brightness == Brightness.light ? 0.03 : 0.20,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'FAST ON-DEVICE',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          'Hardware Accelerated',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '4-Channel Stem Isolation',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Split any track into Vocals, Drums, Bass & Instruments.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildMiniFadersGraphic(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniFadersGraphic(ColorScheme colorScheme) {
    final colors = [
      Colors.indigoAccent,
      Colors.tealAccent,
      Colors.amberAccent,
      Colors.purpleAccent,
    ];
    final values = [0.85, 0.60, 0.75, 0.40];

    return Container(
      width: 74,
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 6,
                height: 52 * values[i],
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildKaraokeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showToast(
            context,
            'Play any track and tap the Mic icon to open Synced Karaoke.',
            icon: FluentIcons.mic_sparkle_24_filled,
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(
              alpha: colorScheme.brightness == Brightness.light ? 0.85 : 0.70,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.brightness == Brightness.light
                  ? Colors.white.withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: colorScheme.brightness == Brightness.light ? 0.03 : 0.20,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'REAL-TIME',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          'Synced Lyrics',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Live Karaoke & Romaji',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sing along with pitch guides, vocal mute, & translation.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  FluentIcons.mic_sparkle_24_filled,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedPlaylists(
    double playlistContainerHeight, {
    bool showOnlyLiked = false,
  }) {
    if (showOnlyLiked) {
      return ValueListenableBuilder<List<Map>>(
        valueListenable: userLikedPlaylists,
        builder: (_, likedPlaylists, __) => _buildSuggestedPlaylistsSection(
          playlistContainerHeight,
          likedPlaylists
              .where((playlist) => !isArtistPlaylist(playlist))
              .take(recommendedCubesNumber)
              .toList(),
          showOnlyLiked: true,
        ),
      );
    }

    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      builder: (context, playlists) =>
          _buildSuggestedPlaylistsSection(playlistContainerHeight, playlists),
    );
  }

  Widget _buildSuggestedPlaylistsSection(
    double playlistContainerHeight,
    List<dynamic> playlists, {
    bool showOnlyLiked = false,
  }) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final sectionTitle = showOnlyLiked
        ? context.l10n!.backToFavorites
        : context.l10n!.suggestedPlaylists;
    final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);

    return Column(
      children: [
        SectionHeader(
          title: sectionTitle,
          icon: showOnlyLiked
              ? FluentIcons.heart_24_filled
              : FluentIcons.music_note_2_24_filled,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: playlistContainerHeight),
          child: _buildHorizontalList(playlists, itemsNumber, playlistContainerHeight),
        ),
      ],
    );
  }

  Widget _buildHorizontalList(
    List<dynamic> playlists,
    int itemCount,
    double containerHeight,
  ) {
    final artworkSize = (containerHeight - 56).clamp(140.0, 200.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: GestureDetector(
                onTap: () => context.push('/home/playlist/${playlist['ytid']}'),
                child: PlaylistCube(
                  playlist,
                  size: artworkSize,
                  showMetadata: true,
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 48,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surface.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _buildRecommendedForYouSection(context, data);
      },
    );
  }

  Widget _buildCurrentMonthRecapSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (_, isEnabled, __) {
        if (!isEnabled) return const SizedBox.shrink();

        final currentMonthKey = listeningStatsMonthKey(DateTime.now());
        final monthStats = listeningStatsService.monthStats(currentMonthKey);
        final songs = listeningStatsService.monthTopSongs(currentMonthKey);
        final displayMinutes = monthDisplayMinutes(monthStats);
        if (displayMinutes <= 0 && songs.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewSongs = songs.take(wrappedShareSongsLimit).toList();
        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          currentMonthKey,
        );

        return Column(
          children: [
            SectionHeader(
              title: context.l10n!.timeMachine,
              icon: FluentIcons.data_trending_24_filled,
            ),
            const SizedBox(height: 16),
            ListeningRecapCard(
              periodLabel: periodLabel,
              minutes: displayMinutes,
              songs: previewSongs,
              onSongTap: (index) => _playRecapSongs(previewSongs, index),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/home/timeMachine'),
                icon: const Icon(FluentIcons.arrow_right_24_regular),
                label: Text(context.l10n!.listeningStats),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playRecapSongs(
    List<Map<String, dynamic>> songs,
    int index,
  ) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': context.l10n!.timeMachine, 'list': songs},
      songIndex: index,
    );
  }

  Widget _buildRecommendedForYouSection(
    BuildContext context,
    List<dynamic> data,
  ) {
    return RecommendedSongsSection(
      title: context.l10n!.recommendedForYou,
      songs: data,
      listKeyPrefix: 'home_recommended',
      asCards: true,
    );
  }

  Widget _buildSuggestedArtistsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([userRecentlyPlayed, userLikedSongsList]),
      builder: (context, _) {
        final artists = _getSuggestedArtists();
        if (artists.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.l10n!.suggestedArtists,
              icon: FluentIcons.person_star_24_filled,
            ),
            const SizedBox(height: 4),
            Text(
              'Artists recommended based on your recent listening and library',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                SizedBox(
                  height: 172,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 48),
                    itemCount: artists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 20),
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      return _SuggestedArtistCard(artist: artist);
                    },
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 48,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            colorScheme.surface,
                            colorScheme.surface.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<_SuggestedArtistData> _getSuggestedArtists() {
    final artistMap = <String, _SuggestedArtistData>{};

    void processSongs(List songs, double weight) {
      for (final song in songs) {
        if (song is! Map) continue;
        final name = (song['artist'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final candidate = artistMap.putIfAbsent(
          name,
          () => _SuggestedArtistData(name: name),
        )
          ..score += weight
          ..isFromHistory = true;
        if (candidate.image == null && song['image'] != null) {
          candidate.image = song['image'].toString();
        }
        if (candidate.artistId == null && song['artistId'] != null) {
          candidate.artistId = song['artistId'].toString();
        }
      }
    }

    processSongs(userRecentlyPlayed.value, 1.5);
    processSongs(userLikedSongsList.value, 2);

    final sortedUserArtists = artistMap.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    const curatedPool = [
      (
        name: 'Daft Punk',
        genre: 'Electronic',
        image: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&fit=crop&q=80',
      ),
      (
        name: 'The Weeknd',
        genre: 'R&B / Pop',
        image: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&fit=crop&q=80',
      ),
      (
        name: 'Billie Eilish',
        genre: 'Alternative Pop',
        image: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&fit=crop&q=80',
      ),
      (
        name: 'Kendrick Lamar',
        genre: 'Hip-Hop',
        image: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300&fit=crop&q=80',
      ),
      (
        name: 'Taylor Swift',
        genre: 'Pop',
        image: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&fit=crop&q=80',
      ),
      (
        name: 'Radiohead',
        genre: 'Alternative Rock',
        image: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300&fit=crop&q=80',
      ),
      (
        name: 'Dua Lipa',
        genre: 'Pop / Disco',
        image: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300&fit=crop&q=80',
      ),
      (
        name: 'Gorillaz',
        genre: 'Alternative',
        image: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300&fit=crop&q=80',
      ),
      (
        name: 'Arctic Monkeys',
        genre: 'Indie Rock',
        image: 'https://images.unsplash.com/photo-1520523839898-50712213388b?w=300&fit=crop&q=80',
      ),
      (
        name: 'Queen',
        genre: 'Classic Rock',
        image: 'https://images.unsplash.com/photo-1511735111819-9a3f7709049c?w=300&fit=crop&q=80',
      ),
    ];

    final result = <_SuggestedArtistData>[...sortedUserArtists];
    final existingNames = result.map((a) => a.name.toLowerCase()).toSet();

    for (final item in curatedPool) {
      if (!existingNames.contains(item.name.toLowerCase())) {
        result.add(_SuggestedArtistData(
          name: item.name,
          genre: item.genre,
          image: item.image,
        ));
      }
      if (result.length >= 12) break;
    }

    return result;
  }
}

class _SuggestedArtistData {
  _SuggestedArtistData({
    required this.name,
    this.genre,
    this.image,
  });

  final String name;
  final String? genre;
  String? image;
  String? artistId;
  double score = 0;
  bool isFromHistory = false;
}

class _SuggestedArtistCard extends StatefulWidget {
  const _SuggestedArtistCard({required this.artist});

  final _SuggestedArtistData artist;

  @override
  State<_SuggestedArtistCard> createState() => _SuggestedArtistCardState();
}

class _SuggestedArtistCardState extends State<_SuggestedArtistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final artist = widget.artist;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          final lookup = artist.artistId ?? artist.name;
          final artistPath = NavigationManager.artistPath(context, lookup);
          final artistData = {
            'ytid': lookup,
            'title': artist.name,
            if (artist.image != null) 'image': artist.image,
          };
          context.push(artistPath, extra: artistData);
        },
        child: SizedBox(
          width: 116,
          child: Column(
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.05 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered
                            ? colorScheme.primary.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: _isHovered ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: artist.image != null
                        ? Image(
                            image: ArtworkProvider.get(artist.image!),
                            fit: BoxFit.cover,
                            width: 104,
                            height: 104,
                            errorBuilder: (_, __, ___) => _buildFallbackAvatar(colorScheme),
                          )
                        : _buildFallbackAvatar(colorScheme),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isHovered ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                artist.isFromHistory ? 'Based on plays' : (artist.genre ?? 'Artist'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(ColorScheme colorScheme) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.artist.name.isNotEmpty
              ? widget.artist.name[0].toUpperCase()
              : 'A',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

