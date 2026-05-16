import 'package:kurdle_app/services/app_locale.dart';

/// Bir ferheng (sözlük) girdisinin bir tanımı.
///
/// Hem Kurmancî hem Türkçe tanımlar aynı şekli kullanır.
class FerhengDefinition {
  final String gloss;
  final List<FerhengExample> examples;

  const FerhengDefinition({required this.gloss, this.examples = const []});

  factory FerhengDefinition.fromJson(Map<String, dynamic> json) {
    final raw = json['examples'] as List<dynamic>? ?? const [];
    return FerhengDefinition(
      gloss: (json['gloss'] ?? '') as String,
      examples: raw
          .whereType<Map<String, dynamic>>()
          .map(FerhengExample.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'gloss': gloss,
        'examples': examples.map((e) => e.toJson()).toList(),
      };
}

class FerhengExample {
  final String text;
  final String translation;

  const FerhengExample({required this.text, this.translation = ''});

  factory FerhengExample.fromJson(Map<String, dynamic> json) => FerhengExample(
        text: (json['text'] ?? '') as String,
        translation: (json['translation'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        if (translation.isNotEmpty) 'translation': translation,
      };
}

/// Bir Kurmancî kelime ve onun çift dilli tanımları + meta bilgileri.
///
/// Firestore document shape: bkz. plan §3 ve `tools/ferheng_pipeline/scripts/06_emit_artifacts.py`.
class FerhengEntry {
  final String headword; // ekran formatı (orijinal case)
  final String normalized; // wordId — NFC + uppercase
  final List<String> prefixes;
  final String dialect;
  final List<String> pos;
  final String ipa;
  final List<FerhengDefinition> definitionsKmr;
  final List<FerhengDefinition> definitionsTr;
  final String etymology;
  final List<String> categories;
  final List<String> related;
  final String? audioUrl;
  final String source;
  final String sourceUrl;
  final String license;
  final int version;
  final bool isPlayable;

  const FerhengEntry({
    required this.headword,
    required this.normalized,
    this.prefixes = const [],
    this.dialect = 'kmr',
    this.pos = const [],
    this.ipa = '',
    this.definitionsKmr = const [],
    this.definitionsTr = const [],
    this.etymology = '',
    this.categories = const [],
    this.related = const [],
    this.audioUrl,
    this.source = '',
    this.sourceUrl = '',
    this.license = 'CC BY-SA 4.0',
    this.version = 1,
    this.isPlayable = true,
  });

  factory FerhengEntry.fromJson(Map<String, dynamic> json) {
    final defs = (json['definitions'] as Map<String, dynamic>?) ?? const {};
    List<FerhengDefinition> readDefs(String key, String flatKey) {
      final raw = defs[key] as List<dynamic>? ?? const [];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(FerhengDefinition.fromJson)
          .toList(growable: false);
      if (list.isNotEmpty) return list;
      final flat = (json[flatKey] ?? '').toString().trim();
      if (flat.isEmpty) return const [];
      return [FerhengDefinition(gloss: flat)];
    }

    List<String> readStrList(dynamic raw) => (raw as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);

    final headword = (json['headword'] ?? json['word'] ?? '') as String;
    final normalized =
        (json['normalized'] ?? json['normalizedWord'] ?? '').toString();

    return FerhengEntry(
      headword: headword,
      normalized: normalized.isNotEmpty ? normalized : headword.toUpperCase(),
      prefixes: readStrList(json['prefixes']),
      dialect: (json['dialect'] ?? 'kmr') as String,
      pos: readStrList(json['pos']),
      ipa: (json['ipa'] ?? '') as String,
      definitionsKmr: readDefs('kmr', 'kuMeaning'),
      definitionsTr: readDefs('tr', 'trMeaning'),
      etymology: (json['etymology'] ?? '') as String,
      categories: readStrList(json['categories']),
      related: readStrList(json['related']),
      audioUrl: json['audioUrl'] as String?,
      source: (json['source'] ?? '') as String,
      sourceUrl: (json['sourceUrl'] ?? '') as String,
      license: (json['license'] ?? 'CC BY-SA 4.0') as String,
      version: (json['version'] ?? 1) as int,
      isPlayable: (json['isPlayable'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'headword': headword,
        'normalized': normalized,
        'word': headword,
        'normalizedWord': normalized,
        'prefixes': prefixes,
        'dialect': dialect,
        'pos': pos,
        'ipa': ipa,
        'definitions': {
          'kmr': definitionsKmr.map((d) => d.toJson()).toList(),
          'tr': definitionsTr.map((d) => d.toJson()).toList(),
        },
        'kuMeaning':
            definitionsKmr.isNotEmpty ? definitionsKmr.first.gloss : '',
        'trMeaning': definitionsTr.isNotEmpty ? definitionsTr.first.gloss : '',
        'etymology': etymology,
        'categories': categories,
        'related': related,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'source': source,
        'sourceUrl': sourceUrl,
        'license': license,
        'version': version,
        'isPlayable': isPlayable,
      };

  /// Kullanıcının seçtiği dile göre ana tanımı döndürür.
  /// Tercih edilen dilde tanım yoksa diğer dile düşer; o da yoksa boş string.
  String displayGloss(AppLocale locale) {
    final preferred = locale == AppLocale.tr ? definitionsTr : definitionsKmr;
    final fallback = locale == AppLocale.tr ? definitionsKmr : definitionsTr;
    if (preferred.isNotEmpty) return preferred.first.gloss;
    if (fallback.isNotEmpty) return fallback.first.gloss;
    return '';
  }

  String displayMeaning(AppLocale locale) {
    final preferred = locale == AppLocale.tr ? definitionsTr : definitionsKmr;
    final fallback = locale == AppLocale.tr ? definitionsKmr : definitionsTr;
    if (preferred.isNotEmpty) return preferred.first.gloss;
    if (fallback.isNotEmpty) {
      final prefix = locale == AppLocale.tr
          ? L.missingTurkishMeaning
          : L.missingKurdishMeaning;
      return '$prefix\n${fallback.first.gloss}';
    }
    return L.dictionaryEntryMissingMeaning;
  }

  List<FerhengDefinition> definitionsFor(AppLocale locale) =>
      locale == AppLocale.tr ? definitionsTr : definitionsKmr;

  bool get hasAnyDefinition =>
      definitionsKmr.isNotEmpty || definitionsTr.isNotEmpty;
}

/// Ferheng meta dokümanı (Firestore: `ferheng_meta/{lang}`).
/// Cache invalidation ve kill switch için kullanılır.
class FerhengMeta {
  final String version;
  final String dialect;
  final DateTime? lastUpdatedAt;
  final int totalEntries;
  final Map<String, int> letterCounts;
  final Map<String, int> categoryCounts;
  final bool ferhengEnabled;
  final Map<String, String> attribution;

  const FerhengMeta({
    required this.version,
    required this.dialect,
    this.lastUpdatedAt,
    this.totalEntries = 0,
    this.letterCounts = const {},
    this.categoryCounts = const {},
    this.ferhengEnabled = true,
    this.attribution = const {},
  });

  factory FerhengMeta.fromJson(Map<String, dynamic> json) {
    Map<String, int> readCounts(dynamic raw) {
      if (raw is! Map) return const {};
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }

    Map<String, String> readStrMap(dynamic raw) {
      if (raw is! Map) return const {};
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    DateTime? parseTs(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) return DateTime.tryParse(raw);
      // Firestore Timestamp has .toDate(); accessed dynamically to avoid Firestore import here.
      try {
        final dyn = raw as dynamic;
        return dyn.toDate() as DateTime;
      } catch (_) {
        // Firestore Timestamp değil — yoksay (yaygın, gürültü yapmasın)
        return null;
      }
    }

    return FerhengMeta(
      version: (json['version'] ?? '0.0.0') as String,
      dialect: (json['dialect'] ?? 'kmr') as String,
      lastUpdatedAt: parseTs(json['lastUpdatedAt']),
      totalEntries: (json['totalEntries'] ?? 0) as int,
      letterCounts: readCounts(json['letterCounts']),
      categoryCounts: readCounts(json['categoryCounts']),
      ferhengEnabled: (json['ferhengEnabled'] ?? true) as bool,
      attribution: readStrMap(json['attribution']),
    );
  }
}
