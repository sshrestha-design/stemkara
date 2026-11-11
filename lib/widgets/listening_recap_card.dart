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
import 'package:musify/extensions/l10n.dart';
import 'package:musify/widgets/no_artwork_cube.dart';

const _stemkaraIconAsset = 'assets/icons/musify_icon.png';

String _getArtworkFromSong(Map song) {
  for (final key in ['lowResImage', 'image', 'highResImage', 'artworkPath']) {
    final val = song[key];
    if (val is String && val.trim().isNotEmpty) {
      return val.trim();
    }
  }
  return '';
}

class ListeningRecapCard extends StatelessWidget {
  const ListeningRecapCard({
    required this.periodLabel,
    required this.minutes,
    required this.songs,
    required this.onSongTap,
    super.key,
  });

  final String periodLabel;
  final int minutes;
  final List<Map<String, dynamic>> songs;
  final ValueChanged<int> onSongTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: colorScheme.brightness == Brightness.light ? 0.65 : 0.35,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colorScheme.brightness == Brightness.light ? 0.03 : 0.20,
            ),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$minutes',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n!.minutesListened.toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              _RecapBrandHeader(periodLabel: periodLabel),
            ],
          ),
          if (songs.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 164,
              child: Stack(
                children: [
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: songs.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _TopSongCard(
                          song: songs[i],
                          rank: i + 1,
                          onTap: () => onSongTap(i),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 40,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              colorScheme.surfaceContainerLow,
                              colorScheme.surfaceContainerLow
                                  .withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopSongCard extends StatefulWidget {
  const _TopSongCard({
    required this.song,
    required this.rank,
    required this.onTap,
  });

  final Map<String, dynamic> song;
  final int rank;
  final VoidCallback onTap;

  @override
  State<_TopSongCard> createState() => _TopSongCardState();
}

class _TopSongCardState extends State<_TopSongCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _getArtworkFromSong(widget.song);
    final title = (widget.song['title'] ?? '').toString();
    final artist = (widget.song['artist'] ?? '').toString();
    final playCount = widget.song['playCount'] ?? widget.song['count'];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 120,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    if (imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        memCacheWidth: 240,
                        memCacheHeight: 240,
                        errorWidget: (_, __, ___) =>
                            const NullArtworkWidget(size: 120),
                      )
                    else
                      const NullArtworkWidget(size: 120),
                    // Dark bottom gradient for depth
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Rank badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '#${widget.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    // Play button accent - visible on hover
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _isHovered ? 1.0 : 0.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            FluentIcons.play_20_filled,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (playCount != null) ...[
                    Icon(
                      FluentIcons.headphones_24_regular,
                      size: 11,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$playCount',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _RecapBrandHeader extends StatelessWidget {
  const _RecapBrandHeader({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.40),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              _stemkaraIconAsset,
              width: 14,
              height: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Stemkara',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            ' · $periodLabel',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
