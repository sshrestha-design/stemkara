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
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:musify/constants/clients.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/proxy_manager.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final downloadDirectorySetting = ValueNotifier<String?>(
  Hive.box('settings').get('customDownloadDirectory', defaultValue: null)
      as String?,
);

final askDownloadDirectorySetting = ValueNotifier<bool>(
  Hive.box('settings').get('askDownloadDirectory', defaultValue: true) as bool,
);

String sanitizeFilename(String name) {
  var clean = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\.+/'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  while (clean.startsWith('.')) {
    clean = clean.substring(1).trim();
  }
  return clean.isEmpty ? 'untitled' : clean;
}

Future<void> setCustomDownloadDirectory(String? path) async {
  downloadDirectorySetting.value = path;
  if (path == null) {
    await deleteData('settings', 'customDownloadDirectory');
  } else {
    await addOrUpdateData<String>('settings', 'customDownloadDirectory', path);
  }
}

Future<void> setAskDownloadDirectory(bool value) async {
  askDownloadDirectorySetting.value = value;
  await addOrUpdateData<bool>('settings', 'askDownloadDirectory', value);
}

Future<String?> pickDownloadDirectory(BuildContext context) async {
  try {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder for downloads',
    );
    if (path != null && path.isNotEmpty) {
      await setCustomDownloadDirectory(path);
      if (context.mounted) {
        showToast(context, 'Download folder set');
      }
      return path;
    }
  } catch (e, stack) {
    logger.log('Error selecting directory', error: e, stackTrace: stack);
    if (context.mounted) {
      showToast(context, 'Failed to pick folder: $e');
    }
  }
  return null;
}

Future<bool> downloadSongToFolder(
  BuildContext context,
  dynamic song, {
  String? targetDirectory,
}) async {
  try {
    final ytid = song['ytid']?.toString();
    if (ytid == null || ytid.isEmpty) {
      if (context.mounted) showToast(context, 'Invalid song');
      return false;
    }

    var destDir = targetDirectory;
    if (destDir == null) {
      final savedDir = downloadDirectorySetting.value;
      if (!askDownloadDirectorySetting.value &&
          savedDir != null &&
          savedDir.isNotEmpty &&
          await Directory(savedDir).exists()) {
        destDir = savedDir;
      } else {
        destDir = await FilePicker.getDirectoryPath(
          dialogTitle:
              'Select destination folder for "${song['title'] ?? 'Song'}"',
        );
      }
    }

    if (destDir == null || destDir.isEmpty) {
      return false;
    }

    final title = (song['title'] ?? 'Song').toString();
    final artist = (song['artist'] ?? 'Artist').toString();
    var fileName = sanitizeFilename('$artist - $title.m4a');
    if (fileName.isEmpty || fileName == '.m4a') {
      fileName = '$ytid.m4a';
    }

    var targetPath = '$destDir/$fileName';
    var file = File(targetPath);
    var counter = 1;
    final baseName = sanitizeFilename('$artist - $title');
    while (await file.exists()) {
      targetPath = '$destDir/$baseName ($counter).m4a';
      file = File(targetPath);
      counter++;
    }

    if (context.mounted) {
      showToast(context, 'Saving to $destDir...');
    }

    // 1. If song is already cached locally in Musify offline storage, copy it
    if (isSongAlreadyOffline(ytid)) {
      final cachedPath = FilePaths.getAudioPath(ytid);
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) {
        await cachedFile.copy(targetPath);
        if (context.mounted) {
          showToast(context, 'Saved: $fileName');
        }
        return true;
      }
    }

    // 2. Fetch best audio stream (prefer AAC/MP4 container for native .m4a compatibility)
    AudioOnlyStreamInfo? audioManifest;
    try {
      final manifest = await ytClient.videos.streams.getManifest(ytid);
      final aacStreams = manifest.audioOnly.where(
        (s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.codec.toString().toLowerCase().contains('aac') ||
            s.codec.toString().toLowerCase().contains('mp4a'),
      ).toList();
      if (aacStreams.isNotEmpty) {
        aacStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
        audioManifest = aacStreams.first;
      }
    } catch (_) {}

    audioManifest ??= await fetchBestAudioStream(ytid);

    if (audioManifest == null) {
      if (context.mounted) {
        showToast(context, 'Failed to fetch audio stream');
      }
      return false;
    }

    final stream = ytClient.videos.streamsClient.get(
      audioManifest,
      headers: streamPlaybackHeaders(ytid),
    );
    final fileSink = file.openWrite();
    await stream.pipe(fileSink);
    await fileSink.flush();
    await fileSink.close();

    // Register offline path so Musify can play it directly
    try {
      final offlineEntry = Map<String, dynamic>.from(song);
      offlineEntry['audioPath'] = targetPath;
      offlineEntry['dateAdded'] = DateTime.now().millisecondsSinceEpoch;
      final existingIndex =
          userOfflineSongs.value.indexWhere((s) => s['ytid'] == ytid);
      final updatedOfflineSongs = List.from(userOfflineSongs.value);
      if (existingIndex != -1) {
        updatedOfflineSongs[existingIndex] = offlineEntry;
      } else {
        updatedOfflineSongs.add(offlineEntry);
      }
      userOfflineSongs.value = updatedOfflineSongs;
      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlineSongs',
          userOfflineSongs.value,
        ),
      );
    } catch (_) {}

    if (context.mounted) {
      showToast(context, 'Saved: $fileName');
    }
    return true;
  } catch (e, stack) {
    logger.log('Error downloading song to folder', error: e, stackTrace: stack);
    if (context.mounted) {
      showToast(context, 'Error saving song: $e');
    }
    return false;
  }
}

Future<void> downloadPlaylistToFolder(
  BuildContext context,
  List<dynamic> songs,
  String playlistTitle,
) async {
  if (songs.isEmpty) {
    showToast(context, 'Playlist is empty');
    return;
  }

  var baseDir = downloadDirectorySetting.value;
  if (baseDir == null ||
      askDownloadDirectorySetting.value ||
      !await Directory(baseDir).exists()) {
    baseDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder for "$playlistTitle"',
    );
  }

  if (baseDir == null || baseDir.isEmpty) return;

  final playlistFolder =
      Directory('$baseDir/${sanitizeFilename(playlistTitle)}');
  if (!await playlistFolder.exists()) {
    await playlistFolder.create(recursive: true);
  }

  showToast(
    context,
    'Downloading ${songs.length} songs to ${playlistFolder.path}...',
  );

  var successCount = 0;
  for (final song in songs) {
    final success = await downloadSongToFolder(
      context,
      song,
      targetDirectory: playlistFolder.path,
    );
    if (success) successCount++;
  }

  if (context.mounted) {
    showToast(
      context,
      'Downloaded $successCount/${songs.length} songs to ${playlistFolder.path}!',
    );
  }
}
