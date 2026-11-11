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

String applicationDirPath = '';

class FilePaths {
  // File extensions
  static const String audioExtension = '.m4a';
  static const String artworkExtension = '.jpg';

  // Directory names
  static const String tracksDir = 'tracks';
  static const String artworksDir = 'artworks';

  /// Sanitizes songId against directory traversal using an allowlist: [a-zA-Z0-9_-]
  static String sanitizeId(String id) {
    final sanitized = id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }

  // Get full paths for various file types
  static String getAudioPath(String songId) {
    final safeId = sanitizeId(songId);
    return '$applicationDirPath/$tracksDir/$safeId$audioExtension';
  }

  static String getArtworkPath(String songId) {
    final safeId = sanitizeId(songId);
    return '$applicationDirPath/$artworksDir/$safeId$artworkExtension';
  }

  // Ensure directories exist
  static Future<void> ensureDirectoriesExist() async {
    final tracksDirectory = Directory('$applicationDirPath/$tracksDir');
    final artworksDirectory = Directory('$applicationDirPath/$artworksDir');

    if (!await tracksDirectory.exists()) {
      await tracksDirectory.create(recursive: true);
    }

    if (!await artworksDirectory.exists()) {
      await artworksDirectory.create(recursive: true);
    }
  }
}
