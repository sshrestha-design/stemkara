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

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/onnx_stem_service.dart';

class StemTracks {
  StemTracks({
    required this.vocalsPath,
    required this.drumsPath,
    required this.bassPath,
    required this.otherPath,
  });

  final String vocalsPath;
  final String drumsPath;
  final String bassPath;
  final String otherPath;
}

class StemPlayerController {
  StemPlayerController({required this.stems});

  final StemTracks stems;

  final AudioPlayer _vocalsPlayer = AudioPlayer();
  final AudioPlayer _drumsPlayer = AudioPlayer();
  final AudioPlayer _bassPlayer = AudioPlayer();
  final AudioPlayer _otherPlayer = AudioPlayer();

  final ValueNotifier<double> vocalsVolume = ValueNotifier(1);
  final ValueNotifier<double> drumsVolume = ValueNotifier(1);
  final ValueNotifier<double> bassVolume = ValueNotifier(1);
  final ValueNotifier<double> otherVolume = ValueNotifier(1);

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  Future<void> init() async {
    try {
      await Future.wait([
        _vocalsPlayer.setFilePath(stems.vocalsPath),
        _drumsPlayer.setFilePath(stems.drumsPath),
        _bassPlayer.setFilePath(stems.bassPath),
        _otherPlayer.setFilePath(stems.otherPath),
      ]);

      await Future.wait([
        _vocalsPlayer.setVolume(vocalsVolume.value),
        _drumsPlayer.setVolume(drumsVolume.value),
        _bassPlayer.setVolume(bassVolume.value),
        _otherPlayer.setVolume(otherVolume.value),
      ]);

      duration.value = _vocalsPlayer.duration ?? Duration.zero;

      _posSub = _vocalsPlayer.positionStream.listen((pos) {
        position.value = pos;
      });

      _stateSub = _vocalsPlayer.playerStateStream.listen((state) {
        isPlaying.value = state.playing;
      });
    } catch (e, st) {
      logger.log('Error initializing StemPlayerController', error: e, stackTrace: st);
    }
  }

  void setVocalsVolume(double volume) {
    vocalsVolume.value = volume.clamp(0.0, 1.0);
    _vocalsPlayer.setVolume(vocalsVolume.value);
  }

  void setDrumsVolume(double volume) {
    drumsVolume.value = volume.clamp(0.0, 1.0);
    _drumsPlayer.setVolume(drumsVolume.value);
  }

  void setBassVolume(double volume) {
    bassVolume.value = volume.clamp(0.0, 1.0);
    _bassPlayer.setVolume(bassVolume.value);
  }

  void setOtherVolume(double volume) {
    otherVolume.value = volume.clamp(0.0, 1.0);
    _otherPlayer.setVolume(otherVolume.value);
  }

  Future<void> play() async {
    await Future.wait([
      _vocalsPlayer.play(),
      _drumsPlayer.play(),
      _bassPlayer.play(),
      _otherPlayer.play(),
    ]);
  }

  Future<void> pause() async {
    await Future.wait([
      _vocalsPlayer.pause(),
      _drumsPlayer.pause(),
      _bassPlayer.pause(),
      _otherPlayer.pause(),
    ]);
  }

  Future<void> seek(Duration target) async {
    await Future.wait([
      _vocalsPlayer.seek(target),
      _drumsPlayer.seek(target),
      _bassPlayer.seek(target),
      _otherPlayer.seek(target),
    ]);
  }

  Future<void> dispose() async {
    await _posSub?.cancel();
    await _stateSub?.cancel();
    await Future.wait([
      _vocalsPlayer.dispose(),
      _drumsPlayer.dispose(),
      _bassPlayer.dispose(),
      _otherPlayer.dispose(),
    ]);
    vocalsVolume.dispose();
    drumsVolume.dispose();
    bassVolume.dispose();
    otherVolume.dispose();
    isPlaying.dispose();
    position.dispose();
    duration.dispose();
  }
}

