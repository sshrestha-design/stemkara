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

import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/stem_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';

void showStemMixerDialog(
  BuildContext context, {
  required String? audioId,
  required String title,
  String? artist,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StemMixerSheet(
      audioId: audioId,
      title: title,
      artist: artist,
    ),
  );
}

class _StemMixerSheet extends StatefulWidget {
  const _StemMixerSheet({
    required this.audioId,
    required this.title,
    this.artist,
  });

  final String? audioId;
  final String title;
  final String? artist;

  @override
  State<_StemMixerSheet> createState() => _StemMixerSheetState();
}

class _StemMixerSheetState extends State<_StemMixerSheet> {
  bool _isSeparating = false;
  double _separationProgress = 0;
  String _separationStatus = '';

  // Local fader volume values (0.0 to 1.0)
  double _vocals = 1;
  double _drums = 1;
  double _bass = 1;
  double _other = 1;

  @override
  void initState() {
    super.initState();
    _initStems();
  }

  Future<void> _initStems() async {
    final ytid = widget.audioId;
    if (ytid == null) return;

    if (StemService.hasStems(ytid)) {
      if (audioHandler.isStemActive.value && audioHandler.stemController != null) {
        if (mounted) {
          setState(() {
            _vocals = audioHandler.stemController!.vocalsVolume.value;
            _drums = audioHandler.stemController!.drumsVolume.value;
            _bass = audioHandler.stemController!.bassVolume.value;
            _other = audioHandler.stemController!.otherVolume.value;
          });
        }
      } else {
        // Auto-activate stems if available
        await _toggleStemPlayback(true);
      }
    }
  }

  Future<void> _toggleStemPlayback(bool enable) async {
    final ytid = widget.audioId;
    if (ytid == null) return;

    if (enable) {
      final stems = StemService.getStems(ytid);
      if (stems != null) {
        final success = await audioHandler.startStemPlayback(stems);
        if (success && mounted) {
          audioHandler.stemController?.setVocalsVolume(_vocals);
          audioHandler.stemController?.setDrumsVolume(_drums);
          audioHandler.stemController?.setBassVolume(_bass);
          audioHandler.stemController?.setOtherVolume(_other);
          setState(() {});
        }
      }
    } else {
      await audioHandler.stopStemPlayback();
      if (mounted) setState(() {});
    }
  }

  void _applyPreset(double v, double d, double b, double o) {
    setState(() {
      _vocals = v;
      _drums = d;
      _bass = b;
      _other = o;
    });
    audioHandler.stemController?.setVocalsVolume(v);
    audioHandler.stemController?.setDrumsVolume(d);
    audioHandler.stemController?.setBassVolume(b);
    audioHandler.stemController?.setOtherVolume(o);
    if (!audioHandler.isStemActive.value) {
      _toggleStemPlayback(true);
    }
  }

