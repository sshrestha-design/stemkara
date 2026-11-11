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

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/widgets/quick_search_palette.dart';

class GlobalKeyboardHandler extends StatefulWidget {
  const GlobalKeyboardHandler({super.key, required this.child});
  final Widget child;

  @override
  State<GlobalKeyboardHandler> createState() => _GlobalKeyboardHandlerState();
}

class _GlobalKeyboardHandlerState extends State<GlobalKeyboardHandler> {
  static double _savedVolume = 1;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _isEditableFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final hasCommandOrControl = isMeta || isControl;

    // Command + K or Command + F: Open/Toggle Quick Search Command Palette
    if (hasCommandOrControl &&
        (event.logicalKey == LogicalKeyboardKey.keyK ||
            event.logicalKey == LogicalKeyboardKey.keyF)) {
      final navContext =
          NavigationManager.parentNavigatorKey.currentContext ?? context;
      QuickSearchPalette.toggle(navContext);
      return true;
    }

    // If typing in any input / text field, let all keystrokes pass to the text field!
    if (_isEditableFocused()) {
      return false;
    }

    // Space: Play / Pause
    if (!hasCommandOrControl &&
        !isAlt &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.space) {
      if (audioHandler.playbackState.value.playing) {
        audioHandler.pause();
      } else {
        audioHandler.play();
      }
      return true;
    }

    // Arrow Right: Seek forward 5s (or Skip Next if Command is held)
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (hasCommandOrControl) {
        if (audioHandler.canSkipToNext) {
          audioHandler.skipToNext();
        }
        return true;
      } else if (!isAlt && !isShift) {
        final pos = audioHandler.audioPlayer.position;
        final dur = audioHandler.audioPlayer.duration ?? Duration.zero;
        final target = pos + const Duration(seconds: 5);
        audioHandler.seek(target > dur ? dur : target);
        return true;
      }
    }

    // Arrow Left: Seek backward 5s (or Skip Previous if Command is held)
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (hasCommandOrControl) {
        if (audioHandler.hasPrevious) {
          audioHandler.skipToPrevious();
        }
        return true;
      } else if (!isAlt && !isShift) {
        final pos = audioHandler.audioPlayer.position;
        final target = pos - const Duration(seconds: 5);
        audioHandler.seek(target < Duration.zero ? Duration.zero : target);
        return true;
      }
    }

    // Key M: Mute / Unmute
    if (!hasCommandOrControl &&
        !isAlt &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.keyM) {
      final currentVol = audioHandler.audioPlayer.volume;
      if (currentVol == 0) {
        audioHandler.setVolume(_savedVolume > 0 ? _savedVolume : 1.0);
      } else {
        _savedVolume = currentVol;
        audioHandler.setVolume(0);
      }
      return true;
    }

    // Key L: View Lyrics / Now Playing
    if (!hasCommandOrControl &&
        !isAlt &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.keyL) {
      final navContext =
          NavigationManager.parentNavigatorKey.currentContext ?? context;
      Navigator.of(navContext).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const NowPlayingPage(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
