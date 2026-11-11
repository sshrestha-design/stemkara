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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/main.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/no_artwork_cube.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';

String _extractSongArtwork(Map song) {
  for (final key in ['lowResImage', 'image', 'highResImage', 'artworkPath']) {
    final val = song[key];
    if (val is String && val.trim().isNotEmpty) {
      return val.trim();
    }
  }
  return '';
}

/// Shared titled list of recommended songs with an optional "play all" button.
/// Supports both classic vertical list and modern horizontal track card layout.
class RecommendedSongsSection extends StatelessWidget {
  const RecommendedSongsSection({
    super.key,
    required this.title,
    required this.songs,
    required this.listKeyPrefix,
    this.showPlayButton = true,
    this.asCards = false,
    this.onAddSong,
  });

  final String title;
  final List<dynamic> songs;
  final String listKeyPrefix;
  final bool showPlayButton;
  final bool asCards;
  final void Function(Map song)? onAddSong;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: title,
          icon: FluentIcons.sparkle_24_filled,
          actionButton: showPlayButton
              ? FilledButton.tonalIcon(
                  onPressed: () async {
                    await audioHandler.playPlaylistSong(
                      playlist: {'title': title, 'list': songs},
                      songIndex: 0,
                      shuffle: false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(FluentIcons.play_20_filled, size: 14),
                  label: const Text(
                    'Play all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        if (asCards)
          _buildCardsShelf(context)
        else
          _buildVerticalList(context),
      ],
    );
  }

  Widget _buildCardsShelf(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 226,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              final song = songs[index];
              if (song is! Map) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 24),
                child: _RecommendedTrackCard(
                  song: song,
                  onTap: () async {
                    await audioHandler.playPlaylistSong(
                      playlist: {'title': title, 'list': songs},
                      songIndex: index,
                      shuffle: false,
                    );
                  },
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
      ),
    );
  }

  Widget _buildVerticalList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: songs.length,
      padding: commonListViewBottomPadding,
      itemBuilder: (context, index) {
        final song = songs[index];
        final borderRadius = getItemBorderRadius(index, songs.length);
        return RepaintBoundary(
          key: listItemKey(listKeyPrefix, index, song),
          child: SongBar(
            song,
            true,
            barPadding: const EdgeInsetsDirectional.only(
              top: 10,
              bottom: 10,
              start: 12,
            ),
            borderRadius: borderRadius,
            onAdd: onAddSong != null && song is Map
                ? () => onAddSong!(song)
                : null,
          ),
        );
      },
    );
  }
}

class _RecommendedTrackCard extends StatefulWidget {
  const _RecommendedTrackCard({
    required this.song,
    required this.onTap,
  });

  final Map song;
  final VoidCallback onTap;

  @override
  State<_RecommendedTrackCard> createState() => _RecommendedTrackCardState();
}

class _RecommendedTrackCardState extends State<_RecommendedTrackCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _extractSongArtwork(widget.song);
    final title = (widget.song['title'] ?? '').toString();
    final artist = (widget.song['artist'] ?? '').toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 146,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                scale: _isHovered ? 1.03 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      if (imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 146,
                          height: 146,
                          fit: BoxFit.cover,
                          memCacheWidth: 292,
                          memCacheHeight: 292,
                          errorWidget: (_, __, ___) =>
                              const NullArtworkWidget(size: 146),
                        )
                      else
                        const NullArtworkWidget(size: 146),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.20),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FluentIcons.music_note_2_16_filled,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'TRACK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Neutral play button matching PlaylistCube, visible on hover
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _isHovered ? 1.0 : 0.0,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            scale: _isHovered ? 1.0 : 0.8,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
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
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'STEM',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
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
