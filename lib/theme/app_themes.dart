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

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/settings_manager.dart';

ThemeMode themeMode = getThemeMode(themeModeSetting);
Brightness brightness = getBrightnessFromThemeMode(themeMode);

Brightness getBrightnessFromThemeMode(ThemeMode themeMode) {
  final themeBrightnessMapping = {
    ThemeMode.light: Brightness.light,
    ThemeMode.dark: Brightness.dark,
    ThemeMode.system:
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
  };

  return themeBrightnessMapping[themeMode] ?? Brightness.dark;
}

ThemeMode getThemeMode(int themeModeIndex) {
  const themeModes = ThemeMode.values;
  if (themeModeIndex >= 0 && themeModeIndex < themeModes.length) {
    return themeModes[themeModeIndex];
  }
  return ThemeMode.system;
}

const appleMusicRoseDark = Color(0xFFFA2D48);
const appleMusicRoseLight = Color(0xFFE81E38);

ColorScheme getAppleMusicColorScheme(Brightness currentBrightness) {
  if (currentBrightness == Brightness.dark) {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFA2D48),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF33141B),
      onPrimaryContainer: Color(0xFFFFB3BF),
      secondary: Color(0xFFFF375F),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF2A1620),
      onSecondaryContainer: Color(0xFFFFD9E2),
      tertiary: Color(0xFFFF6482),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF381622),
      onTertiaryContainer: Color(0xFFFFD9E2),
      error: Color(0xFFFF453A),
      onError: Colors.white,
      errorContainer: Color(0xFF491212),
      onErrorContainer: Color(0xFFFFB4AB),
      surface: Color(0xFF0D0E12),
      onSurface: Color(0xFFF5F5F7),
      onSurfaceVariant: Color(0xFF9898A6),
      surfaceContainerLowest: Color(0xFF13141B),
      surfaceContainerLow: Color(0xFF181A22),
      surfaceContainer: Color(0xFF1E202B),
      surfaceContainerHigh: Color(0xFF242735),
      surfaceContainerHighest: Color(0xFF2C3040),
      outline: Color(0xFF383A4A),
      outlineVariant: Color(0xFF242633),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFF5F5F7),
      onInverseSurface: Color(0xFF141419),
      inversePrimary: Color(0xFFE81E38),
    );
  } else {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFE81E38),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFE8EC),
      onPrimaryContainer: Color(0xFF8C001C),
      secondary: Color(0xFFD6183B),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFEAEF),
      onSecondaryContainer: Color(0xFF5C0718),
      tertiary: Color(0xFFB31430),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFD9E0),
      onTertiaryContainer: Color(0xFF40000B),
      error: Color(0xFFD32F2F),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF111115),
      onSurfaceVariant: Color(0xFF6E6E7A),
      surfaceContainerLowest: Color(0xFFF2F2F7),
      surfaceContainerLow: Color(0xFFF7F7FA),
      surfaceContainer: Color(0xFFEFEFF4),
      surfaceContainerHigh: Color(0xFFFFFFFF),
      surfaceContainerHighest: Color(0xFFE5E5EB),
      outline: Color(0xFFCECED8),
      outlineVariant: Color(0xFFE5E5EA),
      shadow: Color(0x18000000),
      scrim: Color(0x33000000),
      inverseSurface: Color(0xFF1B1B22),
      onInverseSurface: Color(0xFFF5F5F7),
      inversePrimary: Color(0xFFFA2D48),
    );
  }
}

ColorScheme getAppColorScheme(
  ColorScheme? lightColorScheme,
  ColorScheme? darkColorScheme,
) {
  final selectedScheme = (brightness == Brightness.light)
      ? lightColorScheme
      : darkColorScheme;

  if (useSystemColor.value && selectedScheme != null) {
    return selectedScheme;
  } else {
    return getAppleMusicColorScheme(brightness);
  }
}

ThemeData getAppTheme(ColorScheme colorScheme) {
  final base = colorScheme.brightness == Brightness.light
      ? ThemeData.light()
      : ThemeData.dark();

  final isLight = colorScheme.brightness == Brightness.light;
  final isPureBlack =
      colorScheme.brightness == Brightness.dark && usePureBlackColor.value;

  // Pure black theme colors
  const pureBlack = Color(0xFF000000);
  const pureBlackElevated = Color(0xFF0A0A0A);
  const pureBlackContainer = Color(0xFF121212);
  const pureBlackContainerHigh = Color(0xFF1A1A1A);

  // modified color scheme for pure black theme
  final effectiveColorScheme = isPureBlack
      ? colorScheme.copyWith(
          surface: pureBlack,
          surfaceContainerLowest: pureBlack,
          surfaceContainerLow: pureBlackElevated,
          surfaceContainer: pureBlackContainer,
          surfaceContainerHigh: pureBlackContainerHigh,
          surfaceContainerHighest: pureBlackContainerHigh,
        )
      : colorScheme;

  final bgColor = effectiveColorScheme.surface;
  final cardBgColor = isLight
      ? effectiveColorScheme.surfaceContainerLow
      : (isPureBlack ? pureBlackElevated : effectiveColorScheme.surfaceContainer);

  return ThemeData(
    scaffoldBackgroundColor: bgColor,
    colorScheme: effectiveColorScheme,
    cardColor: cardBgColor,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bgColor,
      foregroundColor: effectiveColorScheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: effectiveColorScheme.onSurface,
        letterSpacing: -0.4,
      ),
      toolbarHeight: 64,
      iconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: effectiveColorScheme.onSurface,
      iconColor: effectiveColorScheme.onSurfaceVariant,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      activeTrackColor: effectiveColorScheme.primary,
      inactiveTrackColor: effectiveColorScheme.primary.withValues(alpha: 0.2),
      thumbColor: effectiveColorScheme.primary,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: isLight
          ? effectiveColorScheme.surfaceContainerLow
          : (isPureBlack ? pureBlackElevated : effectiveColorScheme.surfaceContainer),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      isDense: true,
      fillColor: isLight
          ? effectiveColorScheme.surfaceContainerHighest
          : (isPureBlack
                ? pureBlackContainerHigh
                : effectiveColorScheme.surfaceContainerHigh),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 20, 14),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: isLight
          ? effectiveColorScheme.surfaceContainerLow
          : (isPureBlack ? pureBlackContainer : effectiveColorScheme.surfaceContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      height: 70,
      indicatorColor: effectiveColorScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            color: effectiveColorScheme.onPrimaryContainer,
            size: 24,
          );
        }
        return IconThemeData(
          color: effectiveColorScheme.onSurfaceVariant,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: effectiveColorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: effectiveColorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      indicatorColor: effectiveColorScheme.primaryContainer,
      selectedIconTheme: IconThemeData(
        color: effectiveColorScheme.onPrimaryContainer,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: isLight
          ? effectiveColorScheme.surfaceContainerLow
          : (isPureBlack ? pureBlackContainer : effectiveColorScheme.surfaceContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: effectiveColorScheme.outlineVariant,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: effectiveColorScheme.secondaryContainer,
      closeIconColor: effectiveColorScheme.onSecondaryContainer,
      contentTextStyle: TextStyle(
        color: effectiveColorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: effectiveColorScheme.outlineVariant,
          width: 0.2,
        ),
      ),
      elevation: 0,
      actionTextColor: effectiveColorScheme.secondary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: true,
  );
}
