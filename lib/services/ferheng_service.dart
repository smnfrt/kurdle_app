import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_repository.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/word_normalizer.dart';
import 'package:kurdle_app/services/wordlist_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bundled (offline) ferheng servisi.
///
/// Tüm 196k+ entry uygulama açılışında `assets/ferheng/entries.ndjson.gz`'den
/// in-memory'e yüklenir (compute() isolate'inde). Lookup'lar O(1) Map.
/// Firestore artık yalnızca favoriler + meta için kullanılır.
class FerhengService {
  FerhengService._({FerhengRepository? repo})
      : _repo = repo ?? FerhengRepository();

  static FerhengService? _instance;
  static FerhengService get instance => _instance ??= FerhengService._();

  static const String _entriesAsset = 'assets/ferheng/entries.ndjson.gz';
  static const String _legacyAsset = 'assets/ferheng/legacy_meanings.json';
  static const String _trOverridesAsset =
      'assets/ferheng/tr_meaning_overrides.json';
  static const String _categoriesAsset = 'assets/ferheng/categories.json';

  static const String _prefRecentSearchesKey = 'ferheng_recent_searches';
  static const int _maxRecentSearches = 20;

  final FerhengRepository _repo;

  // In-memory veri
  Map<String, FerhengEntry> _byId = const {};
  Map<String, List<String>> _byPrefix = const {}; // 1-4 char prefix → ids
  Map<String, List<String>> _byCategory = const {}; // category id → ids
  Map<String, String> _relatedToId = const {}; // çekimli form → başlık id
  List<String> _sortedIds = const []; // alfabetik gezinme için

  Map<String, String>? _legacy;
  Map<String, String>? _trOverrides;
  Set<String>? _playableWords;
  Future<Set<String>>? _playableWordsFuture;
  List<Map<String, String>>? _categories;
  FerhengMeta? _meta;
  bool _initialized = false;
  Future<void>? _initFuture;

  /// Açılışta çağrılır. Idempotent.
  Future<void> init() async {
    if (_initialized) return;
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;
    final future = _init();
    _initFuture = future;
    return future.whenComplete(() {
      _initFuture = null;
    });
  }

  Future<void> _init() async {
    await _loadLegacyBundle();
    await _loadTrOverridesBundle();
    await _loadCategoriesBundle();
    await _loadEntriesBundle();
    // Meta best-effort — başarısızsa offline mod.
    unawaited(_refreshMeta());
    _initialized = true;
  }

  // ── Bundle yükleme ──────────────────────────────────────────────

  Future<void> _loadEntriesBundle() async {
    final data = await rootBundle.load(_entriesAsset);
    final bytes = data.buffer.asUint8List();
    final result = await compute(_parseEntriesBundle, bytes);
    _byId = result.byId;
    _byPrefix = result.byPrefix;
    _byCategory = result.byCategory;
    _relatedToId = result.relatedToId;
    _sortedIds = result.sortedIds;
  }

  Future<void> _loadLegacyBundle() async {
    try {
      final raw = await rootBundle.loadString(_legacyAsset);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final entries = (decoded['entries'] as Map<String, dynamic>? ?? const {});
      _legacy = entries.map(
        (k, v) => MapEntry(k, ((v as Map)['tr'] ?? '').toString()),
      );
    } catch (_) {
      _legacy = const {};
    }
  }

  Future<void> _loadTrOverridesBundle() async {
    try {
      final raw = await rootBundle.loadString(_trOverridesAsset);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final entries = (decoded['entries'] as Map<String, dynamic>? ?? const {});
      _trOverrides = entries.map((k, v) {
        final value = v is Map ? (v['tr'] ?? '').toString() : v.toString();
        return MapEntry(_normalize(k), value.trim());
      })
        ..removeWhere((_, v) => v.isEmpty);
    } catch (_) {
      _trOverrides = const {};
    }
  }

