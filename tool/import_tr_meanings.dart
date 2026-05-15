import 'dart:convert';
import 'dart:io';

String normalize(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

String unquote(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed
        .substring(1, trimmed.length - 1)
        .replaceAll('""', '"')
        .trim();
  }
  return trimmed;
}

List<String> splitLine(String line) {
  final delimiter = line.contains('\t') ? '\t' : ',';
  final values = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (!quoted && char == delimiter) {
      values.add(buffer.toString().trim());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  values.add(buffer.toString().trim());
  return values.map(unquote).toList(growable: false);
}

void usage() {
  stderr.writeln(
      'Usage: dart run tool/import_tr_meanings.dart <input.csv|tsv> <source-label>');
  stderr.writeln('Input columns: word,trMeaning');
}

void main(List<String> args) {
  if (args.length < 2) {
    usage();
    exitCode = 64;
    return;
  }

  final input = File(args[0]);
  final source = args[1].trim();
  if (!input.existsSync() || source.isEmpty) {
    usage();
    exitCode = 64;
    return;
  }

  final overridesFile = File('assets/ferheng/tr_meaning_overrides.json');
  final decoded =
      json.decode(overridesFile.readAsStringSync()) as Map<String, dynamic>;
  final entries = Map<String, dynamic>.from(
      decoded['entries'] as Map<String, dynamic>? ?? const {});

  var imported = 0;
  var skipped = 0;
  for (final rawLine in input.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final cols = splitLine(line);
    if (cols.length < 2) {
      skipped++;
      continue;
    }
    final word = normalize(cols[0]);
    final tr = cols[1].trim();
    if (word.isEmpty ||
        tr.isEmpty ||
        word == 'WORD' ||
        word == 'NORMALIZED' ||
        tr.toLowerCase() == 'trmeaning') {
      skipped++;
      continue;
    }
    entries[word] = {'tr': tr, 'source': source};
    imported++;
  }

  final sorted = Map.fromEntries(
    entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  decoded['entries'] = sorted;
  overridesFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(decoded),
  );
  stdout.writeln('Imported: $imported');
  stdout.writeln('Skipped: $skipped');
  stdout.writeln('Total overrides: ${sorted.length}');
}
