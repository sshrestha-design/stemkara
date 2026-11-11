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

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:musify/main.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/stem_service.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Native ONNX Runtime & Apple Silicon CoreML (ANE / Metal) Stem Separation Engine.
/// Operates directly on raw float32 waveforms with zero Python dependencies.
class OnnxStemService {
  static const int sampleRate = 44100;
  static const double segmentSeconds = 7.8;
  static const int segmentSamples = 343980; // 7.8 * 44100
  static const int numChannels = 2; // Stereo

  static const String modelFileName = 'htdemucs_fp16weights.onnx';
  static const String modelDownloadUrl =
      'https://huggingface.co/StemSplitio/htdemucs-onnx/resolve/main/htdemucs_fp16weights.onnx';

  static String get modelsDirectoryPath => '$applicationDirPath/models';
  static String get modelFilePath => '$modelsDirectoryPath/$modelFileName';

  /// Checks if the ONNX separation model exists on disk and is valid.
  static bool isModelAvailable() {
    final file = File(modelFilePath);
    // htdemucs_fp16weights is ~165 MB
    return file.existsSync() && file.lengthSync() > 100 * 1024 * 1024;
  }

  /// Downloads the ONNX model from the CDN with streaming progress.
  static Future<bool> downloadModel({
    required void Function(double progress, String status) onProgress,
  }) async {
    final modelsDir = Directory(modelsDirectoryPath);
    if (!modelsDir.existsSync()) {
      modelsDir.createSync(recursive: true);
    }

    final targetFile = File(modelFilePath);
    final tempFile = File('$modelFilePath.tmp');

    try {
      onProgress(0.01, 'Connecting to model repository...');
      final request = http.Request('GET', Uri.parse(modelDownloadUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        logger.log('Failed to download ONNX model: HTTP ${response.statusCode}');
        return false;
      }

      final totalBytes = response.contentLength ?? (165 * 1024 * 1024);
      var receivedBytes = 0;

      final sink = tempFile.openWrite();
      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        onProgress(
          progress,
          'Downloading CoreML model: $mbReceived / $mbTotal MB (${(progress * 100).toInt()}%)',
        );
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (tempFile.existsSync() && tempFile.lengthSync() > 100 * 1024 * 1024) {
        if (targetFile.existsSync()) targetFile.deleteSync();
        tempFile.renameSync(targetFile.path);
        onProgress(1, 'CoreML model ready.');
        return true;
      } else {
        logger.log('Downloaded model file is incomplete.');
        return false;
      }
    } catch (e, st) {
      logger.log('Error downloading model', error: e, stackTrace: st);
      if (tempFile.existsSync()) tempFile.deleteSync();
      return false;
    }
  }

  /// Separates an input audio file into 4 stems natively using ONNX Runtime with CoreML.
  static Future<bool> separate({
    required String ytid,
    required String inputAudioPath,
    required void Function(String status, double progress) onProgress,
  }) async {
    final ffmpeg = StemService.findFfmpegPath() ?? 'ffmpeg';
    final outputDir = Directory(StemService.getStemsDirectoryPath(ytid));
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // 1. Verify model presence or trigger download
    if (!isModelAvailable()) {
      onProgress('Downloading neural separation model (165 MB)...', 0.05);
      final downloaded = await downloadModel(
        onProgress: (p, status) => onProgress(status, 0.05 + p * 0.25),
      );
      if (!downloaded) {
        onProgress('Model download failed. Check network connection.', 0);
        return false;
      }
    }

    // 2. Decode source audio to raw float32 stereo PCM via ffmpeg
    onProgress('Decoding audio to 44.1 kHz float32 stereo...', 0.32);
    final rawInputPath = '${outputDir.path}/temp_mix.raw';
    final decodeResult = await Process.run(
      ffmpeg,
      [
        '-y',
        '-i',
        inputAudioPath,
        '-f',
        'f32le',
        '-ac',
        '2',
        '-ar',
        '44100',
        rawInputPath,
      ],
      environment: StemService.executionEnvironment,
    );

    final rawInputFile = File(rawInputPath);
    if (decodeResult.exitCode != 0 || !rawInputFile.existsSync()) {
      logger.log('FFmpeg PCM decode failed: ${decodeResult.stderr}');
      onProgress('Failed to decode audio track.', 0);
      return false;
    }

    // 3. Load PCM data into memory
    final rawBytes = rawInputFile.readAsBytesSync();
    final floatList = Float32List.view(
      rawBytes.buffer,
      rawBytes.offsetInBytes,
      rawBytes.lengthInBytes ~/ 4,
    );
    final totalSamples = floatList.length ~/ 2; // Stereo samples per channel

    if (totalSamples == 0) {
      logger.log('Decoded PCM audio is empty.');
      return false;
    }

    // Separate stereo channels: channel 0 (L) and channel 1 (R)
    final leftChannel = Float32List(totalSamples);
    final rightChannel = Float32List(totalSamples);
    for (var i = 0; i < totalSamples; i++) {
      leftChannel[i] = floatList[i * 2];
      rightChannel[i] = floatList[i * 2 + 1];
    }

    // 4. Initialize ONNX Runtime session with Apple Silicon CoreML hardware acceleration
    onProgress('Initializing Apple Silicon CoreML (ANE / Metal)...', 0.38);
    OrtEnv.instance.init();

    final sessionOptions = OrtSessionOptions();
    try {
      sessionOptions.appendCoreMLProvider(CoreMLFlags.enableOnSubgraph);
    } catch (_) {
      sessionOptions.appendCPUProvider(CPUFlags.useArena);
    }

    final session = OrtSession.fromFile(File(modelFilePath), sessionOptions);
    final runOptions = OrtRunOptions();

    // 5. Overlap-add chunking inference
    const overlap = segmentSamples ~/ 4; // 25% overlap
    const stride = segmentSamples - overlap;
    final numChunks = max(1, (totalSamples + stride - 1) ~/ stride);

    // Fade window for smooth crossfades
    final window = Float32List(segmentSamples);
    for (var i = 0; i < segmentSamples; i++) {
      if (i < overlap) {
        window[i] = i / overlap;
      } else if (i >= segmentSamples - overlap) {
        window[i] = (segmentSamples - 1 - i) / overlap;
      } else {
        window[i] = 1.0;
      }
    }

    // 4 stems: 0 = Drums, 1 = Bass, 2 = Other, 3 = Vocals
    final stemsLeft = List.generate(4, (_) => Float32List(totalSamples));
    final stemsRight = List.generate(4, (_) => Float32List(totalSamples));
    final weightSum = Float32List(totalSamples);

    for (var c = 0; c < numChunks; c++) {
      final start = c * stride;
      final end = min(start + segmentSamples, totalSamples);
      final chunkLen = end - start;

      // Prepare input tensor: shape [1, 2, 343980]
      final inputBuffer = Float32List(2 * segmentSamples);
      for (var i = 0; i < chunkLen; i++) {
        inputBuffer[i] = leftChannel[start + i];
        inputBuffer[segmentSamples + i] = rightChannel[start + i];
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputBuffer,
        [1, 2, segmentSamples],
      );

      final outputs = session.run(runOptions, {'mix': inputTensor});
      inputTensor.release();

      if (outputs.isNotEmpty && outputs[0] != null) {
        final outTensor = outputs[0]!;
        final outData = outTensor.value as List<dynamic>;
        _accumulateStems(
          outData: outData,
          stemsLeft: stemsLeft,
          stemsRight: stemsRight,
          weightSum: weightSum,
          window: window,
          start: start,
          chunkLen: chunkLen,
        );
        outTensor.release();
      }

      final progress = 0.40 + (c / numChunks) * 0.48;
      onProgress(
        'CoreML ANE Inference: Chunk ${c + 1}/$numChunks (${(progress * 100).toInt()}%)',
        progress,
      );
    }

    // Normalize overlapping segments by weight sum
    for (var i = 0; i < totalSamples; i++) {
      final w = max(weightSum[i], 1e-6);
      for (var s = 0; s < 4; s++) {
        stemsLeft[s][i] /= w;
        stemsRight[s][i] /= w;
      }
    }

    session.release();
    sessionOptions.release();
    runOptions.release();

    // 6. Encode 4 stems into high quality MP3 files
    onProgress('Encoding 4 high-fidelity stem audio channels...', 0.90);
    final stemNames = ['drums', 'bass', 'other', 'vocals'];
    for (var s = 0; s < 4; s++) {
      final interleaved = Float32List(totalSamples * 2);
      for (var i = 0; i < totalSamples; i++) {
        interleaved[i * 2] = stemsLeft[s][i];
        interleaved[i * 2 + 1] = stemsRight[s][i];
      }

      final rawStemPath = '${outputDir.path}/raw_${stemNames[s]}.pcm';
      final mp3StemPath = '${outputDir.path}/${stemNames[s]}.mp3';

      File(rawStemPath).writeAsBytesSync(interleaved.buffer.asUint8List());

      await Process.run(
        ffmpeg,
        [
          '-y',
          '-f',
          'f32le',
          '-ar',
          '44100',
          '-ac',
          '2',
          '-i',
          rawStemPath,
          '-b:a',
          '256k',
          mp3StemPath,
        ],
        environment: StemService.executionEnvironment,
      );

      // Clean up temporary raw pcm
      final rawFile = File(rawStemPath);
      if (rawFile.existsSync()) rawFile.deleteSync();
    }

    // Clean up temporary mix raw file
    if (rawInputFile.existsSync()) rawInputFile.deleteSync();

    onProgress('Stems separated and ready!', 1);
    return StemService.hasStems(ytid);
  }

  static void _accumulateStems({
    required List<dynamic> outData,
    required List<Float32List> stemsLeft,
    required List<Float32List> stemsRight,
    required Float32List weightSum,
    required Float32List window,
    required int start,
    required int chunkLen,
  }) {
    try {
      final batch0 = outData[0] as List<dynamic>;
      for (var s = 0; s < 4; s++) {
        final stemChannels = batch0[s] as List<dynamic>;
        final leftList = stemChannels[0] as List<dynamic>;
        final rightList = stemChannels[1] as List<dynamic>;

        for (var i = 0; i < chunkLen; i++) {
          final w = window[i];
          stemsLeft[s][start + i] += (leftList[i] as num).toDouble() * w;
          stemsRight[s][start + i] += (rightList[i] as num).toDouble() * w;
        }
      }

      for (var i = 0; i < chunkLen; i++) {
        weightSum[start + i] += window[i];
      }
    } catch (e) {
      logger.log('Error parsing ONNX output tensor structure: $e');
    }
  }
}
