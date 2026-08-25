import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_repository.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/logging_service.dart';
import 'package:kurdle_app/services/word_normalizer.dart';
import 'package:kurdle_app/services/wordlist_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bundled (offline) ferheng servisi.
///
/// Tüm 196k+ entry uygulama açılışında `assets/ferheng/entries.ndjson.gz`'den
/// in-memory'e yüklenir (compute() isolate'inde). Lookup'lar O(1) Map.
/// Firestore artık yalnızca favoriler + meta için kullanılır.
class FerhengService {
  FerhengService._({FerhengRepository? repo}) : _repo = repo;

  static FerhengService? _instance;
  static FerhengService get instance => _instance ??= FerhengService._();

  static const String _entriesAsset = 'assets/ferheng/entries.ndjson.gz';
  static const String _legacyAsset = 'assets/ferheng/legacy_meanings.json';
  static const String _trOverridesAsset =
      'assets/ferheng/tr_meaning_overrides.json.gz';
  static const String _categoriesAsset = 'assets/ferheng/categories.json';

  static const String _prefRecentSearchesKey = 'ferheng_recent_searches';
  static const int _maxRecentSearches = 20;
  static const Map<String, List<String>> _coreTurkishLookup = {
    'GEL': ['HATIN'],
    'GELME': ['HATIN'],
    'GELMEK': ['HATIN'],
    'GIT': ['ÇÛN'],
    'GITME': ['ÇÛN'],
    'GITMEK': ['ÇÛN'],
    'SU': ['AV'],
    'COCUK': ['ZAROK'],
    'EV': ['MAL'],
    'YEMEK': ['XWARIN'],
    'IC': ['VEXWARIN'],
    'ICME': ['VEXWARIN'],
    'ICMEK': ['VEXWARIN'],
    'GORMEK': ['DÎTIN'],
    'GOR': ['DÎTIN'],
    'BULMAK': ['DÎTIN'],
    'DEMEK': ['GOTIN'],
    'SOYLEMEK': ['GOTIN'],
    'YAPMAK': ['KIRIN'],
    'ETMEK': ['KIRIN'],
  };

  FerhengRepository? _repo;
  FerhengRepository get _repository => _repo ??= FerhengRepository();

