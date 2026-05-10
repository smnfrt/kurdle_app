import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Asset wordlist'lerini (düz metin veya `.gz` sıkıştırılmış) yükler.
///
/// `.gz` uzantılı dosyalar `compute()` isolate'inde gunzip + utf8 decode
/// edilerek main isolate bloklanmaz (1.5M satırlık liste için kritik).
class WordlistLoader {
  /// Birden fazla asset yolundan satır birleşimini döndürür.
  /// Tekrarlananlar elenir; sıralama korunmaz.
  static Future<List<String>> loadAssets(List<String> paths) async {
    final all = <String>{};
    for (final path in paths) {
      final lines = await _loadOne(path);
      all.addAll(lines);
    }
    return all.toList(growable: false);
  }

  static Future<List<String>> _loadOne(String path) async {
    if (path.endsWith('.gz')) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      // İsolate'a immutable Uint8List geçir; ana thread'i bloklamaz.
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
  // Boş son satırları atla; trim/uppercase üst katmanın işi.
  final lines = const LineSplitter().convert(text);
  return lines.where((l) => l.isNotEmpty).toList(growable: false);
}