  Future<void> _startStemSeparation() async {
    final ytid = widget.audioId;
    if (ytid == null) return;

    final sanitized = ytid.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    final offlineSongFile = File(FilePaths.getAudioPath(sanitized));

    if (!offlineSongFile.existsSync() || offlineSongFile.lengthSync() < 1024) {
      final media = audioHandler.mediaItem.value;
      if (media != null) {
        setState(() {
          _isSeparating = true;
          _separationProgress = 0.05;
          _separationStatus = 'Downloading audio track for AI engine...';
        });
        final ok = await makeSongOffline(mediaItemToMap(media));
        if (!ok || !offlineSongFile.existsSync()) {
          if (mounted) {
            setState(() => _isSeparating = false);
            showToast(context, 'Failed to download track for stem separation');
          }
          return;
        }
      } else {
        showToast(
          context,
          'Please play or make this song offline first to separate stems',
          icon: FluentIcons.cloud_arrow_down_24_regular,
        );
        return;
      }
    }

    setState(() {
      _isSeparating = true;
      _separationProgress = 0.1;
      _separationStatus = 'Starting stem separation engine...';
    });

    final success = await StemService.separateAudioStems(
      ytid: sanitized,
      inputAudioPath: offlineSongFile.path,
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _separationStatus = status;
            _separationProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isSeparating = false);
      if (success) {
        showToast(context, 'Stems separated successfully!', icon: FluentIcons.checkmark_circle_24_filled);
        await _toggleStemPlayback(true);
      } else {
        showToast(context, 'Stem separation error. Please try again.', icon: FluentIcons.error_circle_24_regular);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 700;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 540 : double.infinity,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title and track info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        FluentIcons.music_note_2_24_filled,
                        color: colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stem Mixer & Karaoke',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.dismiss_24_regular),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  children: [
                    // Section 1: Instant Real-time Karaoke (Vocal Remover)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: audioHandler.isKaraokeActive,
                        builder: (context, isKaraoke, _) {
                          return Row(
                            children: [
                              Icon(
                                isKaraoke
                                    ? FluentIcons.mic_off_24_filled
                                    : FluentIcons.mic_24_regular,
                                color: isKaraoke ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Real-Time Karaoke Mode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Cuts center vocals in real-time (works on all songs)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isKaraoke,
                                activeTrackColor: colorScheme.primary,
                                onChanged: (value) async {
                                  final success = await audioHandler.toggleKaraoke();
                                  if (context.mounted && !success && !audioHandler.isKaraokeActive.value) {
                                    showToast(
                                      context,
                                      'Save this song offline first to enable Instant Karaoke',
                                      icon: FluentIcons.cloud_arrow_down_24_regular,
                                    );
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section 2: 4-Stem Fader Mixer
                    ValueListenableBuilder<bool>(
                      valueListenable: audioHandler.isStemActive,
                      builder: (context, isStemActive, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(FluentIcons.channel_share_24_regular, size: 20, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  '4-Channel Instrument Stems',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (StemService.hasStems(widget.audioId))
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isStemActive ? 'Stem Audio' : 'Original',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isStemActive ? Colors.green : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Switch.adaptive(
                                        value: isStemActive,
                                        activeTrackColor: Colors.green,
                                        onChanged: _toggleStemPlayback,
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            if (StemService.hasStems(widget.audioId)) ...[
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildPresetChip('Reset (100%)', () => _applyPreset(1, 1, 1, 1), colorScheme),
                                    const SizedBox(width: 8),
                                    _buildPresetChip('Karaoke', () => _applyPreset(0, 1, 1, 1), colorScheme),
                                    const SizedBox(width: 8),
                                    _buildPresetChip('Acapella', () => _applyPreset(1, 0, 0, 0), colorScheme),
                                    const SizedBox(width: 8),
                                    _buildPresetChip('Minus Drums', () => _applyPreset(1, 0, 1, 1), colorScheme),
                                    const SizedBox(width: 8),
                                    _buildPresetChip('Rhythm Only', () => _applyPreset(0, 1, 1, 0), colorScheme),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Fader 1: Vocals
                    _buildStemFader(
                      label: 'Vocals',
                      icon: FluentIcons.person_voice_24_filled,
                      value: _vocals,
                      colorScheme: colorScheme,
                      onChanged: (val) {
                        setState(() => _vocals = val);
                        audioHandler.stemController?.setVocalsVolume(val);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                      onMute: () {
                        final next = _vocals > 0 ? 0.0 : 1.0;
                        setState(() => _vocals = next);
                        audioHandler.stemController?.setVocalsVolume(next);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                    ),

                    // Fader 2: Drums
                    _buildStemFader(
                      label: 'Drums',
                      icon: FluentIcons.sound_wave_circle_24_regular,
                      value: _drums,
                      colorScheme: colorScheme,
                      onChanged: (val) {
                        setState(() => _drums = val);
                        audioHandler.stemController?.setDrumsVolume(val);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                      onMute: () {
                        final next = _drums > 0 ? 0.0 : 1.0;
                        setState(() => _drums = next);
                        audioHandler.stemController?.setDrumsVolume(next);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                    ),

                    // Fader 3: Bass
                    _buildStemFader(
                      label: 'Bass',
                      icon: FluentIcons.pulse_24_filled,
                      value: _bass,
                      colorScheme: colorScheme,
                      onChanged: (val) {
                        setState(() => _bass = val);
                        audioHandler.stemController?.setBassVolume(val);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                      onMute: () {
                        final next = _bass > 0 ? 0.0 : 1.0;
                        setState(() => _bass = next);
                        audioHandler.stemController?.setBassVolume(next);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                    ),

                    // Fader 4: Guitars / Other
                    _buildStemFader(
                      label: 'Guitars / Other',
                      icon: FluentIcons.music_note_2_24_filled,
                      value: _other,
                      colorScheme: colorScheme,
                      onChanged: (val) {
                        setState(() => _other = val);
                        audioHandler.stemController?.setOtherVolume(val);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                      onMute: () {
                        final next = _other > 0 ? 0.0 : 1.0;
                        setState(() => _other = next);
                        audioHandler.stemController?.setOtherVolume(next);
                        if (!audioHandler.isStemActive.value && StemService.hasStems(widget.audioId)) {
                          _toggleStemPlayback(true);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // AI Separation Button / Status card
                    if (!StemService.hasStems(widget.audioId)) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(FluentIcons.sparkle_24_filled, color: colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'AI Stem Extraction (Demucs v4)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Splits the track into individual lossless audio channels for drums, bass, guitar, and vocals on your Mac.',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            if (_isSeparating) ...[
                              LinearProgressIndicator(value: _separationProgress > 0 ? _separationProgress : null),
                              const SizedBox(height: 8),
                              Text(
                                _separationStatus,
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ] else
                              FilledButton.icon(
                                icon: const Icon(FluentIcons.play_24_regular, size: 18),
                                label: const Text('Separate 4 Stems with AI'),
                                onPressed: _startStemSeparation,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, ColorScheme colorScheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildStemFader({
    required String label,
    required IconData icon,
    required double value,
    required ColorScheme colorScheme,
    required ValueChanged<double> onChanged,
    required VoidCallback onMute,
  }) {
    final isMuted = value <= 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isMuted ? FluentIcons.speaker_off_24_filled : icon,
              color: isMuted ? Colors.redAccent : colorScheme.primary,
              size: 20,
            ),
            tooltip: isMuted ? 'Unmute' : 'Mute',
            onPressed: onMute,
          ),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isMuted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
              activeColor: isMuted ? colorScheme.outlineVariant : colorScheme.primary,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              isMuted ? 'MUTE' : '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isMuted ? Colors.redAccent : colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
