import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:kurdle_app/services/word_normalizer.dart';

const _dictZipPath =
    'tools/ferheng_pipeline/raw/freedict-kur-tur-0.1.2/kur-tur/kur-tur.dict.dz';
const _indexPath =
    'tools/ferheng_pipeline/raw/freedict-kur-tur-0.1.2/kur-tur/kur-tur.index';
const _overridesPath = 'assets/ferheng/tr_meaning_overrides.json';
const _sourceId = 'freedict-kur-tur-0.1.2';
const _sourceLabel = 'project-curated + FreeDict kur-tur 0.1.2';
const _dictBase64Alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

void main() {
  final dictFile = File(_dictZipPath);
  final indexFile = File(_indexPath);
  final overridesFile = File(_overridesPath);

  if (!dictFile.existsSync()) {
    throw StateError('FreeDict dict.dz bulunamadı: $_dictZipPath');
  }
  if (!indexFile.existsSync()) {
    throw StateError('FreeDict index bulunamadı: $_indexPath');
  }
  if (!overridesFile.existsSync()) {
    throw StateError('Override dosyası bulunamadı: $_overridesPath');
  }

  final dictBytes = GZipDecoder().decodeBytes(dictFile.readAsBytesSync());
  final imported = _readFreedictEntries(indexFile, dictBytes);
  final original =
      json.decode(overridesFile.readAsStringSync()) as Map<String, dynamic>;
  final rawEntries = (original['entries'] as Map<String, dynamic>? ?? {});
  final mergedEntries = <String, Map<String, String>>{};

  for (final item in rawEntries.entries) {
    final key = WordNormalizer.normalize(item.key);
    final value = item.value;
    final tr = value is Map
        ? (value['tr'] ?? '').toString().trim()
        : value.toString().trim();
    if (key.isEmpty || tr.isEmpty) continue;
    mergedEntries[key] = {
      'tr': tr,
      if (value is Map && (value['source'] ?? '').toString().isNotEmpty)
        'source': value['source'].toString(),
    };
  }

  final beforeCount = mergedEntries.length;
  var added = 0;
  var updatedFreedict = 0;
  var keptCurated = 0;
  var removedStaleFreedict = 0;
  for (final item in imported.entries) {
    final existing = mergedEntries[item.key];
    final existingSource = existing?['source'] ?? '';
    if (existingSource == _sourceId) {
      mergedEntries[item.key] = {
        'tr': item.value,
        'source': _sourceId,
      };
      updatedFreedict++;
      continue;
    }
    if (existing != null && (existing['tr'] ?? '').isNotEmpty) {
      keptCurated++;
      continue;
    }
    mergedEntries[item.key] = {
      'tr': item.value,
      'source': _sourceId,
    };
    added++;
  }

  final importedKeys = imported.keys.toSet();
  mergedEntries.removeWhere((key, value) {
    final shouldRemove =
        value['source'] == _sourceId && !importedKeys.contains(key);
    if (shouldRemove) removedStaleFreedict++;
    return shouldRemove;
  });

  final sortedKeys = mergedEntries.keys.toList()..sort();
  final output = <String, dynamic>{
    'version': '1.1.0',
    'source': _sourceLabel,
    'licenseNote':
        'FreeDict-derived entries are GPL-2.0-or-later; project-curated entries keep their original project license.',
    'entries': {
      for (final key in sortedKeys) key: mergedEntries[key],
    },
  };

  const encoder = JsonEncoder.withIndent('  ');
  overridesFile.writeAsStringSync('${encoder.convert(output)}\n');

  stdout.writeln('FreeDict okundu: ${imported.length} benzersiz başlık');
  stdout.writeln('Önceki override: $beforeCount');
  stdout.writeln('Yeni eklenen TR anlam: $added');
  stdout.writeln('Güncellenen FreeDict anlam: $updatedFreedict');
  stdout.writeln('Korunan mevcut/curated anlam: $keptCurated');
  stdout.writeln('Temizlenen boş/eski FreeDict anlam: $removedStaleFreedict');
  stdout.writeln('Toplam override: ${mergedEntries.length}');
}

Map<String, String> _readFreedictEntries(File indexFile, List<int> dictBytes) {
  final meaningsByWord = <String, List<String>>{};
  final seenByWord = <String, Set<String>>{};

  for (final line in indexFile.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 3) continue;
    final headword = parts[0];
    if (headword.startsWith('00database')) continue;

    final normalized = WordNormalizer.normalize(headword);
    if (normalized.isEmpty) continue;

    final offset = _decodeDictBase64(parts[1]);
    final length = _decodeDictBase64(parts[2]);
    if (offset < 0 || length <= 0 || offset + length > dictBytes.length) {
      continue;
    }

    final rawDefinition = utf8.decode(
      dictBytes.sublist(offset, offset + length),
      allowMalformed: true,
    );
    final cleaned = _cleanDefinition(rawDefinition, normalized);
    if (cleaned.isEmpty) continue;

    final seen = seenByWord.putIfAbsent(normalized, () => <String>{});
    final meanings = meaningsByWord.putIfAbsent(normalized, () => <String>[]);
    for (final meaning in cleaned) {
      if (seen.add(meaning)) meanings.add(meaning);
      if (meanings.length >= 5) break;
    }
  }

  return {
    for (final item in meaningsByWord.entries)
      item.key: item.value.take(5).join('; '),
  };
}

List<String> _cleanDefinition(String raw, String normalizedHeadword) {
  final out = <String>[];
  for (final line in const LineSplitter().convert(raw)) {
    final cleaned = line
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[;,\-\u2022\s]+'), '')
        .trim();
    if (cleaned.isEmpty) continue;
    if (WordNormalizer.normalize(cleaned) == normalizedHeadword) continue;
    if (cleaned.startsWith('[') && cleaned.endsWith(']')) continue;
    if (cleaned.length > 120) continue;
    out.add(cleaned);
  }
  return out;
}

int _decodeDictBase64(String value) {
  var result = 0;
  for (final codeUnit in value.codeUnits) {
    final index = _dictBase64Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw FormatException('DICT base64 karakteri çözülemedi: $value');
    }
    result = (result * 64) + index;
  }
  return result;
}
