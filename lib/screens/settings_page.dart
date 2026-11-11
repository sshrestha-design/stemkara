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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/local_sync_page.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/folder_download_service.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/local_sync_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/update_manager.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isDesktopPlatform) ...[
          const SizedBox(height: 16),
          Text(
            context.l10n!.settings,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preferences, audio playback, sync, and application management',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildPreferencesSection(context),
        if (!offlineMode.value) _buildOnlineFeaturesSection(context),
        const LocalSyncSettingsSection(),
        _buildToolsSection(context),
        _buildOthersSection(context),
        const SizedBox(height: 24),
        const MiniPlayerBottomSpace(),
      ],
    );

    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: Text(context.l10n!.settings),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktopPlatform ? 40 : 16,
          vertical: isDesktopPlatform ? 24 : 16,
        ),
        child: isDesktopPlatform
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return _AppleSettingsCard(
      title: context.l10n!.preferences,
      icon: FluentIcons.options_24_filled,
      children: [
        CustomBar(
          context.l10n!.themeMode,
          themeMode == ThemeMode.light
              ? FluentIcons.weather_sunny_24_regular
              : (themeMode == ThemeMode.dark
                  ? FluentIcons.weather_moon_24_regular
                  : FluentIcons.desktop_24_regular),
          trailing: Text(
            themeMode == ThemeMode.light
                ? context.l10n!.themeModeLight
                : (themeMode == ThemeMode.dark
                    ? context.l10n!.themeModeDark
                    : context.l10n!.themeModeSystem),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () => _showThemeModePicker(context),
        ),
        CustomBar(
          context.l10n!.language,
          FluentIcons.translate_24_regular,
          onTap: () => _showLanguagePicker(context),
        ),
        CustomBar(
          context.l10n!.audioQuality,
          FluentIcons.music_note_1_24_regular,
          onTap: () => _showAudioQualityPicker(context),
        ),
        if (isAndroidPlatform)
          CustomBar(
            context.l10n!.equalizer,
            FluentIcons.data_histogram_24_regular,
            onTap: () => context.push('/settings/equalizer'),
          ),
        if (themeMode == ThemeMode.dark)
          CustomBar(
            context.l10n!.pureBlackTheme,
            FluentIcons.color_background_24_regular,
            description: context.l10n!.pureBlackThemeDescription,
            trailing: Switch(
              value: usePureBlackColor.value,
              onChanged: (value) => _togglePureBlack(context, value),
            ),
          ),
        if (isAndroidPlatform)
          CustomBar(
            context.l10n!.dynamicColor,
            FluentIcons.toggle_left_24_regular,
            description: context.l10n!.dynamicColorDescription,
            trailing: Switch(
              value: useSystemColor.value,
              onChanged: (value) => _toggleSystemColor(context, value),
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: showAudioQualityBadge,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.audioQualityBadge,
              FluentIcons.badge_24_regular,
              description: context.l10n!.audioQualityBadgeDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleAudioQualityBadge(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: syncedLyricsEnabled,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.syncedLyrics,
              FluentIcons.text_quote_24_regular,
              description: context.l10n!.syncedLyricsDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSyncedLyrics(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: useProxy,
          builder: (context, value, _) {
            return CustomBar(
              context.l10n!.useProxy,
              FluentIcons.shield_24_regular,
              description:
                  'Public proxies can compromise security. Keep disabled unless using a trusted private proxy.',
              trailing: Switch(
                value: value,
                onChanged: (newValue) {
                  if (newValue) {
                    _showConfirmationDialog(
                      context: context,
                      confirmationMessage:
                          'Security Warning: Public proxies are untrusted third-party servers that may log, inspect, or tamper with your requests. Only enable if using your own secure private proxy or VPN. Do you want to proceed?',
                      submitMessage: 'Enable Anyway',
                      isDangerous: true,
                      onSubmit: () async {
                        useProxy.value = true;
                        await addOrUpdateData<bool>(
                          'settings',
                          'useProxy',
                          true,
                        );
                        if (context.mounted) {
                          showToast(context, context.l10n!.settingChangedMsg);
                        }
                      },
                    );
                  } else {
                    useProxy.value = false;
                    addOrUpdateData<bool>('settings', 'useProxy', false);
                    showToast(context, context.l10n!.settingChangedMsg);
                  }
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: wrappedEnabled,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.listeningStats,
              FluentIcons.clock_24_regular,
              description: context.l10n!.listeningStatsDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleWrapped(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.offlineMode,
              FluentIcons.cloud_off_24_regular,
              description: context.l10n!.offlineModeDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleOfflineMode(context, value),
              ),
            );
          },
        ),
        if (!isFdroidBuild && isMobilePlatform)
          ValueListenableBuilder<bool?>(
            valueListenable: shouldWeCheckUpdates,
            builder: (_, value, __) {
              return CustomBar(
                context.l10n!.automaticUpdateChecks,
                FluentIcons.arrow_sync_24_regular,
                description: context.l10n!.automaticUpdateChecksDescription,
                trailing: Switch(
                  value: value ?? false,
                  onChanged: (value) =>
                      _toggleAutomaticUpdateChecks(context, value),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOnlineFeaturesSection(BuildContext context) {
    return _AppleSettingsCard(
      title: 'Playback & Discovery',
      icon: FluentIcons.play_circle_24_filled,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (_, value, __) {
            return CustomBar(
              'SponsorBlock',
              FluentIcons.cut_24_regular,
              description: context.l10n!.sponsorBlockDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.automaticSongPicker,
              FluentIcons.music_note_2_play_20_regular,
              description: context.l10n!.automaticSongPickerDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  _toggleAutoPlayNext(context, value);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.externalRecommendations,
              FluentIcons.channel_share_24_regular,
              description: context.l10n!.externalRecommendationsDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) =>
                    _toggleExternalRecommendations(context, value),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return _AppleSettingsCard(
      title: context.l10n!.tools,
      icon: FluentIcons.toolbox_24_filled,
      children: [
        CustomBar(
          context.l10n!.clearCache,
          FluentIcons.broom_24_regular,
          onTap: () async {
            final cleared = await clearCache();
            showToast(
              context,
              cleared ? '${context.l10n!.cacheMsg}!' : context.l10n!.error,
            );
          },
        ),
        CustomBar(
          context.l10n!.clearSearchHistory,
          FluentIcons.history_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
            onSubmit: () {
              searchHistoryNotifier.value = [];
              addOrUpdateData('user', 'searchHistory', <dynamic>[]);
              showToast(context, '${context.l10n!.searchHistoryMsg}!');
            },
          ),
        ),
        CustomBar(
          context.l10n!.clearRecentlyPlayed,
          FluentIcons.receipt_play_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
            onSubmit: () {
              userRecentlyPlayed.value = [];
              addOrUpdateData('user', 'recentlyPlayedSongs', <dynamic>[]);
              showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
            },
          ),
        ),
        CustomBar(
          context.l10n!.clearListeningStats,
          FluentIcons.clock_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearListeningStatsQuestion,
            submitMessage: context.l10n!.delete,
            isDangerous: true,
            onSubmit: () async {
              audioHandler.resetListeningStatsSession(flushStats: false);
              await listeningStatsService.clearStats();
              audioHandler.startListeningStatsSessionIfNeeded();
              if (context.mounted) {
                showToast(context, '${context.l10n!.listeningStatsCleared}!');
              }
            },
          ),
        ),
        CustomBar(
          context.l10n!.deleteDownloads,
          FluentIcons.delete_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.deleteDownloadsQuestion,
            submitMessage: context.l10n!.delete,
            isDangerous: true,
            onSubmit: () async {
              try {
                await offlinePlaylistService.deleteAllDownloads();
                if (context.mounted) {
                  showToast(context, context.l10n!.downloadsDeleted);
                }
              } catch (e) {
                if (context.mounted) {
                  showToast(context, context.l10n!.error);
                }
              }
            },
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: downloadDirectorySetting,
          builder: (context, downloadDir, _) => CustomBar(
            'Download Folder',
            FluentIcons.folder_24_regular,
            description: downloadDir ?? 'Ask each time (not set)',
            onTap: () => pickDownloadDirectory(context),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: askDownloadDirectorySetting,
          builder: (context, askDir, _) => CustomBar(
            'Always Ask Download Folder',
            FluentIcons.folder_open_24_regular,
            description: 'Prompt for destination folder on every download',
            trailing: Switch(
              value: askDir,
              onChanged: setAskDownloadDirectory,
            ),
          ),
        ),
        CustomBar(
          context.l10n!.importSpotifyPlaylist,
          FluentIcons.arrow_upload_24_regular,
          onTap: () => context.push('/settings/import-spotify-playlist'),
        ),
        CustomBar(
          context.l10n!.backupUserData,
          FluentIcons.cloud_sync_24_regular,
          onTap: () => _backupUserData(context),
        ),
        CustomBar(
          context.l10n!.restoreUserData,
          FluentIcons.cloud_add_24_regular,
          onTap: () async {
            var storageChanged = false;
            try {
              await LocalSyncService.instance.pauseForStorageRestore();
              if (!context.mounted) return;
              final result = await restoreData(
                context,
                onStorageChanged: (changed) => storageChanged = changed,
              );
              if (result.success) {
                reloadSettingsFromStorage();
                reloadSongLibraryStateFromStorage();
                reloadPlaylistLibraryStateFromStorage();
                reloadSearchHistoryFromStorage();
                listeningStatsService.reload();
                await audioHandler.setShuffleMode(
                  shuffleNotifier.value
                      ? AudioServiceShuffleMode.all
                      : AudioServiceShuffleMode.none,
                );
                await audioHandler.setRepeatMode(repeatNotifier.value);
                themeMode = getThemeMode(themeModeSetting);
                brightness = getBrightnessFromThemeMode(themeMode);
                if (context.mounted) {
                  await Musify.updateAppState(
                    context,
                    newThemeMode: themeMode,
                    newLocale: languageSetting,
                    newAccentColor: primaryColorSetting,
                    useSystemColor: useSystemColor.value,
                  );
                  NavigationManager.refreshRouter();
                }
              }
              if (context.mounted) {
                showToast(
                  context,
                  result.message,
                  icon: result.success
                      ? null
                      : FluentIcons.error_circle_24_regular,
                );
              }
            } catch (e, str) {
              logger.log('Error restoring data', error: e, stackTrace: str);
              if (context.mounted) {
                showToast(
                  context,
                  context.l10n!.error,
                  icon: FluentIcons.error_circle_24_regular,
                );
              }
            } finally {
              await LocalSyncService.instance.resumeAfterStorageRestore(
                storageChanged: storageChanged,
              );
            }
          },
        ),
        if (!isFdroidBuild && isMobilePlatform)
          CustomBar(
            context.l10n!.downloadAppUpdate,
            FluentIcons.arrow_download_24_regular,
            onTap: checkAppUpdates,
          ),
      ],
    );
  }

  Widget _buildOthersSection(BuildContext context) {
    return _AppleSettingsCard(
      title: context.l10n!.others,
      icon: FluentIcons.more_circle_24_filled,
      children: [
        CustomBar(
          context.l10n!.licenses,
          FluentIcons.document_24_regular,
          onTap: () => NavigationManager.router.go('/settings/license'),
        ),
        ValueListenableBuilder<int>(
          valueListenable: logger.logCount,
          builder: (context, logCount, _) => CustomBar(
            '${context.l10n!.copyLogs} ($logCount)',
            FluentIcons.error_circle_24_regular,
            onTap: () async =>
                showToast(context, await logger.copyLogs(context)),
          ),
        ),
        CustomBar(
          context.l10n!.about,
          FluentIcons.book_information_24_regular,
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
      ],
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    final modeIcons = [
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
      if (isDesktopPlatform)
        FluentIcons.desktop_24_regular
      else
        FluentIcons.phone_24_regular,
    ];
    final modeNames = [
      context.l10n!.themeModeLight,
      context.l10n!.themeModeDark,
      context.l10n!.themeModeSystem,
    ];

    Widget buildModeBar(int index) {
      final mode = availableModes[index];

      return BottomSheetBar(
        modeNames[index],
        () {
          addOrUpdateData<int>('settings', 'themeIndex', mode.index);
          Musify.updateAppState(context, newThemeMode: mode);
          Navigator.of(context, rootNavigator: isDesktopPlatform).pop();
        },
        themeMode == mode,
        icon: modeIcons[index],
      );
    }

    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.themeMode,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < availableModes.length; index++)
              buildModeBar(index),
          ],
        ),
      );
      return;
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) => buildModeBar(index),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final availableLanguages = appLanguages.toList();
    final activeLanguageCode = Localizations.localeOf(context).languageCode;
    final activeScriptCode = Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode = activeScriptCode != null
        ? '$activeLanguageCode-$activeScriptCode'
        : activeLanguageCode;

    Widget buildLanguageBar(int index) {
      final language = availableLanguages[index];
      final newLocale = getLocaleFromLanguageCode(language);
      final newLocaleFullCode = newLocale.scriptCode != null
          ? '${newLocale.languageCode}-${newLocale.scriptCode}'
          : newLocale.languageCode;

      return BottomSheetBar(getLanguageDisplayName(context, language), () {
        addOrUpdateData<String>('settings', 'languageCode', newLocaleFullCode);
        Musify.updateAppState(context, newLocale: newLocale);
        showToast(context, context.l10n!.languageMsg);
        Navigator.of(context, rootNavigator: isDesktopPlatform).pop();
      }, activeLanguageFullCode == newLocaleFullCode);
    }

    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.language,
        height: 460,
        content: ListView.builder(
          padding: commonListViewBottomPadding,
          itemCount: availableLanguages.length,
          itemBuilder: (context, index) => buildLanguageBar(index),
        ),
      );
      return;
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) => buildLanguageBar(index),
      ),
    );
  }

  void _showAudioQualityPicker(BuildContext context) {
    final availableQualities = ['low', 'medium', 'high'];
    final qualityNames = [
      context.l10n!.audioQualityLow,
      context.l10n!.audioQualityMedium,
      context.l10n!.audioQualityHigh,
    ];
    const qualityIcons = [
      FluentIcons.speaker_1_24_regular,
      FluentIcons.speaker_2_24_regular,
      FluentIcons.speaker_2_24_filled,
    ];

    Widget buildQualityBar(int index) {
      final quality = availableQualities[index];

      return BottomSheetBar(
        qualityNames[index],
        () {
          addOrUpdateData<String>('settings', 'audioQuality', quality);
          audioQualitySetting.value = quality;
          showToast(context, context.l10n!.audioQualityMsg);
          Navigator.of(context, rootNavigator: isDesktopPlatform).pop();
        },
        audioQualitySetting.value == quality,
        icon: qualityIcons[index],
      );
    }

    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.audioQuality,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < availableQualities.length; index++)
              buildQualityBar(index),
          ],
        ),
      );
      return;
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) => buildQualityBar(index),
      ),
    );
  }

  void _showPickerDialog(
    BuildContext context, {
    required String title,
    required Widget content,
    double? height,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(width: 420, height: height, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Musify.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Musify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAudioQualityBadge(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'showAudioQualityBadge', value);
    showAudioQualityBadge.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSyncedLyrics(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'syncedLyricsEnabled', value);
    syncedLyricsEnabled.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
    if (context.mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;

    // Trigger router refresh and notify about the change
    NavigationManager.refreshRouter();

    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutomaticUpdateChecks(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', value);
    shouldWeCheckUpdates.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleExternalRecommendations(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n!.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    try {
      final result = await backupData(context);
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }
}

class _AppleSettingsCard extends StatelessWidget {
  const _AppleSettingsCard({
    required this.children,
    this.title,
    this.icon,
  });

  final List<Widget> children;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    final itemsWithDividers = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      itemsWithDividers.add(children[i]);
      if (i < children.length - 1) {
        itemsWithDividers.add(
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 66,
            endIndent: 16,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 8),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    title!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerLow.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: itemsWithDividers,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
