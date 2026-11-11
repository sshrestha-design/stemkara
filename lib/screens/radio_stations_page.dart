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
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/database/radio_stations.db.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musify/widgets/radio_station_card.dart';

class RadioStationsPage extends StatefulWidget {
  const RadioStationsPage({super.key});

  @override
  State<RadioStationsPage> createState() => _RadioStationsPageState();
}

class _RadioStationsPageState extends State<RadioStationsPage> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform || MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<List<String>>(
        valueListenable: userLikedRadioStations,
        builder: (context, likedStations, _) {
          final sortedStations = _sortWithLikedFirst(
            radioStationsDB,
            likedStations.toSet(),
          );

          return ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, query, _) {
              final filteredStations = query.trim().isEmpty
                  ? sortedStations
                  : sortedStations.where((s) {
                      final q = query.toLowerCase();
                      final nameMatch = s.name.toLowerCase().contains(q);
                      final genreMatch = s.genre?.toLowerCase().contains(q) ?? false;
                      return nameMatch || genreMatch;
                    }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: isDesktop
                          ? const EdgeInsets.fromLTRB(28, 20, 28, 24)
                          : const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBackNavigationBar(context),
                          const SizedBox(height: 20),
                          _buildHeroHeader(
                            context,
                            sortedStations.length,
                            sortedStations,
                            isDesktop,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: isDesktop
                        ? const EdgeInsets.symmetric(horizontal: 28)
                        : const EdgeInsets.symmetric(horizontal: 16),
                    sliver: filteredStations.isEmpty
                        ? SliverToBoxAdapter(
                            child: EmptyPlaylistState(
                              icon: FluentIcons.sound_source_24_regular,
                              message: query.isNotEmpty
                                  ? 'No radio stations found matching "$query"'
                                  : context.l10n!.noRadioStations,
                            ),
                          )
                        : isDesktop
                            ? SliverGrid(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 380,
                                  mainAxisExtent: 80,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final station = filteredStations[index];
                                    return RadioStationCard(
                                      key: ValueKey(station.id),
                                      station: station,
                                      onPressed: () => _playStation(context, station),
                                    );
                                  },
                                  childCount: filteredStations.length,
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final station = filteredStations[index];
                                    return Padding(
                                      key: ValueKey(station.id),
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: RadioStationCard(
                                        station: station,
                                        onPressed: () => _playStation(context, station),
                                      ),
                                    );
                                  },
                                  childCount: filteredStations.length,
                                ),
                              ),
                  ),
                  const SliverMiniPlayerBottomSpace(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackNavigationBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Material(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/library');
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.chevron_left_20_filled, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Library',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          FluentIcons.chevron_right_16_regular,
          size: 14,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n!.radioStations,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    int stationsLength,
    List<RadioStation> stations,
    bool isDesktop,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const accentColor = Color(0xFF8944AB);

    final heroArtwork = Container(
      width: isDesktop ? 144 : 112,
      height: isDesktop ? 144 : 112,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8944AB), Color(0xFF5E2B97)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          FluentIcons.sound_source_24_filled,
          size: isDesktop ? 54 : 44,
          color: Colors.white,
        ),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'LIVE BROADCASTS',
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n!.radioStations,
          style: TextStyle(
            fontSize: isDesktop ? 32 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$stationsLength curated live channels • High-fidelity audio streams',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(FluentIcons.play_24_filled, size: 18),
              label: const Text('Play Live', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: stations.isEmpty ? null : () => _playStation(context, stations.first),
            ),
            SizedBox(
              width: isDesktop ? 240 : double.infinity,
              height: 38,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (val) => _searchQueryNotifier.value = val,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search stations or genres...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  prefixIcon: const Icon(FluentIcons.search_20_regular, size: 16),
                  suffixIcon: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (_, query, __) {
                      if (query.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(FluentIcons.dismiss_16_regular, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          _searchQueryNotifier.value = '';
                        },
                      );
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heroArtwork,
          const SizedBox(width: 24),
          Expanded(child: details),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              heroArtwork,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE BROADCASTS',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n!.radioStations,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$stationsLength live channels',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          details,
        ],
      );
    }
  }

  Future<void> _playStation(BuildContext context, RadioStation station) async {
    final success = await audioHandler.playRadioStream(
      id: station.id,
      name: station.name,
      streamUrl: station.streamUrl,
      image: station.image,
      genre: station.genre,
    );

    if (!success && context.mounted) {
      showToast(context, context.l10n!.error);
    }
  }
}

List<RadioStation> _sortWithLikedFirst(
  List<RadioStation> stations,
  Set<String> likedIds,
) {
  final liked = <RadioStation>[];
  final rest = <RadioStation>[];

  for (final station in stations) {
    if (likedIds.contains(station.id)) {
      liked.add(station);
    } else {
      rest.add(station);
    }
  }

  return [...liked, ...rest];
}
