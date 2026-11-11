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

import 'package:material_ui/material_ui.dart';

class PlaylistSliverAppBar extends StatelessWidget {
  const PlaylistSliverAppBar({
    super.key,
    required this.title,
    required this.artwork,
    this.leading,
  });

  final String title;
  final Widget artwork;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDesktop = screenSize.width >= 700;

    if (isDesktop) {
      return SliverAppBar(
        leading: leading,
        pinned: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        toolbarHeight: 52,
      );
    }

    return SliverAppBar(
      leading: leading,
      pinned: true,
      expandedHeight: 280,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        expandedTitleScale: 1,
        background: Padding(
          padding: const EdgeInsets.only(top: 48, bottom: 16),
          child: Center(child: artwork),
        ),
      ),
    );
  }
}