class StemService {
  static Map<String, String> get executionEnvironment {
    final currentPath = Platform.environment['PATH'] ?? '';
    const extraPaths = [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/Library/Frameworks/Python.framework/Versions/3.14/bin',
      '/Library/Frameworks/Python.framework/Versions/3.13/bin',
      '/Library/Frameworks/Python.framework/Versions/3.12/bin',
      '/Library/Frameworks/Python.framework/Versions/3.11/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
    ];
    final combined = [...extraPaths, ...currentPath.split(':')]
        .where((p) => p.isNotEmpty)
        .toSet()
        .join(':');
    return {
      ...Platform.environment,
      'PATH': combined,
    };
  }

  static String? findPythonPath() {
    const candidates = [
      '/Library/Frameworks/Python.framework/Versions/3.14/bin/python3',
      '/Library/Frameworks/Python.framework/Versions/3.13/bin/python3',
      '/Library/Frameworks/Python.framework/Versions/3.12/bin/python3',
      '/Library/Frameworks/Python.framework/Versions/3.11/bin/python3',
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return 'python3';
  }

  static String? findFfmpegPath() {
    const candidates = [
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return 'ffmpeg';
  }

  static String getKaraokePath(String ytid) {
    final sanitized = ytid.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    return '$applicationDirPath/karaoke_$sanitized.m4a';
  }

  static bool hasKaraokeTrack(String ytid) {
    final file = File(getKaraokePath(ytid));
    return file.existsSync() && file.lengthSync() > 1024;
  }

  static Future<bool> generateKaraokeTrack({
    required String inputAudioPath,
    required String ytid,
  }) async {
    final ffmpeg = findFfmpegPath() ?? 'ffmpeg';
    final outputPath = getKaraokePath(ytid);
    final result = await Process.run(
      ffmpeg,
      [
        '-y',
        '-i',
        inputAudioPath,
        '-af',
        'stereotools=mlev=0.03:slev=1.0',
        outputPath,
      ],
      environment: executionEnvironment,
    );
    return result.exitCode == 0 && File(outputPath).existsSync();
  }

  static String getStemsDirectoryPath(String ytid) {
    final sanitized = ytid.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    return '$applicationDirPath/stems/$sanitized';
  }

  static String? findStemFile(String dirPath, String stem) {
    const extensions = ['.mp3', '.m4a', '.wav', '.flac', '.aac'];
    // 1. Direct folder check
    for (final ext in extensions) {
      final direct = File('$dirPath/$stem$ext');
      if (direct.existsSync() && direct.lengthSync() > 1024) {
        return direct.path;
      }
    }
    // 2. Subdirectory search (e.g. htdemucs/<track>/)
    final htdemucsDir = Directory('$dirPath/htdemucs');
    if (htdemucsDir.existsSync()) {
      try {
        final entities = htdemucsDir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last;
            for (final ext in extensions) {
              if (fileName == '$stem$ext' && entity.lengthSync() > 1024) {
                return entity.path;
              }
            }
          }
        }
      } catch (e) {
        logger.log('Error scanning htdemucs directory for stem $stem: $e');
      }
    }
    return null;
  }

  static bool hasStems(String? ytid) {
    if (ytid == null || ytid.isEmpty) return false;
    final dirPath = getStemsDirectoryPath(ytid);
    return findStemFile(dirPath, 'vocals') != null &&
        findStemFile(dirPath, 'drums') != null &&
        findStemFile(dirPath, 'bass') != null &&
        findStemFile(dirPath, 'other') != null;
  }

  static StemTracks? getStems(String? ytid) {
    if (ytid == null || !hasStems(ytid)) return null;
    final dirPath = getStemsDirectoryPath(ytid);
    final vocals = findStemFile(dirPath, 'vocals');
    final drums = findStemFile(dirPath, 'drums');
    final bass = findStemFile(dirPath, 'bass');
    final other = findStemFile(dirPath, 'other');

    if (vocals == null || drums == null || bass == null || other == null) {
      return null;
    }

    return StemTracks(
      vocalsPath: vocals,
      drumsPath: drums,
      bassPath: bass,
      otherPath: other,
    );
  }