  // In-memory veri
  Map<String, FerhengEntry> _byId = const {};
  Map<String, FerhengEntry> _bySurface = const {};
  Map<String, List<String>> _byPrefix = const {}; // 1-4 char prefix → ids
  Map<String, List<String>> _byTurkishPrefix =
      const {}; // Türkçe anlam prefix → ids
  Map<String, List<String>> _byCategory = const {}; // category id → ids
  final Map<String, List<FerhengEntry>> _categoryCache = {};
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
    try {
      final data = await rootBundle.load(_entriesAsset);
      final bytes = data.buffer.asUint8List();
      final result = await compute(_parseEntriesBundle, bytes);
      _byId = result.byId;
      _bySurface = result.bySurface;
      _byPrefix = result.byPrefix;
      _byTurkishPrefix = result.byTurkishPrefix;
      _byCategory = result.byCategory;
      _categoryCache.clear();
      _relatedToId = result.relatedToId;
      _sortedIds = result.sortedIds;
      _mergeTurkishOverrideIndex();
    } catch (e) {
      Log.warn('FerhengService', 'entries bundle load failed', e);
      _byId = const {};
      _bySurface = const {};
      _byPrefix = const {};
      _byTurkishPrefix = const {};
      _byCategory = const {};
      _categoryCache.clear();
      _relatedToId = const {};
      _sortedIds = const [];
    }
  }

  /// Kategori ekranlarını arka planda hazırlar.
  ///
  /// Uygulama açılışında bekletmeden çağrılır; kullanıcı Ferheng kategorilerine
  /// girdiğinde filtrelenmiş listeler bellekte hazır bekler.
  Future<void> warmUpCategories() async {
    await init();
    for (final category in _categories ?? const <Map<String, String>>[]) {
      final id = category['id'];
      if (id == null || id.isEmpty) continue;
      _categoryEntries(id);
    }
  }

  Future<void> _loadLegacyBundle() async {
    try {
      final raw = await rootBundle.loadString(_legacyAsset);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final entries = (decoded['entries'] as Map<String, dynamic>? ?? const {});
      _legacy = entries.map(
        (k, v) => MapEntry(k, ((v as Map)['tr'] ?? '').toString()),
      );
    } catch (e) {
      Log.warn('FerhengService', 'legacy bundle load failed', e);
      _legacy = const {};
    }
  }

  Future<void> _loadTrOverridesBundle() async {
    try {
      // 35MB JSON → ~1.9MB gzipped. APK boyutu için kritik.
      final data = await rootBundle.load(_trOverridesAsset);
      final bytes = data.buffer.asUint8List();
      final decoded = GZipDecoder().decodeBytes(bytes);
      final raw = utf8.decode(decoded);
      final parsed = json.decode(raw) as Map<String, dynamic>;
      final entries = (parsed['entries'] as Map<String, dynamic>? ?? const {});
      _trOverrides = entries.map((k, v) {
        final value = v is Map ? (v['tr'] ?? '').toString() : v.toString();
        return MapEntry(_normalize(k), value.trim());
      })
        ..removeWhere((_, v) => v.isEmpty);
    } catch (e) {
      Log.warn('FerhengService', 'TR overrides bundle load failed', e);
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
    } catch (e) {
      Log.warn('FerhengService', 'categories bundle load failed', e);
      _categories = const [];
    }
  }

  Future<void> _refreshMeta() async {
    if (!FirebaseService.isAvailable) return;
    try {
      _meta = await _repository.meta();
    } catch (e) {
      Log.warn('FerhengService', 'meta refresh failed (offline?)', e);
    }
  }

  // ── Lookup ──────────────────────────────────────────────────────

  String _normalize(String word) => WordNormalizer.normalize(word);

  Iterable<String> _surfaceLookupKeys(String word) sync* {
    final raw = word.trim();
    if (raw.isEmpty) return;
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ');
    final seen = <String>{};
    for (final key in [
      raw,
      collapsed,
      raw.toUpperCase(),
      collapsed.toUpperCase(),
    ]) {
      if (key.isNotEmpty && seen.add(key)) yield key;
    }
  }

  FerhengEntry? _entryForSurfaceForm(String word) {
    for (final key in _surfaceLookupKeys(word)) {
      final entry = _bySurface[key];
      if (entry != null) return entry.asRelatedLookup(word);
    }
    return null;
  }

  Future<FerhengEntry?> getEntry(String word) async {
    await init();
    final id = _normalize(word);
    return _entryForSurfaceForm(word) ??
        _byId[id] ??
        _entryForRelatedForm(id) ??
        _entryForInflectedForm(id);
  }

  /// `getEntry` + legacy TR fallback. Bundle'da tüm entry'ler var olduğundan
  /// fallback nadiren gerekir; legacy 318 entry curated TR sağlar.
  Future<FerhengEntry?> getOrFallback(String word) async {
    await init();
    final id = _normalize(word);
    final entry = _entryForSurfaceForm(word) ?? _byId[id];
    final relatedEntry = entry == null ? _entryForRelatedForm(id) : null;
    if (relatedEntry != null) return relatedEntry;
    final overrideTr = _trOverrides?[id] ?? _trOverrides?[entry?.normalized];
    if (overrideTr != null &&
        overrideTr.isNotEmpty &&
        (entry == null || entry.definitionsTr.isEmpty)) {
      return _entryWithTurkishOverride(entry, word, id, overrideTr);
    }
    if (entry != null && entry.definitionsTr.isEmpty) {
      final inheritedTr = _turkishGlossForInflectedBase(id);
      if (inheritedTr != null && inheritedTr.isNotEmpty) {
        return _entryWithTurkishOverride(entry, word, id, inheritedTr);
      }
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
    final hasSurfaceEntry = _entryForSurfaceForm(word) != null;
    final hasRelatedEntry = _relatedToId.containsKey(id);
    final hasOverrideEntry = _trOverrides?[id]?.isNotEmpty == true;
    final hasInflectedEntry = _entryForInflectedForm(id) != null;
    final entry = await getOrFallback(word);
    if (!hasDictionaryEntry &&
        !hasSurfaceEntry &&
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

    for (final id in _coreTurkishLookup[_normalizeTurkishSearch(query)] ??
        const <String>[]) {
      add(await getOrFallback(id));
      if (out.length >= limit) return out;
    }

    final trMatches = await _searchTurkishMeanings(query, limit: limit);
    for (final entry in trMatches) {
      add(entry);
      if (out.length >= limit) return out;
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

  Future<List<FerhengEntry>> _searchTurkishMeanings(String query,
      {int limit = 20}) async {
    final q = _normalizeTurkishSearch(query);
    if (q.isEmpty) return const [];
    final indexKey = q.length > 4 ? q.substring(0, 4) : q;
    final candidates = _byTurkishPrefix[indexKey] ?? const [];
    if (candidates.isEmpty) return const [];

    final scored = <_TurkishSearchMatch>[];
    final bestScores = <String, int>{};
    for (final id in candidates) {
      final score = _turkishSearchScore(id, q);
      if (score == null) continue;
      final best = bestScores[id];
      if (best == null || score < best) {
        bestScores[id] = score;
      }
    }
    for (final item in bestScores.entries) {
      scored.add(_TurkishSearchMatch(id: item.key, score: item.value));
    }
    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      return a.id.compareTo(b.id);
    });

    final out = <FerhengEntry>[];
    for (final match in scored.take(limit)) {
      final entry = await getOrFallback(match.id);
      if (entry != null) out.add(entry);
    }
    return out;
  }

  int? _turkishSearchScore(String id, String query) {
    int? best;

    void consider(String text) {
      final score = _turkishTextScore(text, query);
      if (score == null) return;
      if (best == null || score < best!) best = score;
    }

    final entry = _byId[id];
    if (entry != null) {
      for (final def in entry.definitionsTr) {
        consider(def.gloss);
        for (final example in def.examples) {
          consider(example.translation);
        }
      }
    }
    final override = _trOverrides?[id];
    if (override != null) consider(override);
    return best;
  }

  void _mergeTurkishOverrideIndex() {
    final overrides = _trOverrides;
    if (overrides == null || overrides.isEmpty) return;
    final merged = <String, List<String>>{
      for (final item in _byTurkishPrefix.entries)
        item.key: List<String>.from(item.value),
    };
    for (final item in overrides.entries) {
      if (!_byId.containsKey(item.key) || item.value.trim().isEmpty) continue;
      _indexTurkishText(merged, item.key, item.value);
    }
    for (final ids in merged.values) {
      ids.sort();
    }
    _byTurkishPrefix = merged;
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

  String? _turkishGlossForInflectedBase(String word) {
    final id = _normalize(word);
    for (final baseId in _inflectionBaseCandidates(id)) {
      final overrideTr = _trOverrides?[baseId] ?? _legacy?[baseId];
      if (overrideTr != null && overrideTr.isNotEmpty) return overrideTr;
      final base = _byId[baseId];
      if (base != null && base.definitionsTr.isNotEmpty) {
        return base.definitionsTr.first.gloss;
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
    final seen = <String>{};
    const replacements = <({String suffix, String replacement})>[
      (suffix: 'IBÛNAN', replacement: 'IN'),
      (suffix: 'IBÛNE', replacement: 'IN'),
      (suffix: 'IBÛN', replacement: 'IN'),
      (suffix: 'ÎBÛNAN', replacement: 'ÎN'),
      (suffix: 'ÎBÛNE', replacement: 'ÎN'),
      (suffix: 'ÎBÛN', replacement: 'ÎN'),
    ];
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

  Future<List<FerhengEntry>> byCategory(String categoryId, {int? limit}) async {
    await init();
    final entries = _categoryEntries(categoryId);
    if (limit == null || entries.length <= limit) return entries;
    return entries.take(limit).toList(growable: false);
  }

  List<FerhengEntry> _categoryEntries(String categoryId) {
    final cached = _categoryCache[categoryId];
    if (cached != null) return cached;
    final ids = _byCategory[categoryId] ?? const [];
    final entries = ids
        .map((id) => _byId[id])
        .whereType<FerhengEntry>()
        .where((entry) => _isRelevantForCategory(entry, categoryId))
        .toList(growable: false);
    _categoryCache[categoryId] = entries;
    return entries;
  }

  static bool _isRelevantForCategory(FerhengEntry entry, String categoryId) {
    if (!_isCategoryBrowsableEntry(entry)) return false;
    final keywords = _categoryKeywords[categoryId];
    if (keywords == null || keywords.isEmpty) return true;
    final text = _categorySearchText(entry);
    return keywords.any((keyword) => _containsCategoryKeyword(text, keyword));
  }

  static bool _isCategoryBrowsableEntry(FerhengEntry entry) {
    final word = entry.headword.trim();
    if (word.length < 2 || word.startsWith('-')) return false;
    final pos = entry.pos.map((p) => p.toLowerCase()).toList(growable: false);
    if (pos.any((p) => p.contains('paşgir') || p.contains('character'))) {
      return false;
    }
    if (pos.any((p) =>
        p.contains('biwêj') ||
        p.contains('gotineke pêşiyan') ||
        p.contains('çavkanî'))) {
      return false;
    }
    return true;
  }

  static String _categorySearchText(FerhengEntry entry) {
    final parts = <String>[
      entry.headword,
      entry.normalized,
      ...entry.pos,
      ...entry.definitionsKmr.map((d) => d.gloss),
      ...entry.definitionsTr.map((d) => d.gloss),
    ];
    final raw = parts.join(' ').toLowerCase();
    return raw.replaceAll(RegExp(r"[^a-zçğıöşüêîûûḧ'’0-9]+"), ' ');
  }

  static bool _containsCategoryKeyword(String text, String keyword) {
    final key = keyword.toLowerCase();
    if (key.length <= 3 && !key.contains(' ')) {
      return ' $text '.contains(' $key ');
    }
    return text.contains(key);
  }

  static const Map<String, List<String>> _categoryKeywords = {
    'animals': [
      'animal',
      'hayvan',
      'canlı',
      'yaratık',
      'mahluk',
      'böcek',
      'kuş',
      'balık',
      'yılan',
      'kedi',
      'köpek',
      'at',
      'eşek',
      'inek',
      'koyun',
      'keçi',
      'kurt',
      'aslan',
      'kaplan',
      'fare',
      'tavuk',
      'horoz',
      'ördek',
      'kaz',
      'arı',
      'karınca',
      'sinek',
      'fil',
      'geyik',
      'ceylan',
      'fildişi',
      'yalak',
      'yemlik',
      'ahır',
      'hayvancılık',
      'zooloji',
      'heywan',
      'ajal',
      'ajel',
      'dewar',
      'lawir',
      'balinde',
      'masî',
      'mar',
      'pisîk',
      'kûçik',
      'seg',
      'hesp',
      'ker',
      'ga',
      'pez',
      'mih',
      'bizin',
      'gur',
      'şêr',
      'piling',
      'mişk',
      'mirîşk',
      'mêş',
      'morî',
      'fîl',
      'ahû',
    ],
    'body': [
      'vücut',
      'beden',
      'organ',
      'baş',
      'kafa',
      'yüz',
      'göz',
      'kulak',
      'burun',
      'ağız',
      'diş',
      'dil',
      'el',
      'kol',
      'ayak',
      'bacak',
      'parmak',
      'kalp',
      'ciğer',
      'kan',
      'kemik',
      'deri',
      'saç',
      'sakal',
      'boyun',
      'omuz',
      'karın',
      'laş',
      'beden',
      'ser',
      'rû',
      'çav',
      'guh',
      'poz',
      'dev',
      'diran',
      'ziman',
      'dest',
      'ling',
      'tilî',
      'dil',
      'xwîn',
      'hestî',
      'por',
      'gerden',
    ],
    'family': [
      'aile',
      'akraba',
      'anne',
      'ana',
      'baba',
      'kardeş',
      'abla',
      'ağabey',
      'abi',
      'kız',
      'oğul',
      'çocuk',
      'eş',
      'koca',
      'karı',
      'dede',
      'nine',
      'torun',
      'amca',
      'dayı',
      'hala',
      'teyze',
      'kuzen',
      'malbat',
      'dayik',
      'bav',
      'xwişk',
      'bira',
      'kur',
      'keç',
      'zarok',
      'jin',
      'mêr',
      'dapîr',
      'bapîr',
      'mam',
      'met',
      'xal',
    ],
    'food': [
      'yemek',
      'yiyecek',
      'içecek',
      'gıda',
      'besin',
      'ekmek',
      'su',
      'süt',
      'peynir',
      'yoğurt',
      'et',
      'bal',
      'tuz',
      'şeker',
      'çay',
      'kahve',
      'meyve',
      'sebze',
      'elma',
      'üzüm',
      'arpa',
      'buğday',
      'mercimek',
      'xwarin',
      'vexwarin',
      'nan',
      'av',
      'şîr',
      'mast',
      'goşt',
      'hingiv',
      'xwê',
      'şekir',
      'çay',
      'qehwe',
      'fêkî',
      'sebze',
      'sêv',
      'tirî',
      'genim',
      'nîsk',
    ],
    'nature': [
      'doğa',
      'tabiat',
      'dağ',
      'orman',
      'ağaç',
      'çiçek',
      'bitki',
      'ot',
      'deniz',
      'okyanus',
      'göl',
      'nehir',
      'ırmak',
      'su',
      'taş',
      'toprak',
      'güneş',
      'ay',
      'yıldız',
      'rüzgar',
      'yağmur',
      'kar',
      'hava',
      'xweza',
      'çiya',
      'dar',
      'gul',
      'riwek',
      'giya',
      'behr',
      'derya',
      'gol',
      'çem',
      'av',
      'kevir',
      'erd',
      'roj',
      'heyv',
      'stêr',
      'ba',
      'baran',
      'berf',
      'hewa',
    ],
    'time': [
      'zaman',
      'vakit',
      'saat',
      'gün',
      'hafta',
      'ay',
      'yıl',
      'sabah',
      'öğle',
      'akşam',
      'gece',
      'dün',
      'bugün',
      'yarın',
      'şimdi',
      'sonra',
      'önce',
      'dem',
      'wext',
      'saet',
      'roj',
      'hefte',
      'meh',
      'sal',
      'sibê',
      'nîvro',
      'êvar',
      'şev',
      'do',
      'îro',
      'sibe',
      'niha',
      'paşê',
      'berê',
    ],
    'numbers': [
      'sayı',
      'rakam',
      'bir',
      'iki',
      'üç',
      'dört',
      'beş',
      'altı',
      'yedi',
      'sekiz',
      'dokuz',
      'on',
      'yüz',
      'bin',
      'milyon',
      'hejmar',
      'yek',
      'du',
      'sê',
      'çar',
      'pênc',
      'şeş',
      'heft',
      'heşt',
      'neh',
      'deh',
      'sed',
      'hezar',
      'milyon',
    ],
    'colors': [
      'renk',
      'siyah',
      'beyaz',
      'kırmızı',
      'yeşil',
      'mavi',
      'sarı',
      'mor',
      'pembe',
      'turuncu',
      'kahverengi',
      'gri',
      'reng',
      'reş',
      'spî',
      'sor',
      'kesk',
      'şîn',
      'zer',
      'mor',
      'pembe',
      'porteqalî',
      'qehweyî',
      'gewir',
    ],
    'clothing': [
      'giyim',
      'giysi',
      'elbise',
      'kıyafet',
      'gömlek',
      'pantolon',
      'etek',
      'ceket',
      'ayakkabı',
      'çorap',
      'şapka',
      'kemer',
      'yüzük',
      'cil',
      'berg',
      'kiras',
      'pantalon',
      'kirasik',
      'sol',
      'gore',
      'kumik',
      'şapka',
      'qayîş',
      'gustîl',
    ],
    'home': [
      'ev',
      'oda',
      'hane',
      'bina',
      'duvar',
      'kapı',
      'pencere',
      'mutfak',
      'banyo',
      'yatak',
      'masa',
      'sandalye',
      'lamba',
      'ocak',
      'tava',
      'adres',
      'mal',
      'ode',
      'xanî',
      'xane',
      'dîwar',
      'derî',
      'pace',
      'metbex',
      'serşok',
      'nivîn',
      'mase',
      'kursî',
      'lemba',
      'sobe',
      'aftawe',
    ],
    'places': [
      'yer',
      'mekan',
      'şehir',
      'ülke',
      'köy',
      'kasaba',
      'sokak',
      'cadde',
      'dağ',
      'ova',
      'okul',
      'hastane',
      'pazar',
      'cami',
      'kilise',
      'adres',
      'cîh',
      'cih',
      'bajar',
      'welat',
      'gund',
      'kolan',
      'çiya',
      'deşt',
      'dibistan',
      'nexweşxane',
      'bazar',
      'mizgeft',
      'dêr',
    ],
    'emotions': [
      'duygu',
      'his',
      'sevinç',
      'mutlu',
      'üzüntü',
      'keder',
      'öfke',
      'kızgın',
      'korku',
      'endişe',
      'sevgi',
      'aşk',
      'nefret',
      'huzur',
      'sakin',
      'heyecan',
      'hest',
      'şad',
      'kêf',
      'xem',
      'hêrs',
      'tirs',
      'xof',
      'endîşe',
      'evîn',
      'hez',
      'nefret',
      'aram',
      'hêmin',
      'dilxweş',
    ],
    'professions': [
      'meslek',
      'işçi',
      'öğretmen',
      'doktor',
      'yazar',
      'şarkıcı',
      'müzisyen',
      'çiftçi',
      'çoban',
      'asker',
      'polis',
      'usta',
      'sanatçı',
      'pîşe',
      'karker',
      'mamoste',
      'bijîşk',
      'nivîskar',
      'stranbêj',
      'ahengbêj',
      'cotkar',
      'şivan',
      'leşker',
      'polîs',
      'hosta',
      'hunerkar',
    ],
    'religion_culture': [
      'din',
      'kültür',
      'ibadet',
      'tanrı',
      'allah',
      'xwedê',
      'yezdan',
      'cami',
      'kilise',
      'dua',
      'bayram',
      'gelenek',
      'töre',
      'ateşe tapan',
      'ol',
      'çand',
      'perestin',
      'îbadet',
      'xuda',
      'mizgeft',
      'dêr',
      'nimêj',
      'cejn',
      'adet',
      'kevneşop',
      'agirparêz',
    ],
  };

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
      FirebaseService.isAvailable
          ? _repository.listFavoriteIds(uid)
          : Future.value(const <String>[]);
  Future<void> addFavorite(String uid, String word) =>
      FirebaseService.isAvailable
          ? _repository.addFavorite(uid, _normalize(word))
          : Future.value();
  Future<void> removeFavorite(String uid, String word) =>
      FirebaseService.isAvailable
          ? _repository.removeFavorite(uid, _normalize(word))
          : Future.value();

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
  final bySurface = <String, FerhengEntry>{};
  final byPrefix = <String, List<String>>{};
  final byTurkishPrefix = <String, List<String>>{};
  final byCategory = <String, List<String>>{};
  final relatedToId = <String, String>{};

  for (final line in const LineSplitter().convert(text)) {
    if (line.isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final entry = FerhengEntry.fromJson(map);
    final id = WordNormalizer.normalize(entry.normalized);
    if (id.isEmpty) continue;
    byId[id] = entry;
    _indexSurfaceEntry(bySurface, entry, map);
    _indexTurkishEntry(byTurkishPrefix, id, entry);
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
  for (final list in byTurkishPrefix.values) {
    list.sort();
  }
  for (final list in byCategory.values) {
    list.sort();
  }

  return _ParsedBundle(
    byId: byId,
    bySurface: bySurface,
    byPrefix: byPrefix,
    byTurkishPrefix: byTurkishPrefix,
    byCategory: byCategory,
    relatedToId: relatedToId,
    sortedIds: sortedIds,
  );
}

void _indexSurfaceEntry(
  Map<String, FerhengEntry> bySurface,
  FerhengEntry entry,
  Map<String, dynamic> raw,
) {
  final seen = <String>{};
  for (final value in [
    raw['headword'],
    raw['word'],
    raw['normalized'],
    raw['normalizedWord'],
    entry.headword,
    entry.normalized,
  ]) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ');
    for (final key in [
      text,
      collapsed,
      text.toUpperCase(),
      collapsed.toUpperCase(),
    ]) {
      if (key.isNotEmpty && seen.add(key)) {
        bySurface.putIfAbsent(key, () => entry);
      }
    }
  }
}

void _indexTurkishEntry(
  Map<String, List<String>> byTurkishPrefix,
  String id,
  FerhengEntry entry,
) {
  for (final def in entry.definitionsTr) {
    _indexTurkishText(byTurkishPrefix, id, def.gloss);
    for (final example in def.examples) {
      _indexTurkishText(byTurkishPrefix, id, example.translation);
    }
  }
}

void _indexTurkishText(
  Map<String, List<String>> byTurkishPrefix,
  String id,
  String text,
) {
  final normalized = _normalizeTurkishSearch(text);
  if (normalized.isEmpty) return;
  final indexedTerms = <String>{normalized};
  indexedTerms.addAll(normalized.split(' ').where((part) => part.length >= 2));
  for (final term in indexedTerms) {
    final maxPrefix = term.length < 4 ? term.length : 4;
    for (var i = 1; i <= maxPrefix; i++) {
      final key = term.substring(0, i);
      final ids = byTurkishPrefix[key] ??= <String>[];
      if (ids.isEmpty || ids.last != id) ids.add(id);
    }
  }
}

String _normalizeTurkishSearch(String value) {
  final upper = value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  if (upper.isEmpty) return '';
  final buffer = StringBuffer();
  for (final codeUnit in upper.codeUnits) {
    final ch = String.fromCharCode(codeUnit);
    final mapped = switch (ch) {
      'Ç' => 'C',
      'Ğ' => 'G',
      'İ' => 'I',
      'I' => 'I',
      'Ö' => 'O',
      'Ş' => 'S',
      'Ü' => 'U',
      'Â' => 'A',
      'Î' => 'I',
      'Û' => 'U',
      _ => ch,
    };
    if (_isTurkishSearchChar(mapped)) {
      buffer.write(mapped);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isTurkishSearchChar(String value) {
  if (value.length != 1) return false;
  final code = value.codeUnitAt(0);
  return code == 32 || (code >= 48 && code <= 57) || (code >= 65 && code <= 90);
}

int? _turkishTextScore(String text, String query) {
  final normalized = _normalizeTurkishSearch(text);
  if (normalized.isEmpty) return null;
  final parts = normalized
      .split(RegExp(r'[,;:.!?()\[\]{}" ]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final phrases = normalized
      .split(RegExp(r'[,;:.!?()\[\]{}"]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.any((part) => part == query) ||
      phrases.any((phrase) => phrase == query)) {
    return 0;
  }
  if (phrases.any((phrase) => phrase.startsWith(query)) ||
      parts.any((part) => part.startsWith(query))) {
    return 1;
  }
  if (query.length >= 4 &&
      phrases.any((phrase) => phrase.split(' ').contains(query))) {
    return 2;
  }
  if (query.length >= 4 && normalized.contains(query)) {
    return 3;
  }
  return null;
}

class _TurkishSearchMatch {
  final String id;
  final int score;

  const _TurkishSearchMatch({required this.id, required this.score});
}

class _ParsedBundle {
  final Map<String, FerhengEntry> byId;
  final Map<String, FerhengEntry> bySurface;
  final Map<String, List<String>> byPrefix;
  final Map<String, List<String>> byTurkishPrefix;
  final Map<String, List<String>> byCategory;
  final Map<String, String> relatedToId;
  final List<String> sortedIds;
  const _ParsedBundle({
    required this.byId,
    required this.bySurface,
    required this.byPrefix,
    required this.byTurkishPrefix,
    required this.byCategory,
    required this.relatedToId,
    required this.sortedIds,
  });
}

/// fire-and-forget yardımcısı.
void unawaited(Future<void> _) {}
