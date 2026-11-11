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
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/widgets/playlist_page/playlist_action_buttons.dart';

/// The metadata and actions for an artist, album, or playlist.
/// On desktop (width >= 700) with artwork supplied, renders as a full-bleed
/// horizontal studio hero. On mobile, renders as a clean vertical stack.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.title,
    this.artwork,
    this.songsLength,
    this.isAlbum,
    this.isArtist = false,
    this.showTitle = true,
    this.monthlyListeners,
    this.description,
    this.onPlay,
    this.onShuffle,
    this.isLoading = false,
    this.secondaryActions,
  });

  final String title;
  final Widget? artwork;

  /// Left null by the artist page, which does not hold the song list itself.
  final int? songsLength;
  final bool? isAlbum;
  final bool isArtist;
  final bool showTitle;

  /// Monthly listeners of an artist, already shortened, e.g. `447M`.
  final String? monthlyListeners;

  /// Biography or album description.
  final String? description;

  final VoidCallback? onPlay;
  final AsyncCallback? onShuffle;
  final bool isLoading;
  final List<Widget>? secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    if (isDesktop && artwork != null) {
      return _buildDesktopHero(context, theme, colorScheme);
    }

    return _buildMobileHeader(context, theme, colorScheme);
  }

  Widget _buildDesktopHero(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          // Artwork Container with studio elevation
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isArtist ? 100 : 18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: artwork,
          ),
          const SizedBox(width: 32),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Kicker Row
                Row(
                  children: [
                    _buildKickerBadge(context, colorScheme),
                    if (monthlyListeners != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '•',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        FluentIcons.headphones_20_filled,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$monthlyListeners ${context.l10n!.monthlyListeners}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else if (songsLength != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '•',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$songsLength ${context.l10n!.songs}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  title,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Description / Bio with constrained max width
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _Description(description!.trim(), isDesktop: true),
                  ),
                ],

                const SizedBox(height: 18),

                // Actions Row: [ Play ] [ Shuffle ] ( Like ) ( Add ) ( Download ) ( Sync )
                if (onPlay != null || onShuffle != null)
                  PlaylistActionButtons(
                    onPlay: onPlay ?? () {},
                    onShuffle: onShuffle ?? () async {},
                    isLoading: isLoading,
                    trailingActions: secondaryActions,
                    centerAligned: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, showTitle ? 16 : 0, 24, 8),
      child: Column(
        children: [
          if (showTitle) ...[
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.4,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 8),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isArtist)
                _Chip(
                  icon: FluentIcons.person_16_regular,
                  label: context.l10n!.artist,
                  color: colorScheme.primaryContainer,
                  onColor: colorScheme.onPrimaryContainer,
                  theme: theme,
                )
              else if (isAlbum != null)
                _Chip(
                  icon: isAlbum!
                      ? FluentIcons.cd_16_regular
                      : FluentIcons.apps_list_24_regular,
                  label: isAlbum!
                      ? context.l10n!.album
                      : context.l10n!.playlist,
                  color: colorScheme.primaryContainer,
                  onColor: colorScheme.onPrimaryContainer,
                  theme: theme,
                ),
              if (songsLength != null)
                _Chip(
                  icon: FluentIcons.text_bullet_list_24_filled,
                  label: '$songsLength ${context.l10n!.songs}',
                  color: colorScheme.secondaryContainer,
                  onColor: colorScheme.onSecondaryContainer,
                  theme: theme,
                ),
              if (monthlyListeners != null)
                _Chip(
                  icon: FluentIcons.headphones_20_filled,
                  label: '$monthlyListeners ${context.l10n!.monthlyListeners}',
                  color: colorScheme.secondaryContainer,
                  onColor: colorScheme.onSecondaryContainer,
                  theme: theme,
                ),
            ],
          ),

          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _Description(description!.trim()),
            ),
          ],

          const SizedBox(height: 16),

          if (onPlay != null || onShuffle != null)
            PlaylistActionButtons(
              onPlay: onPlay ?? () {},
              onShuffle: onShuffle ?? () async {},
              isLoading: isLoading,
            ),

          if (secondaryActions != null && secondaryActions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: secondaryActions!,
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildKickerBadge(BuildContext context, ColorScheme colorScheme) {
    final String label;
    final IconData icon;

    if (isArtist) {
      label = context.l10n!.artist.toUpperCase();
      icon = FluentIcons.person_16_filled;
    } else if (isAlbum == true) {
      label = context.l10n!.album.toUpperCase();
      icon = FluentIcons.cd_16_filled;
    } else {
      label = context.l10n!.playlist.toUpperCase();
      icon = FluentIcons.music_note_2_16_filled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The artist biography / album description with expand/collapse toggle.
class _Description extends StatefulWidget {
  const _Description(this.text, {this.isDesktop = false});

  final String text;
  final bool isDesktop;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Column(
        crossAxisAlignment: widget.isDesktop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            widget.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.45,
            ),
            textAlign: widget.isDesktop ? TextAlign.start : TextAlign.center,
            maxLines: _isExpanded ? null : (widget.isDesktop ? 2 : 3),
            overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            _isExpanded ? 'Show less' : 'Read more',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