  Future<void> _loadCategoriesBundle() async {
    try {
      final raw = await rootBundle.loadString(_categoriesAsset);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final list = (decoded['categories'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map<Map<String, String>>(
              (m) => m.map((k, v) => MapEntry(k, v.toString())))
          .toList(growable: false);
      _categories = list;
    } catch (_) {
      _categories = const [];
    }
  }

  Future<void> _refreshMeta() async {
    try {
      _meta = await _repo.meta();
    } catch (_) {/* offline */}
  }

  // ── Lookup ──────────────────────────────────────────────────────

  String _normalize(String word) => WordNormalizer.normalize(word);

  Future<FerhengEntry?> getEntry(String word) async {
    await init();
    final id = _normalize(word);
    return _byId[id] ?? _entryForRelatedForm(id) ?? _entryForInflectedForm(id);
  }

  /// `getEntry` + legacy TR fallback. Bundle'da tüm entry'ler var olduğundan
  /// fallback nadiren gerekir; legacy 318 entry curated TR sağlar.
  Future<FerhengEntry?> getOrFallback(String word) async {
    await init();
    final id = _normalize(word);
    final entry = _byId[id];
    final relatedEntry = entry == null ? _entryForRelatedForm(id) : null;
    if (relatedEntry != null) return relatedEntry;
    final overrideTr = _trOverrides?[id];
    if (overrideTr != null &&
        overrideTr.isNotEmpty &&
        (entry == null || entry.definitionsTr.isEmpty)) {
      return _entryWithTurkishOverride(entry, word, id, overrideTr);
    }
    if (entry != null && entry.hasAnyDefinition) return entry;
    final inflectedEntry = entry == null ? _entryForInflectedForm(id) : null;
    if (inflectedEntry != null) return inflectedEntry;
    final legacyTr = _legacy?[id];
    if (legacyTr != null && legacyTr.isNotEmpty) {
      return _entryWithTurkishOverride(entry, word, id, legacyTr);
    }
    if (entry == null && await isPlayableWord(id)) {
      return _playableOnlyEntry(id);
    }
    return entry; // null veya tanımsız boş entry
  }

  Future<DictionaryMeaningResult> lookupMeaning(
    String word, {
    bool acceptedInGame = false,
  }) async {
    final id = _normalize(word);
    await init();
    final hasDictionaryEntry = _byId.containsKey(id);
    final hasRelatedEntry = _relatedToId.containsKey(id);
    final hasOverrideEntry = _trOverrides?[id]?.isNotEmpty == true;
    final hasInflectedEntry = _entryForInflectedForm(id) != null;
    final entry = await getOrFallback(id);
    if (!hasDictionaryEntry &&
        !hasRelatedEntry &&
        !hasOverrideEntry &&
        !hasInflectedEntry &&
        acceptedInGame) {
      debugPrint(
          '[dictionary_miss] playable word not in dictionary: $word -> $id');
    }
    return DictionaryMeaningResult(
      query: word,
      normalized: id,
      entry: entry,
      acceptedInGame: acceptedInGame,
    );
  }

  Future<List<FerhengEntry>> searchPrefix(String prefix,
      {int limit = 20}) async {
    await init();
    final p = _normalize(prefix);
    if (p.isEmpty) return const [];
    final indexKey = p.length > 4 ? p.substring(0, 4) : p;
    final candidates = _byPrefix[indexKey] ?? const [];
    final out = <FerhengEntry>[];
    for (final id in candidates) {
      if (p.length <= 4 || id.startsWith(p)) {
        final e = _byId[id];
        if (e != null) {
          out.add(e);
          if (out.length >= limit) break;
        }
      }
    }
    return out;
  }

  Future<List<FerhengEntry>> search(String query, {int limit = 20}) async {
    await init();
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final out = <FerhengEntry>[];
    final seen = <String>{};

    void add(FerhengEntry? entry) {
      if (entry == null || seen.contains(entry.normalized)) return;
      out.add(entry);
      seen.add(entry.normalized);
    }

    final exact = await getOrFallback(q);
    if (exact != null) {
      add(exact);
    } else if (await isPlayableWord(q)) {
      add(_playableOnlyEntry(q));
    }

    final prefixMatches = await searchPrefix(q, limit: limit);
    for (final entry in prefixMatches) {
      add(entry);
      if (out.length >= limit) return out;
    }

    for (final id in _sortedIds) {
      if (out.length >= limit) break;
      if (!id.contains(q)) continue;
      add(_byId[id]);
    }

    return out;
  }

  Future<bool> isPlayableWord(String word) async {
    final id = _normalize(word);
    if (id.isEmpty) return false;
    final words = await _loadPlayableWords();
    return words.contains(id);
  }

  Future<Set<String>> _loadPlayableWords() async {
    final cached = _playableWords;
    if (cached != null) return cached;
    final inFlight = _playableWordsFuture;
    if (inFlight != null) return inFlight;

    final future = WordlistLoader.loadAssets(LanguageConfig.kurdish.wordAssets)
        .then((words) =>
            words.map(_normalize).where((w) => w.isNotEmpty).toSet());
    _playableWordsFuture = future;
    try {
      _playableWords = await future;
      return _playableWords!;
    } finally {
      _playableWordsFuture = null;
    }
  }

  FerhengEntry _playableOnlyEntry(String word) {
    final id = _normalize(word);
    return FerhengEntry(
      headword: id,
      normalized: id,
      source: 'playable-wordlist',
      isPlayable: true,
    );
  }

  FerhengEntry? _entryForRelatedForm(String word) {
    final id = _normalize(word);
    final baseId = _relatedToId[id];
    if (baseId == null) return null;
    final base = _byId[baseId];
    if (base == null) return null;
    final overrideTr = _trOverrides?[base.normalized] ?? _trOverrides?[id];
    if (overrideTr != null &&
        overrideTr.isNotEmpty &&
        base.definitionsTr.isEmpty) {
      return _entryWithTurkishOverride(base, id, base.normalized, overrideTr)
          .asRelatedLookup(id);
    }
    return base.asRelatedLookup(id);
  }

  FerhengEntry? _entryForInflectedForm(String word) {
    final id = _normalize(word);
    for (final baseId in _inflectionBaseCandidates(id)) {
      final base = _byId[baseId];
      final overrideTr = _trOverrides?[baseId] ?? _legacy?[baseId];
      if (base != null) {
        if (overrideTr != null &&
            overrideTr.isNotEmpty &&
            base.definitionsTr.isEmpty) {
          return _entryWithTurkishOverride(
                  base, baseId, base.normalized, overrideTr)
              .asRelatedLookup(id);
        }
        if (base.hasAnyDefinition) return base.asRelatedLookup(id);
      }
      if (overrideTr != null && overrideTr.isNotEmpty) {
        return _entryWithTurkishOverride(null, baseId, baseId, overrideTr)
            .asRelatedLookup(id);
      }
    }
    return null;
  }

  Iterable<String> _inflectionBaseCandidates(String id) sync* {
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
      'INAN',
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
    final seen = <String>{};
    for (final suffix in suffixes) {
      if (!id.endsWith(suffix) || id.length <= suffix.length + 2) continue;
      final candidate = id.substring(0, id.length - suffix.length);
      if (seen.add(candidate)) yield candidate;
    }
  }

  FerhengEntry _entryWithTurkishOverride(
    FerhengEntry? entry,
    String word,
    String id,
    String trGloss,
  ) {
    return FerhengEntry(
      headword: entry?.headword ?? word,
      normalized: id,
      prefixes: entry?.prefixes ?? const [],
      dialect: entry?.dialect ?? 'kmr',
      pos: entry?.pos ?? const [],
      ipa: entry?.ipa ?? '',
      definitionsKmr: entry?.definitionsKmr ?? const [],
      definitionsTr: [FerhengDefinition(gloss: trGloss)],
      etymology: entry?.etymology ?? '',
      categories: entry?.categories ?? const [],
      related: entry?.related ?? const [],
      audioUrl: entry?.audioUrl,
      source: entry == null ? 'tr_override' : '${entry.source}+tr_override',
      sourceUrl: entry?.sourceUrl ?? '',
      license: entry?.license ?? 'CC BY-SA 4.0 + project-curated',
      version: entry?.version ?? 1,
      isPlayable: entry?.isPlayable ?? true,
    );
  }

  Future<List<FerhengEntry>> byLetter(String letter, {int limit = 50}) async {
    await init();
    final letterUp = _normalize(letter);
    final ids = _byPrefix[letterUp] ?? const [];
    return ids
        .take(limit)
        .map((id) => _byId[id])
        .whereType<FerhengEntry>()
        .toList(growable: false);
  }

  Future<List<FerhengEntry>> byCategory(String categoryId,
      {int limit = 50}) async {
    await init();
    final ids = _byCategory[categoryId] ?? const [];
    return ids
        .take(limit)
        .map((id) => _byId[id])
        .whereType<FerhengEntry>()
        .toList(growable: false);
  }

  // ── Word of the Day ─────────────────────────────────────────────

  Future<FerhengEntry?> getWordOfTheDay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final dayIndex = DateTime.utc(today.year, today.month, today.day)
            .millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    // Pool: legacy 318 (curated, anlamlı) > bundle headwords
    final pool = _legacy?.keys.toList(growable: false) ?? const <String>[];
    if (pool.isNotEmpty) {
      final id = pool[dayIndex.abs() % pool.length];
      return getOrFallback(id);
    }
    if (_sortedIds.isNotEmpty) {
      final id = _sortedIds[dayIndex.abs() % _sortedIds.length];
      return getEntry(id);
    }
    return null;
  }

  Future<List<FerhengEntry>> getRandomForFlashcard({int count = 10}) async {
    final pool = _legacy?.keys.toList() ?? <String>[];
    if (pool.isEmpty) return const [];
    pool.shuffle();
    final selected = pool.take(count).toList();
    final results = <FerhengEntry>[];
    for (final id in selected) {
      final e = await getOrFallback(id);
      if (e != null) results.add(e);
    }
    return results;
  }

  // ── Recent searches ─────────────────────────────────────────────

  Future<List<String>> recentSearches() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_prefRecentSearchesKey) ?? const [];
  }

  Future<void> recordSearch(String word) async {
    final id = _normalize(word);
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_prefRecentSearchesKey) ?? <String>[];
    list.remove(id);
    list.insert(0, id);
    if (list.length > _maxRecentSearches) {
      list.removeRange(_maxRecentSearches, list.length);
    }
    await p.setStringList(_prefRecentSearchesKey, list);
  }

  Future<void> clearRecentSearches() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefRecentSearchesKey);
  }

  // ── Favorites (Firestore-backed) ────────────────────────────────

  Future<List<String>> listFavoriteIds(String uid) =>
      _repo.listFavoriteIds(uid);
  Future<void> addFavorite(String uid, String word) =>
      _repo.addFavorite(uid, _normalize(word));
  Future<void> removeFavorite(String uid, String word) =>
      _repo.removeFavorite(uid, _normalize(word));

  // ── Categories ──────────────────────────────────────────────────

  List<Map<String, String>> categories() => _categories ?? const [];

  // ── Meta ────────────────────────────────────────────────────────

  FerhengMeta? get meta => _meta;
  bool get ferhengEnabled => _meta?.ferhengEnabled ?? true;
  int get totalEntries => _byId.length;

  Future<void> clearCache() async {
    // Bundle her start'ta yüklenir; cache yok. Sadece recent searches'i sil.
    await clearRecentSearches();
  }
}

