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
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/widgets/playlist_artwork.dart';

class PlaylistCube extends StatefulWidget {
  const PlaylistCube(
    this.playlist, {
    super.key,
    this.playlistData,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.size = 220,
    this.borderRadius = 16,
    this.showTypeLabel = true,
    this.showMetadata = false,
  });

  final Map? playlistData;
  final Map playlist;
  final IconData cubeIcon;
  final double size;
  final double borderRadius;
  final bool showTypeLabel;
  final bool showMetadata;

  @override
  State<PlaylistCube> createState() => _PlaylistCubeState();
}

class _PlaylistCubeState extends State<PlaylistCube> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAlbum = widget.playlist['isAlbum'] == true;
    final rawTitle = (widget.playlist['title'] ?? '').toString();
    final cleanTitle = rawTitle
        .replaceAll(RegExp(r'\bSpotify\s+Playlist\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bSpotify\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+-\s*$', caseSensitive: false), '')
        .trim();
    final artist = (widget.playlist['artist'] ?? '').toString();

    final artworkWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: _isHovered ? 1.03 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.15),
                blurRadius: _isHovered ? 18 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              children: [
                PlaylistArtwork(
                  playlistArtwork: widget.playlist['image'],
                  size: widget.size,
                  cubeIcon: widget.cubeIcon,
                ),
                // Subtle gradient overlay for contrast
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.40),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                if (widget.showTypeLabel && widget.playlist['image'] != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildFrostedLabel(context, isAlbum),
                  ),
                // Floating Play Action Accent visible on hover
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
      ),
    );

    if (!widget.showMetadata) {
      return artworkWidget;
    }

    // Rich card with Title, Subtitle and Stem badge
    return SizedBox(
      width: widget.size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          artworkWidget,
          const SizedBox(height: 10),
          Text(
            cleanTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  isAlbum
                      ? (artist.isNotEmpty
                          ? '$artist • 4-Stem'
                          : '${context.l10n!.album} • 4-Stem')
                      : 'Curated • 4-Stem',
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
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
    );
  }

  Widget _buildFrostedLabel(BuildContext context, bool isAlbum) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAlbum
                ? FluentIcons.album_20_filled
                : FluentIcons.music_note_2_16_filled,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isAlbum ? 'ALBUM' : 'PLAYLIST',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
