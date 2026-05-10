import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/ferheng_repository.dart';
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
  static const String _categoriesAsset = 'assets/ferheng/categories.json';

  static const String _prefRecentSearchesKey = 'ferheng_recent_searches';
  static const int _maxRecentSearches = 20;

  final FerhengRepository _repo;

  // In-memory veri
  Map<String, FerhengEntry> _byId = const {};
  Map<String, List<String>> _byPrefix = const {}; // 1-4 char prefix → ids
  Map<String, List<String>> _byCategory = const {}; // category id → ids
  List<String> _sortedIds = const []; // alfabetik gezinme için

  Map<String, String>? _legacy;
  List<Map<String, String>>? _categories;
  FerhengMeta? _meta;
  bool _initialized = false;
  bool _initInProgress = false;

  /// Açılışta çağrılır. Idempotent.
  Future<void> init() async {
    if (_initialized || _initInProgress) return;
    _initInProgress = true;
    try {
      await _loadLegacyBundle();
      await _loadCategoriesBundle();
      await _loadEntriesBundle();
      // Meta best-effort — başarısızsa offline mod.
      unawaited(_refreshMeta());
      _initialized = true;
    } finally {
      _initInProgress = false;
    }
  }

  // ── Bundle yükleme ──────────────────────────────────────────────

  Future<void> _loadEntriesBundle() async {
    final data = await rootBundle.load(_entriesAsset);
    final bytes = data.buffer.asUint8List();
    final result = await compute(_parseEntriesBundle, bytes);
    _byId = result.byId;
    _byPrefix = result.byPrefix;
    _byCategory = result.byCategory;
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

  String _normalize(String word) => word.trim().toUpperCase();

  Future<FerhengEntry?> getEntry(String word) async {
    final id = _normalize(word);
    return _byId[id];
  }

  /// `getEntry` + legacy TR fallback. Bundle'da tüm entry'ler var olduğundan
  /// fallback nadiren gerekir; legacy 318 entry curated TR sağlar.
  Future<FerhengEntry?> getOrFallback(String word) async {
    final id = _normalize(word);
    final entry = _byId[id];
    if (entry != null && entry.hasAnyDefinition) return entry;
    final legacyTr = _legacy?[id];
    if (legacyTr != null && legacyTr.isNotEmpty) {
      // Legacy TR ile augmented entry üret.
      return FerhengEntry(
        headword: entry?.headword ?? word,
        normalized: id,
        pos: entry?.pos ?? const [],
        ipa: entry?.ipa ?? '',
        definitionsKmr: entry?.definitionsKmr ?? const [],
        definitionsTr: [FerhengDefinition(gloss: legacyTr)],
        related: entry?.related ?? const [],
        categories: entry?.categories ?? const [],
        source: 'legacy',
      );
    }
    return entry; // null veya tanımsız boş entry
  }

  Future<List<FerhengEntry>> searchPrefix(String prefix, {int limit = 20}) async {
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

  Future<List<FerhengEntry>> byLetter(String letter, {int limit = 50}) async {
    final letterUp = letter.toUpperCase();
    final ids = _byPrefix[letterUp] ?? const [];
    return ids
        .take(limit)
        .map((id) => _byId[id])
        .whereType<FerhengEntry>()
        .toList(growable: false);
  }

  Future<List<FerhengEntry>> byCategory(String categoryId, {int limit = 50}) async {
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

/// Top-level (compute() requirement). Gzip decompress + NDJSON parse + index.
_ParsedBundle _parseEntriesBundle(Uint8List bytes) {
  final decoded = GZipDecoder().decodeBytes(bytes);
  final text = utf8.decode(decoded, allowMalformed: false);

  final byId = <String, FerhengEntry>{};
  final byPrefix = <String, List<String>>{};
  final byCategory = <String, List<String>>{};

  for (final line in const LineSplitter().convert(text)) {
    if (line.isEmpty) continue;
    final map = json.decode(line) as Map<String, dynamic>;
    final entry = FerhengEntry.fromJson(map);
    final id = entry.normalized;
    if (id.isEmpty) continue;
    byId[id] = entry;
    for (final p in entry.prefixes) {
      (byPrefix[p] ??= <String>[]).add(id);
    }
    for (final c in entry.categories) {
      (byCategory[c] ??= <String>[]).add(id);
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
    sortedIds: sortedIds,
  );
}

class _ParsedBundle {
  final Map<String, FerhengEntry> byId;
  final Map<String, List<String>> byPrefix;
  final Map<String, List<String>> byCategory;
  final List<String> sortedIds;
  const _ParsedBundle({
    required this.byId,
    required this.byPrefix,
    required this.byCategory,
    required this.sortedIds,
  });
}

/// fire-and-forget yardımcısı.
void unawaited(Future<void> _) {}
