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

Set<String> loadOverrideWords(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = decoded['entries'] as Map<String, dynamic>? ?? const {};
  return entries.entries
      .where((entry) {
        final value = entry.value;
        if (value is Map)
          return (value['tr'] ?? '').toString().trim().isNotEmpty;
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
  stdout.writeln('Dictionary missing Turkish: ${missingTr.length}');
  stdout.writeln('Dictionary missing Kurdish: ${missingKu.length}');
  printSample('Sample playable not in dictionary', playableNotInDictionary);
  printSample('Sample dictionary not playable', dictionaryNotPlayable);
  printSample('Sample missing Turkish', missingTr);
  printSample('Sample missing Kurdish', missingKu);
}
