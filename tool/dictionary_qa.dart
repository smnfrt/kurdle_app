import 'dart:convert';
import 'dart:io';

String normalize(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

Set<String> loadPlainWords(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .map(normalize)
      .where((word) => word.isNotEmpty)
      .toSet();
}

Set<String> loadGzipWords(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  final text = utf8.decode(gzip.decode(file.readAsBytesSync()));
  return const LineSplitter()
      .convert(text)
      .map(normalize)
      .where((word) => word.isNotEmpty)
      .toSet();
}

Map<String, ({bool ku, bool tr})> loadDictionaryEntries(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final text = utf8.decode(gzip.decode(file.readAsBytesSync()));
  final entries = <String, ({bool ku, bool tr})>{};
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final id = normalize((map['normalized'] ?? map['word'] ?? '').toString());
    if (id.isEmpty) continue;
    final defs = map['definitions'] as Map<String, dynamic>? ?? const {};
    final kuDefs = defs['kmr'] as List<dynamic>? ?? const [];
    final trDefs = defs['tr'] as List<dynamic>? ?? const [];
    entries[id] = (ku: kuDefs.isNotEmpty, tr: trDefs.isNotEmpty);
  }
  return entries;
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

Set<String> loadOverrideWords(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = decoded['entries'] as Map<String, dynamic>? ?? const {};
  return entries.entries
      .where((entry) {
        final value = entry.value;
        if (value is Map) {
          return (value['tr'] ?? '').toString().trim().isNotEmpty;
        }
        return value.toString().trim().isNotEmpty;
      })
      .map((entry) => normalize(entry.key))
      .where((word) => word.isNotEmpty)
      .toSet();
}

void printSample(String title, Iterable<String> words, {int limit = 25}) {
  final sample = words.take(limit).join(', ');
  stdout.writeln('$title: $sample');
}

void main() {
  final playable = <String>{
    ...loadPlainWords('assets/allowed_guesses.txt'),
    ...loadPlainWords('assets/answers.txt'),
    ...loadPlainWords('assets/kurdish_dictionary.txt'),
  };
  final dictionary = loadDictionaryEntries('assets/ferheng/entries.ndjson.gz');
  playable.addAll(dictionary.keys);
  final trOverrides = <String>{
    ...loadOverrideWords('assets/ferheng/tr_meaning_overrides.json'),
    ...loadOverrideWords('assets/ferheng/legacy_meanings.json'),
  };
  final dictionaryWords = dictionary.keys.toSet();
  final playableNotInDictionary = playable.difference(dictionaryWords).toList()
    ..sort();
  final dictionaryNotPlayable = dictionaryWords.difference(playable).toList()
    ..sort();
  final missingTr = dictionary.entries
      .where((entry) => !entry.value.tr && !trOverrides.contains(entry.key))
      .map((entry) => entry.key)
      .toList()
    ..sort();
  bool hasEffectiveTr(String word) {
    if (trOverrides.contains(word) || (dictionary[word]?.tr ?? false)) {
      return true;
    }
    for (final base in inflectionBaseCandidates(word)) {
      if (trOverrides.contains(base) || (dictionary[base]?.tr ?? false)) {
        return true;
      }
    }
    return false;
  }

  final missingEffectiveTr =
      dictionary.keys.where((word) => !hasEffectiveTr(word)).toList()..sort();
  final missingKu = dictionary.entries
      .where((entry) => !entry.value.ku)
      .map((entry) => entry.key)
      .toList()
    ..sort();

  stdout.writeln('Playable words: ${playable.length}');
  stdout.writeln('Dictionary headwords: ${dictionaryWords.length}');
  stdout.writeln(
      'Playable but not dictionary headword: ${playableNotInDictionary.length}');
  stdout
      .writeln('Dictionary but not playable: ${dictionaryNotPlayable.length}');
  stdout.writeln('Dictionary missing Turkish (direct): ${missingTr.length}');
  stdout.writeln(
      'Dictionary missing Turkish (after fallback): ${missingEffectiveTr.length}');
  stdout.writeln('Dictionary missing Kurdish: ${missingKu.length}');
  printSample('Sample playable not in dictionary', playableNotInDictionary);
  printSample('Sample dictionary not playable', dictionaryNotPlayable);
  printSample('Sample missing Turkish (direct)', missingTr);
  printSample('Sample missing Turkish (after fallback)', missingEffectiveTr);
  printSample('Sample missing Kurdish', missingKu);
}
