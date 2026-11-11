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
import 'package:musify/main.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/lyrics_view.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/queue_list_view.dart';
import 'package:musify/widgets/song_artwork.dart';

enum DesktopSidePanel { queue, lyrics }

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();
  DesktopSidePanel _sidePanel = DesktopSidePanel.queue;

  void _openFullscreenLyrics(BuildContext context, MediaItem metadata) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Lyrics',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      pageBuilder: (context, anim1, anim2) {
        return _ImmersiveFullscreenLyricsView(
          metadata: metadata,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            if (snapshot.data == null || !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final metadata = snapshot.data!;
            return Column(
              children: [
                _buildAppBar(context, colorScheme, metadata, isLargeScreen),
                Expanded(
                  child: isLargeScreen
                      ? _DesktopLayout(
                          metadata: metadata,
                          size: size,
                          adjustedIconSize: baseIconSize,
                          adjustedMiniIconSize: miniIconSize,
                          lyricsController: _lyricsController,
                          sidePanel: _sidePanel,
                          onSelectSidePanel: (panel) {
                            setState(() => _sidePanel = panel);
                          },
                          onToggleLyrics: () {
                            setState(() {
                              _sidePanel = _sidePanel == DesktopSidePanel.lyrics
                                  ? DesktopSidePanel.queue
                                  : DesktopSidePanel.lyrics;
                            });
                          },
                          onOpenFullscreen: () => _openFullscreenLyrics(context, metadata),
                        )
                      : _MobileLayout(
                          metadata: metadata,
                          size: size,
                          adjustedIconSize: baseIconSize,
                          adjustedMiniIconSize: miniIconSize,
                          isLargeScreen: isLargeScreen,
                          lyricsController: _lyricsController,
                          onOpenFullscreen: () => _openFullscreenLyrics(context, metadata),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
    bool isLargeScreen,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            iconSize: isLargeScreen ? 22 : 26,
            icon: Icon(
              isLargeScreen
                  ? FluentIcons.home_24_filled
                  : FluentIcons.chevron_down_24_regular,
            ),
            tooltip: isLargeScreen ? 'Home' : 'Collapse',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          if (!isLargeScreen)
            IconButton(
              iconSize: 22,
              icon: const Icon(FluentIcons.full_screen_maximize_24_regular),
              tooltip: 'Fullscreen Lyrics',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _openFullscreenLyrics(context, metadata),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.lyricsController,
    required this.sidePanel,
    required this.onSelectSidePanel,
    required this.onToggleLyrics,
    this.onOpenFullscreen,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;
  final DesktopSidePanel sidePanel;
  final ValueChanged<DesktopSidePanel> onSelectSidePanel;
  final VoidCallback onToggleLyrics;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Left Column: Artwork, Controls, Bottom Actions
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: GestureDetector(
                      onTap: onToggleLyrics,
                      child: NowPlayingArtwork(
                        size: size,
                        metadata: metadata,
                        lyricsController: lyricsController,
                        onExpand: onOpenFullscreen,
                      ),
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: BottomActionsRow(
                    metadata: metadata,
                    iconSize: adjustedMiniIconSize,
                    isLargeScreen: true,
                    lyricsController: lyricsController,
                    onLyricsPressed: onToggleLyrics,
                    isLyricsActive: sidePanel == DesktopSidePanel.lyrics,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Right Column: Switchable Queue or Full-Height Lyrics
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Switcher Bar (Queue vs Lyrics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, right: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PanelTabButton(
                              icon: FluentIcons.apps_list_24_filled,
                              label: context.l10n!.queue,
                              isSelected: sidePanel == DesktopSidePanel.queue,
                              onTap: () => onSelectSidePanel(DesktopSidePanel.queue),
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(width: 4),
                            _PanelTabButton(
                              icon: FluentIcons.text_quote_24_filled,
                              label: context.l10n!.lyrics,
                              isSelected: sidePanel == DesktopSidePanel.lyrics,
                              onTap: () => onSelectSidePanel(DesktopSidePanel.lyrics),
                              colorScheme: colorScheme,
                            ),
                          ],
                        ),
                      ),
                      if (onOpenFullscreen != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 20,
                          icon: const Icon(FluentIcons.full_screen_maximize_24_regular),
                          tooltip: 'Immersive Karaoke',
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: onOpenFullscreen,
                        ),
                      ],
                    ],
                  ),
                ),
                // Panel Content
                Expanded(
                  child: sidePanel == DesktopSidePanel.lyrics
                      ? LyricsView(
                          metadata: metadata,
                          isExpanded: true,
                          onExpand: onOpenFullscreen,
                        )
                      : const QueueWidget(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelTabButton extends StatelessWidget {
  const _PanelTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.lyricsController,
    this.onOpenFullscreen,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
                onExpand: onOpenFullscreen,
              ),
            ),
          ),
          if (!isLive)
            Expanded(
              flex: 4,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize,
                adjustedMiniIconSize: adjustedMiniIconSize,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            metadata: metadata,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
            lyricsController: lyricsController,
            onLyricsPressed: onOpenFullscreen,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
                onExpand: onOpenFullscreen,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLive)
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  lyricsController: lyricsController,
                  onLyricsPressed: onOpenFullscreen,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveFullscreenLyricsView extends StatelessWidget {
  const _ImmersiveFullscreenLyricsView({
    required this.metadata,
    required this.onClose,
  });

  final MediaItem metadata;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width > 800;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient blurred album art background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: SongArtworkWidget(
                metadata: metadata,
                size: double.infinity,
                borderRadius: 0,
              ),
            ),
          ),
          // Deep dark gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Minimal header bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        iconSize: 22,
                        icon: Icon(
                          isDesktop
                              ? FluentIcons.dismiss_24_regular
                              : FluentIcons.chevron_down_24_regular,
                          color: Colors.white70,
                        ),
                        tooltip: isDesktop ? 'Exit Fullscreen' : 'Close',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onClose,
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: size.width * 0.5),
                        child: Text(
                          metadata.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                // Expanded Content
                Expanded(
                  child: isDesktop
                      ? Row(
                          children: [
                            // Left column: Album artwork, title, and playback controls
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: SongArtworkWidget(
                                        metadata: metadata,
                                        size: size.height * 0.35,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      metadata.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      metadata.artist ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 24),
                                    NowPlayingControls(
                                      size: size,
                                      audioId: metadata.extras?['ytid'],
                                      adjustedIconSize: 40,
                                      adjustedMiniIconSize: 20,
                                      metadata: metadata,
                                      showSongInfo: false,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Right column: Fullscreen Lyrics
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 36, top: 12, bottom: 24),
                                child: LyricsView(
                                  metadata: metadata,
                                  isExpanded: true,
                                  showAmbientBackground: false,
                                ),
                              ),
                            ),
                          ],
                        )
                      : LyricsView(
                          metadata: metadata,
                          isExpanded: true,
                          showAmbientBackground: false,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
