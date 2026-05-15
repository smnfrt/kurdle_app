import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Asset wordlist'lerini (düz metin veya `.gz` sıkıştırılmış) yükler.
///
/// `.gz` uzantılı dosyalar `compute()` isolate'inde gunzip + utf8 decode
/// edilerek main isolate bloklanmaz (1.5M satırlık liste için kritik).
///
/// **Cache**: aynı asset path kombinasyonu için sonuç in-memory tutulur.
/// İlk yüklemeden sonra her oyun başlangıcı anında döner.
class WordlistLoader {
  static final Map<String, List<String>> _cache = {};
  static final Map<String, Future<List<String>>> _inflight = {};

  /// Birden fazla asset yolundan satır birleşimini döndürür.
  /// Tekrarlananlar elenir; sıralama korunmaz. Tekrar çağrılarda cache'ten döner.
  static Future<List<String>> loadAssets(List<String> paths) async {
    final key = (List<String>.from(paths)..sort()).join('|');

    // Cache hit
    final cached = _cache[key];
    if (cached != null) return cached;

    // Aynı anda 2 caller varsa tek bir future paylaşsın (in-flight de-dupe)
    final inFlight = _inflight[key];
    if (inFlight != null) return inFlight;

    final future = _loadAndCache(paths, key);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  static Future<List<String>> _loadAndCache(
      List<String> paths, String key) async {
    final all = <String>{};
    for (final path in paths) {
      final lines = await _loadOne(path);
      all.addAll(lines);
    }
    final result = all.toList(growable: false);
    _cache[key] = result;
    return result;
  }

  /// Test veya bellek baskısı durumunda manuel boşalt.
  static void clearCache() {
    _cache.clear();
  }

  /// Cache hit kontrolü — preload tamamlandı mı.
  static bool isCached(List<String> paths) {
    final key = (List<String>.from(paths)..sort()).join('|');
    return _cache.containsKey(key);
  }

  static Future<List<String>> _loadOne(String path) async {
    if (path.endsWith('.gz')) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      if (path.endsWith('entries.ndjson.gz')) {
        return compute(_decodeFerhengEntryWords, bytes);
      }
      return compute(_decodeGzipLines, bytes);
    }
    final raw = await rootBundle.loadString(path);
    return const LineSplitter().convert(raw);
  }
}

/// Top-level fonksiyon — `compute()` requirement.
List<String> _decodeGzipLines(Uint8List bytes) {
  final decoded = GZipDecoder().decodeBytes(bytes);
  final text = utf8.decode(decoded, allowMalformed: false);
  final lines = const LineSplitter().convert(text);
  return lines.where((l) => l.isNotEmpty).toList(growable: false);
}

List<String> _decodeFerhengEntryWords(Uint8List bytes) {
  final decoded = GZipDecoder().decodeBytes(bytes);
  final text = utf8.decode(decoded, allowMalformed: false);
  final words = <String>{};
  for (final line in const LineSplitter().convert(text)) {
    if (line.isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final word = (map['normalized'] ?? map['word'] ?? '').toString().trim();
    if (word.isNotEmpty) words.add(word);
  }
  return words.toList(growable: false);
}