  /// Separates the audio file into 4 stems natively using ONNX Runtime with CoreML.
  /// Falls back to Python CLI Demucs if native separation fails or is unavailable.
  static Future<bool> separateAudioStems({
    required String ytid,
    required String inputAudioPath,
    required void Function(String status, double progress) onProgress,
  }) async {
    // 1. Try Native Apple Silicon CoreML / ONNX Runtime engine (zero Python requirement)
    try {
      final nativeSuccess = await OnnxStemService.separate(
        ytid: ytid,
        inputAudioPath: inputAudioPath,
        onProgress: onProgress,
      );
      if (nativeSuccess) return true;
    } catch (e, st) {
      logger.log('Native CoreML stem separation error, checking Python fallback: $e', stackTrace: st);
    }

    // 2. Secondary fallback: Python CLI Demucs (if installed on host)
    final outputDir = Directory(getStemsDirectoryPath(ytid));
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final python = findPythonPath() ?? 'python3';
    final env = executionEnvironment;
    onProgress('Checking fallback engine ($python)...', 0.1);

    // Check if demucs is installed in python
    final testResult = await Process.run(
      python,
      ['-m', 'demucs', '--help'],
      environment: env,
    );
    if (testResult.exitCode != 0) {
      onProgress('Installing Demucs v4 (Meta AI stem separator)...', 0.2);
      final installResult = await Process.run(
        python,
        [
          '-m',
          'pip',
          'install',
          '--upgrade',
          'demucs',
          'torch',
          'torchaudio',
        ],
        environment: env,
      );
      if (installResult.exitCode != 0) {
        logger.log('Pip install demucs failed: ${installResult.stderr}');
        onProgress('Tip: Run "pip3 install demucs" in Terminal', 0);
        return false;
      }
    }

    onProgress('Separating audio into stems (Vocals, Drums, Bass, Other)...', 0.35);

    final process = await Process.start(
      python,
      [
        '-m',
        'demucs',
        '-n',
        'htdemucs',
        '--mp3',
        '-o',
        outputDir.path,
        inputAudioPath,
      ],
      environment: env,
    );

    final progressRegex = RegExp(r'(\d{1,3})%');
    process.stdout.listen((event) {
      final text = String.fromCharCodes(event);
      logger.log('Demucs stdout: $text');
    });

    process.stderr.listen((event) {
      final text = String.fromCharCodes(event);
      logger.log('Demucs stderr: $text');
      final match = progressRegex.firstMatch(text);
      if (match != null) {
        final pct = int.tryParse(match.group(1) ?? '');
        if (pct != null) {
          final mappedProgress = (0.35 + (pct / 100) * 0.55).clamp(0.35, 0.92);
          onProgress('Demucs AI processing: $pct%', mappedProgress);
        }
      }
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      logger.log('Demucs separation failed with exit code $exitCode');
      return false;
    }

    // Copy outputs to standard stem names in outputDir
    onProgress('Finalizing stem channels...', 0.9);
    final htdemucsFolder = Directory('${outputDir.path}/htdemucs');
    if (htdemucsFolder.existsSync()) {
      final subDirs = htdemucsFolder.listSync().whereType<Directory>();
      for (final sub in subDirs) {
        for (final stem in ['vocals', 'drums', 'bass', 'other']) {
          final foundFile = File('${sub.path}/$stem.mp3');
          if (foundFile.existsSync() && foundFile.lengthSync() > 1024) {
            final destFile = File('${outputDir.path}/$stem.mp3');
            if (!destFile.existsSync() || destFile.lengthSync() < 1024) {
              foundFile.copySync(destFile.path);
            }
          }
        }
      }
    }

    onProgress('Stems ready!', 1);
    return hasStems(ytid);
  }
}
