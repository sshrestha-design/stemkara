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

/// Play and shuffle whatever the page is about, shared by the playlist and the
/// artist pages. While [isLoading] the songs are still being read, so both
/// buttons wait instead of playing an incomplete list.
class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.isLoading = false,
    this.trailingActions,
    this.centerAligned = true,
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final bool isLoading;
  final List<Widget>? trailingActions;
  final bool centerAligned;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        if (isDesktop && trailingActions != null && trailingActions!.isNotEmpty) {
          return Row(
            mainAxisAlignment: centerAligned
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isLoading
                    ? const _Spinner()
                    : const Icon(FluentIcons.play_24_filled, size: 18),
                label: Text(
                  context.l10n!.play,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: isLoading ? null : onPlay,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isLoading
                    ? const _Spinner()
                    : const Icon(FluentIcons.arrow_shuffle_24_filled, size: 18),
                label: Text(
                  context.l10n!.shuffle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: isLoading ? null : onShuffle,
              ),
              const SizedBox(width: 14),
              ...trailingActions!,
            ],
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: isLoading
                          ? const _Spinner()
                          : const Icon(FluentIcons.play_24_filled, size: 18),
                      label: Text(
                        context.l10n!.play,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: isLoading ? null : onPlay,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: isLoading
                          ? const _Spinner()
                          : const Icon(FluentIcons.arrow_shuffle_24_filled, size: 18),
                      label: Text(
                        context.l10n!.shuffle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: isLoading ? null : onShuffle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Replaces the icon of a button while its songs are being read.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