class DictionaryMeaningResult {
  final String query;
  final String normalized;
  final FerhengEntry? entry;
  final bool acceptedInGame;

  const DictionaryMeaningResult({
    required this.query,
    required this.normalized,
    required this.entry,
    this.acceptedInGame = false,
  });

  bool get found => entry != null;
  String get displayWord =>
      entry?.headword.isNotEmpty == true ? entry!.headword : normalized;

  String displayMeaning(AppLocale locale) {
    final e = entry;
    if (e == null) return L.dictionaryWordNotFound;
    return e.displayMeaning(locale);
  }

  String displayGameMeaning() {
    final e = entry;
    if (e == null) {
      return acceptedInGame
          ? L.playableWordMissingMeaning
          : L.dictionaryWordNotFound;
    }

    final tr =
        e.definitionsTr.isNotEmpty ? e.definitionsTr.first.gloss.trim() : '';
    final kmr =
        e.definitionsKmr.isNotEmpty ? e.definitionsKmr.first.gloss.trim() : '';
    if (tr.isEmpty && kmr.isEmpty) {
      return e.source == 'playable-wordlist'
          ? L.playableWordMissingMeaning
          : L.dictionaryEntryMissingMeaning;
    }

    final lines = <String>[];
    if (tr.isNotEmpty) {
      lines.add('Türkçe: $tr');
    } else {
      lines.add(L.missingTurkishMeaning);
    }
    if (kmr.isNotEmpty) {
      lines.add('Kürtçe: $kmr');
    }
    return lines.join('\n');
  }
}

