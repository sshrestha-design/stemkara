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
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:musify/main.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';

class LyricsTranslationResult {
  const LyricsTranslationResult({
    required this.translations,
    required this.romanizations,
    required this.sourceLanguage,
    required this.hasNonLatin,
  });

  final List<String> translations;
  final List<String> romanizations;
  final String sourceLanguage;
  final bool hasNonLatin;

  bool get hasRomanization =>
      romanizations.any((r) => r.trim().isNotEmpty);

  bool get hasTranslation =>
      translations.any((t) => t.trim().isNotEmpty);
}

class LyricsTranslationService {
  static const int _maxCacheSize = 60;
  static final Map<String, LyricsTranslationResult> _cache = {};

  /// Checks if string contains non-Latin scripts (Japanese, Korean, Chinese, Cyrillic, Thai, etc.)
  static bool hasNonLatinScript(String text) {
    return RegExp(
      r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f\uac00-\ud7af\u0400-\u04ff\u0600-\u06ff\u0e00-\u0e7f]',
    ).hasMatch(text);
  }

  /// Translates and Romanizes a list of [LyricLine]s concurrently.
  static Future<LyricsTranslationResult?> translateLines({
    required List<LyricLine> lines,
    String targetLang = 'en',
  }) async {
    if (lines.isEmpty) return null;

    final rawLines = lines.map((l) => l.text.trim()).toList();
    final cacheKey = '$targetLang:${rawLines.take(5).join('|')}:${rawLines.length}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final hasNonLatin = rawLines.any(hasNonLatinScript);
    final translations = List<String>.filled(lines.length, '');
    final romanizations = List<String>.filled(lines.length, '');
    var detectedLanguage = 'unknown';

    // Translate lines in concurrent worker pools of 6
    const chunkSize = 6;
    for (var i = 0; i < rawLines.length; i += chunkSize) {
      final end = (i + chunkSize < rawLines.length) ? i + chunkSize : rawLines.length;
      final futures = <Future<void>>[];

      for (var idx = i; idx < end; idx++) {
        final lineText = rawLines[idx];
        if (lineText.isEmpty) continue;

        futures.add(
          _fetchLineData(lineText, targetLang).then((res) {
            translations[idx] = res.translation;
            romanizations[idx] = res.romanization;
            if (res.sourceLanguage.isNotEmpty && detectedLanguage == 'unknown') {
              detectedLanguage = res.sourceLanguage;
            }
          }).catchError((_) {
            // Gracefully ignore single-line network errors
          }),
        );
      }

      await Future.wait(futures);
    }

    final result = LyricsTranslationResult(
      translations: translations,
      romanizations: romanizations,
      sourceLanguage: detectedLanguage,
      hasNonLatin: hasNonLatin,
    );

    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;

    return result;
  }

  static Future<({String translation, String romanization, String sourceLanguage})>
      _fetchLineData(String text, String targetLang) async {
    try {
      final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLang,
        'dt': ['t', 'rm'],
        'q': text,
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Stemkara/1.0 (macOS)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        return (translation: '', romanization: '', sourceLanguage: '');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      if (data is! List || data.isEmpty) {
        return (translation: '', romanization: '', sourceLanguage: '');
      }

      var translation = '';
      var romanization = '';
      var lang = '';

      if (data.length > 2 && data[2] is String) {
        lang = data[2] as String;
      }

      final rowList = data[0];
      if (rowList is List && rowList.isNotEmpty) {
        // Translation text is in first block
        final firstBlock = rowList[0];
        if (firstBlock is List && firstBlock.isNotEmpty && firstBlock[0] is String) {
          translation = (firstBlock[0] as String).trim();
        }

        // Romanization is found in an item with index 3
        for (final row in rowList) {
          if (row is List && row.length > 3 && row[3] is String) {
            final candidate = (row[3] as String).trim();
            if (candidate.isNotEmpty) {
              romanization = candidate;
              break;
            }
          }
        }
      }

      return (
        translation: translation,
        romanization: romanization,
        sourceLanguage: lang,
      );
    } catch (e, st) {
      logger.log('Lyrics translation line error', error: e, stackTrace: st);
      return (translation: '', romanization: '', sourceLanguage: '');
    }
  }
}
