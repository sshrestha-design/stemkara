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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/constants/version.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.about)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/musify_icon.png',
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stemkara',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI Stem Separation & Karaoke Studio',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'v$appVersion',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Features',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFeatureItem(
                      context,
                      icon: FluentIcons.music_note_2_24_filled,
                      title: '4-Channel Stem Isolation',
                      subtitle:
                          'Isolate Vocals, Drums, Bass, and Instruments with neural audio processing.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      icon: FluentIcons.mic_sparkle_24_filled,
                      title: 'Real-time Karaoke & Lyrics',
                      subtitle:
                          'Live synced lyrics, pitch guide, and instant vocal suppression.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      icon: FluentIcons.shield_checkmark_24_filled,
                      title: 'Private & Offline First',
                      subtitle:
                          'Local audio library playback with zero telemetry and zero tracking.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: colorScheme.surfaceContainerLow,
              leading: Icon(
                FluentIcons.document_text_24_regular,
                color: colorScheme.primary,
              ),
              title: const Text(
                'Open Source Licenses',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              trailing: const Icon(FluentIcons.chevron_right_24_regular),
              onTap: () => context.go('/settings/license'),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