extension _RelatedLookupEntry on FerhengEntry {
  FerhengEntry asRelatedLookup(String surfaceForm) {
    final form = WordNormalizer.normalize(surfaceForm);
    if (form.isEmpty || form == normalized) return this;
    return FerhengEntry(
      headword: form,
      normalized: form,
      prefixes: prefixes,
      dialect: dialect,
      pos: pos,
      ipa: ipa,
      definitionsKmr: definitionsKmr,
      definitionsTr: definitionsTr,
      etymology: etymology,
      categories: categories,
      related: [normalized, ...related],
      audioUrl: audioUrl,
      source: '$source+related:$normalized',
      sourceUrl: sourceUrl,
      license: license,
      version: version,
      isPlayable: isPlayable,
    );
  }
}

/// Top-level (compute() requirement). Gzip decompress + NDJSON parse + index.
_ParsedBundle _parseEntriesBundle(Uint8List bytes) {
  final decoded = GZipDecoder().decodeBytes(bytes);
  final text = utf8.decode(decoded, allowMalformed: false);

  final byId = <String, FerhengEntry>{};
  final byPrefix = <String, List<String>>{};
  final byCategory = <String, List<String>>{};
  final relatedToId = <String, String>{};

  for (final line in const LineSplitter().convert(text)) {
    if (line.isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final entry = FerhengEntry.fromJson(map);
    final id = WordNormalizer.normalize(entry.normalized);
    if (id.isEmpty) continue;
    byId[id] = entry;
    for (final p in entry.prefixes) {
      (byPrefix[p] ??= <String>[]).add(id);
    }
    for (final c in entry.categories) {
      (byCategory[c] ??= <String>[]).add(id);
    }
    for (final related in entry.related) {
      final relatedId = WordNormalizer.normalize(related);
      if (relatedId.isEmpty || relatedId == id || byId.containsKey(relatedId)) {
        continue;
      }
      relatedToId.putIfAbsent(relatedId, () => id);
    }
  }

  final sortedIds = byId.keys.toList()..sort();
  // Prefix listelerini de sırala (alfabetik gezinme).
  for (final list in byPrefix.values) {
    list.sort();
  }
  for (final list in byCategory.values) {
    list.sort();
  }

  return _ParsedBundle(
    byId: byId,
    byPrefix: byPrefix,
    byCategory: byCategory,
    relatedToId: relatedToId,
    sortedIds: sortedIds,
  );
}

class _ParsedBundle {
  final Map<String, FerhengEntry> byId;
  final Map<String, List<String>> byPrefix;
  final Map<String, List<String>> byCategory;
  final Map<String, String> relatedToId;
  final List<String> sortedIds;
  const _ParsedBundle({
    required this.byId,
    required this.byPrefix,
    required this.byCategory,
    required this.relatedToId,
    required this.sortedIds,
  });
}

/// fire-and-forget yardımcısı.
void unawaited(Future<void> _) {}
