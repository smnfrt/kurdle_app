import 'dart:convert';
import 'dart:io';

String normalize(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

Iterable<String> loadPlainWords(String path) {
  final file = File(path);
  if (!file.existsSync()) return const <String>[];
  return file.readAsLinesSync().map(normalize).where((word) => word.isNotEmpty);
}

Map<String, String> loadEntryTurkish(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final text = utf8.decode(gzip.decode(file.readAsBytesSync()));
  final out = <String, String>{};
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final id = normalize((map['normalized'] ?? map['word'] ?? '').toString());
    final defs = map['definitions'] as Map<String, dynamic>? ?? const {};
    final trDefs = defs['tr'] as List<dynamic>? ?? const [];
    if (id.isEmpty || trDefs.isEmpty) continue;
    final first = trDefs.first;
    final gloss = first is Map ? (first['gloss'] ?? '').toString().trim() : '';
    if (gloss.isNotEmpty) out[id] = gloss;
  }
  return out;
}

Map<String, String> loadOverrides(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = decoded['entries'] as Map<String, dynamic>? ?? const {};
  return entries.map((key, value) {
    final tr = value is Map ? (value['tr'] ?? '').toString() : value.toString();
    return MapEntry(normalize(key), tr.trim());
  })
    ..removeWhere((key, value) => key.isEmpty || value.isEmpty);
}

Iterable<String> inflectionBaseCandidates(String id) sync* {
  const suffixes = [
    'TIRÎNAN',
    'TIRÎNEKE',
    'TIRÎNEKÊ',
    'TIRÎNEK',
    'TIRÎNA',
    'TIRÎN',
    'TIRAN',
    'TIREKE',
    'TIREKÊ',
    'TIREK',
    'TIRA',
    'TIRÊN',
    'TIRÊ',
    'TIRÎ',
    'TIR',
    'IBÛNAN',
    'IBÛNE',
    'IBÛN',
    'ÎBÛNAN',
    'ÎBÛNE',
    'ÎBÛN',
    'INAN',
    'IYÊN',
    'IYAN',
    'IYÊ',
    'IYA',
    'ÎYÊN',
    'ÎYAN',
    'ÎYÊ',
    'ÎYA',
    'INE',
    'INO',
    'IN',
    'EKE',
    'EKÊ',
    'EKÎ',
    'EK',
    'ÊN',
    'AN',
    'A',
    'E',
    'Ê',
    'Î',
    'O',
  ];
  const replacements = <({String suffix, String replacement})>[
    (suffix: 'IBÛNAN', replacement: 'IN'),
    (suffix: 'IBÛNE', replacement: 'IN'),
    (suffix: 'IBÛN', replacement: 'IN'),
    (suffix: 'ÎBÛNAN', replacement: 'ÎN'),
    (suffix: 'ÎBÛNE', replacement: 'ÎN'),
    (suffix: 'ÎBÛN', replacement: 'ÎN'),
  ];

  final seen = <String>{};
  for (final rule in replacements) {
    if (!id.endsWith(rule.suffix) || id.length <= rule.suffix.length + 2) {
      continue;
    }
    final candidate =
        '${id.substring(0, id.length - rule.suffix.length)}${rule.replacement}';
    if (seen.add(candidate)) yield candidate;
  }
  for (final suffix in suffixes) {
    if (!id.endsWith(suffix) || id.length <= suffix.length + 2) continue;
    final candidate = id.substring(0, id.length - suffix.length);
    if (seen.add(candidate)) yield candidate;
  }
}

void main() {
  const overridesPath = 'assets/ferheng/tr_meaning_overrides.json';
  final overridesFile = File(overridesPath);
  if (!overridesFile.existsSync()) {
    throw StateError('Override dosyası bulunamadı: $overridesPath');
  }

  final decoded =
      json.decode(overridesFile.readAsStringSync()) as Map<String, dynamic>;
  final rawEntries = Map<String, dynamic>.from(
      decoded['entries'] as Map<String, dynamic>? ?? const {});
  final directOverrides = loadOverrides(overridesPath);
  final legacyOverrides = loadOverrides('assets/ferheng/legacy_meanings.json');
  final entryTurkish = loadEntryTurkish('assets/ferheng/entries.ndjson.gz');
  final trByWord = <String, String>{
    ...entryTurkish,
    ...legacyOverrides,
    ...directOverrides,
  };

  final candidateWords = <String>{
    ...loadPlainWords('assets/allowed_guesses.txt'),
    ...loadPlainWords('assets/answers.txt'),
    ...loadPlainWords('assets/kurdish_dictionary.txt'),
    ...loadEntryWords('assets/ferheng/entries.ndjson.gz'),
  };

  var added = 0;
  for (final word in candidateWords) {
    if (word.isEmpty || trByWord.containsKey(word)) continue;
    for (final base in inflectionBaseCandidates(word)) {
      final tr = trByWord[base];
      if (tr == null || tr.isEmpty) continue;
      rawEntries[word] = {
        'tr': tr,
        'source': 'inferred-inflection:$base',
      };
      trByWord[word] = tr;
      added++;
      break;
    }
  }

  final sorted = Map.fromEntries(
    rawEntries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  final output = <String, dynamic>{
    ...decoded,
    'version': '1.2.0',
    'source':
        '${decoded['source'] ?? 'project-curated + FreeDict kur-tur 0.1.2'} + inferred inflection TR fallbacks',
    'entries': sorted,
  };
  overridesFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );

  stdout.writeln('Inferred Turkish overrides added: $added');
  stdout.writeln('Total overrides: ${sorted.length}');
}

Iterable<String> loadEntryWords(String path) sync* {
  final file = File(path);
  if (!file.existsSync()) return;
  final text = utf8.decode(gzip.decode(file.readAsBytesSync()));
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final id = normalize((map['normalized'] ?? map['word'] ?? '').toString());
    if (id.isNotEmpty) yield id;
  }
}
