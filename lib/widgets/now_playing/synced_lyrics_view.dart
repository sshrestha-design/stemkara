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

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/lyrics/lyrics_translation_service.dart';
import 'package:musify/services/settings_manager.dart';

/// Shows time-synced lyrics styled in Apple Music & Spotify aesthetics:
/// - Prominent, vibrant active line with soft scaling and glow
/// - Modern left-aligned layout with top & bottom edge gradient fade
/// - Click-to-seek, auto-scrolling with user-drag pause
/// - Integrated timing offset adjuster pill
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.lyrics,
    this.isExpanded = false,
    this.onFlipBack,
    this.onExpand,
  });

  final Lyrics lyrics;
  final bool isExpanded;
  final VoidCallback? onFlipBack;
  final VoidCallback? onExpand;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  static const Duration _offsetStep = Duration(milliseconds: 500);
  static const Duration _manualScrollPause = Duration(seconds: 4);
  static const Duration _scrollDuration = Duration(milliseconds: 350);

  StreamSubscription<PositionData>? _positionSubscription;
  List<GlobalKey> _lineKeys = const [];
  Duration _position = Duration.zero;
  Duration _offset = Duration.zero;
  int _activeIndex = -1;
  DateTime _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);

  LyricsTranslationResult? _translationResult;
  bool _isLoadingTranslation = false;

  List<LyricLine> get _lines => widget.lyrics.synced ?? const <LyricLine>[];

  bool get _hasNonLatin =>
      _translationResult?.hasNonLatin ??
      _lines.any((l) => LyricsTranslationService.hasNonLatinScript(l.text));

  @override
  void initState() {
    super.initState();
    _prepareLines();
    _position = audioHandler.currentPositionData.position;
    _activeIndex = _computeActiveIndex();
    _positionSubscription = audioHandler.positionDataStream.listen((data) {
      _position = data.position;
      _refreshActiveLine();
    });
    lyricsTranslationEnabled.addListener(_onTranslationToggled);
    lyricsRomanizationEnabled.addListener(_onTranslationToggled);
    _checkAndFetchTranslation();
    _scheduleScrollToActive(animate: false);
  }

  void _onTranslationToggled() {
    if (!mounted) return;
    if (lyricsTranslationEnabled.value || lyricsRomanizationEnabled.value) {
      _fetchTranslation();
    }
    setState(() {});
  }

  void _checkAndFetchTranslation() {
    if (_lines.isEmpty) return;
    if (lyricsTranslationEnabled.value || lyricsRomanizationEnabled.value) {
      _fetchTranslation();
    }
  }

  Future<void> _fetchTranslation() async {
    if (_isLoadingTranslation || _translationResult != null || _lines.isEmpty) return;
    setState(() => _isLoadingTranslation = true);
    try {
      final res = await LyricsTranslationService.translateLines(lines: _lines);
      if (mounted) {
        setState(() {
          _translationResult = res;
          _isLoadingTranslation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTranslation = false);
    }
  }

  @override
  void didUpdateWidget(SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _prepareLines();
      _offset = Duration.zero;
      _activeIndex = _computeActiveIndex();
      _translationResult = null;
      _checkAndFetchTranslation();
      _scheduleScrollToActive(animate: false);
    }
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    lyricsTranslationEnabled.removeListener(_onTranslationToggled);
    lyricsRomanizationEnabled.removeListener(_onTranslationToggled);
    super.dispose();
  }

  void _prepareLines() {
    _lineKeys = List<GlobalKey>.generate(_lines.length, (_) => GlobalKey());
  }

  int _computeActiveIndex() => widget.lyrics.lineIndexAt(_position + _offset);

  void _refreshActiveLine() {
    final index = _computeActiveIndex();
    if (index == _activeIndex || !mounted) return;
    setState(() => _activeIndex = index);
    _scheduleScrollToActive();
  }

  void _scheduleScrollToActive({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (DateTime.now().isBefore(_autoScrollResumesAt)) return;
      if (_activeIndex < 0 || _activeIndex >= _lineKeys.length) return;

      final lineContext = _lineKeys[_activeIndex].currentContext;
      if (lineContext == null) return;

      unawaited(
        Scrollable.ensureVisible(
          lineContext,
          alignment: widget.isExpanded ? 0.32 : 0.38,
          duration: animate ? _scrollDuration : Duration.zero,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _changeOffset(Duration delta) {
    setState(() {
      _offset = delta == Duration.zero ? Duration.zero : _offset + delta;
      _activeIndex = _computeActiveIndex();
    });
    _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);
    _scheduleScrollToActive();
  }

  void _seekToLine(LyricLine line) {
    final target = line.start - _offset;
    unawaited(audioHandler.seek(target.isNegative ? Duration.zero : target));
    _autoScrollResumesAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get _offsetLabel {
    if (_offset == Duration.zero) return '0.0s';
    final seconds = _offset.inMilliseconds / 1000;
    return '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final horizontalPadding = widget.isExpanded ? 32.0 : 20.0;

    return Column(
      children: [
        if (widget.onFlipBack != null || widget.onExpand != null)
          _buildCompactHeader(context),
        Expanded(
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) {
                _autoScrollResumesAt = DateTime.now().add(_manualScrollPause);
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final edgePadding = constraints.maxHeight * (widget.isExpanded ? 0.35 : 0.32);
                return ShaderMask(
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
                      stops: [0.0, 0.12, 0.88, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      edgePadding,
                      horizontalPadding,
                      edgePadding,
                    ),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < lines.length; i++)
                          _buildLine(i, lines[i]),
                        if (widget.lyrics.source.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: Text(
                              '© ${widget.lyrics.source}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _buildOffsetControls(),
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
              if (_isLoadingTranslation)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ),
              if (_hasNonLatin || lyricsRomanizationEnabled.value)
                ValueListenableBuilder<bool>(
                  valueListenable: lyricsRomanizationEnabled,
                  builder: (context, enabled, _) {
                    return _LyricsHeaderButton(
                      label: 'あ Romaji',
                      isActive: enabled,
                      tooltip: 'Toggle Romanized Lyrics (Romaji / Pinyin)',
                      onTap: () {
                        final next = !enabled;
                        lyricsRomanizationEnabled.value = next;
                        Hive.box('settings')
                            .put('lyricsRomanizationEnabled', next);
                      },
                    );
                  },
                ),
              ValueListenableBuilder<bool>(
                valueListenable: lyricsTranslationEnabled,
                builder: (context, enabled, _) {
                  return _LyricsHeaderButton(
                    label: '文 Translate',
                    isActive: enabled,
                    tooltip: 'Toggle English Translation',
                    onTap: () {
                      final next = !enabled;
                      lyricsTranslationEnabled.value = next;
                      Hive.box('settings').put('lyricsTranslationEnabled', next);
                    },
                  );
                },
              ),
              if (widget.onExpand != null)
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: Colors.white.withValues(alpha: 0.7),
                  icon: const Icon(FluentIcons.full_screen_maximize_24_regular),
                  tooltip: 'Full Screen',
                  onPressed: widget.onExpand,
                ),
              if (widget.onFlipBack != null)
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: Colors.white.withValues(alpha: 0.7),
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  tooltip: 'Close',
                  onPressed: widget.onFlipBack,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLine(int index, LyricLine line) {
    final isActive = index == _activeIndex;
    final activeFontSize = widget.isExpanded ? 26.0 : 20.0;
    final inactiveFontSize = widget.isExpanded ? 20.0 : 16.0;

    final showRom = lyricsRomanizationEnabled.value;
    final showTrans = lyricsTranslationEnabled.value;

    String? rom;
    String? trans;

    if (_translationResult != null) {
      if (index < _translationResult!.romanizations.length) {
        final r = _translationResult!.romanizations[index];
        if (r.isNotEmpty && r.toLowerCase() != line.text.toLowerCase()) {
          rom = r;
        }
      }
      if (index < _translationResult!.translations.length) {
        final t = _translationResult!.translations[index];
        if (t.isNotEmpty && t.toLowerCase() != line.text.toLowerCase()) {
          trans = t;
        }
      }
    }

    return _LyricLineItem(
      key: _lineKeys[index],
      line: line,
      isActive: isActive,
      activeFontSize: activeFontSize,
      inactiveFontSize: inactiveFontSize,
      showRom: showRom,
      rom: rom,
      showTrans: showTrans,
      trans: trans,
      isExpanded: widget.isExpanded,
      onTap: () => _seekToLine(line),
    );
  }

  Widget _buildOffsetControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            color: Colors.white.withValues(alpha: 0.7),
            icon: const Icon(FluentIcons.subtract_24_regular),
            onPressed: () => _changeOffset(-_offsetStep),
          ),
          GestureDetector(
            onTap: () => _changeOffset(Duration.zero),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _offsetLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            color: Colors.white.withValues(alpha: 0.7),
            icon: const Icon(FluentIcons.add_24_regular),
            onPressed: () => _changeOffset(_offsetStep),
          ),
        ],
      ),
    );
  }
}



class _LyricsHeaderButton extends StatelessWidget {
  const _LyricsHeaderButton({
    required this.label,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary
                  : Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? colorScheme.onPrimary : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricLineItem extends StatefulWidget {
  const _LyricLineItem({
    super.key,
    required this.line,
    required this.isActive,
    required this.activeFontSize,
    required this.inactiveFontSize,
    required this.showRom,
    required this.rom,
    required this.showTrans,
    required this.trans,
    required this.onTap,
    required this.isExpanded,
  });

  final LyricLine line;
  final bool isActive;
  final double activeFontSize;
  final double inactiveFontSize;
  final bool showRom;
  final String? rom;
  final bool showTrans;
  final String? trans;
  final VoidCallback onTap;
  final bool isExpanded;

  @override
  State<_LyricLineItem> createState() => _LyricLineItemState();
}

class _LyricLineItemState extends State<_LyricLineItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    final targetScale = isActive
        ? 1.045
        : (_isHovered ? 1.015 : 1.0);
    final targetOffset = isActive
        ? const Offset(0.012, 0)
        : (_isHovered ? const Offset(0.005, 0) : Offset.zero);

    final textColor = isActive
        ? Colors.white
        : (_isHovered
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.35));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: widget.isExpanded ? 10 : 6,
          ),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            offset: targetOffset,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              scale: targetScale,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: isActive
                          ? widget.activeFontSize
                          : widget.inactiveFontSize,
                      height: 1.35,
                      fontWeight:
                          isActive ? FontWeight.w800 : FontWeight.w600,
                      color: textColor,
                    ),
                    textAlign: TextAlign.start,
                    child: Text(
                      widget.line.text.isEmpty ? '♪' : widget.line.text,
                    ),
                  ),
                  if (widget.showRom &&
                      widget.rom != null &&
                      widget.rom!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        widget.rom!,
                        style: TextStyle(
                          fontSize: (isActive
                                  ? widget.activeFontSize
                                  : widget.inactiveFontSize) *
                              0.70,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.32),
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  if (widget.showTrans &&
                      widget.trans != null &&
                      widget.trans!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.trans!,
                        style: TextStyle(
                          fontSize: (isActive
                                  ? widget.activeFontSize
                                  : widget.inactiveFontSize) *
                              0.68,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.78)
                              : Colors.white.withValues(alpha: 0.28),
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


