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

import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/now_playing/synced_lyrics_view.dart';
import 'package:musify/widgets/song_artwork.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.metadata,
    this.isExpanded = false,
    this.onFlipBack,
    this.onExpand,
    this.showAmbientBackground = true,
  });

  final MediaItem metadata;
  final bool isExpanded;
  final VoidCallback? onFlipBack;
  final VoidCallback? onExpand;
  final bool showAmbientBackground;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  String? _resolvedKey;
  late Future<Lyrics?> _lyricsFuture;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveIfNeeded();
  }

  void _resolveIfNeeded() {
    final key = '${widget.metadata.artist} - ${widget.metadata.title}';
    if (key == _resolvedKey) return;
    _resolvedKey = key;
    _lyricsFuture = getSongLyricsResult(
      widget.metadata.artist,
      widget.metadata.title,
      duration: widget.metadata.duration,
      album: widget.metadata.album,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget unavailable() => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.text_quote_24_regular,
            size: widget.isExpanded ? 56 : 40,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n!.lyricsNotAvailable,
            style: TextStyle(
              fontSize: widget.isExpanded ? 20 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final content = AsyncLoader<Lyrics?>(
      future: _lyricsFuture,
      emptyWidget: unavailable(),
      errorBuilder: (ctx, error, stack) => unavailable(),
      builder: (context, lyrics) {
        if (lyrics == null || lyrics.isEmpty) return unavailable();

        return ValueListenableBuilder<bool>(
          valueListenable: syncedLyricsEnabled,
          builder: (context, syncedEnabled, _) {
            if (lyrics.isSynced && syncedEnabled) {
              return SyncedLyricsView(
                lyrics: lyrics,
                isExpanded: widget.isExpanded,
                onFlipBack: widget.onFlipBack,
                onExpand: widget.onExpand,
              );
            }

            return _PlainLyricsView(
              lyrics: lyrics,
              isExpanded: widget.isExpanded,
              onFlipBack: widget.onFlipBack,
              onExpand: widget.onExpand,
            );
          },
        );
      },
    );

    if (!widget.showAmbientBackground) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient blurred album art background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: SongArtworkWidget(
                metadata: widget.metadata,
                size: double.infinity,
                borderRadius: 0,
              ),
            ),
          ),
          // Frosted dark glass overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.70),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Lyrics content
          Positioned.fill(child: content),
        ],
      ),
    );
  }
}

class _PlainLyricsView extends StatelessWidget {
  const _PlainLyricsView({
    required this.lyrics,
    required this.isExpanded,
    this.onFlipBack,
    this.onExpand,
  });

  final Lyrics lyrics;
  final bool isExpanded;
  final VoidCallback? onFlipBack;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final edgePadding = isExpanded ? 36.0 : 20.0;

    return Column(
      children: [
        if (onFlipBack != null || onExpand != null)
          _buildCompactHeader(context),
        Expanded(
          child: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.10, 0.90, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                edgePadding,
                edgePadding * 0.8,
                edgePadding,
                edgePadding,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPlainLyrics(lyrics),
                    style: TextStyle(
                      fontSize: isExpanded ? 22 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                      height: 1.7,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  if (lyrics.source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Text(
                        '© ${lyrics.source}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.text_quote_24_filled,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n!.lyrics.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (onExpand != null)
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: Colors.white.withValues(alpha: 0.7),
                  icon: const Icon(FluentIcons.full_screen_maximize_24_regular),
                  tooltip: 'Full Screen',
                  onPressed: onExpand,
                ),
              if (onFlipBack != null)
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: Colors.white.withValues(alpha: 0.7),
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  tooltip: 'Close',
                  onPressed: onFlipBack,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
