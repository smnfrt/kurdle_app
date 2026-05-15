import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/word_normalizer.dart';

/// Saf Firestore katmanı — cache yok, fallback yok. `FerhengService` üstte oturur.
class FerhengRepository {
  static const String _entriesCollection = 'ferheng';
  static const String _metaCollection = 'ferheng_meta';
  static const String _favoritesSubcollection = 'ferhengFavorites';

  final FirebaseFirestore _db;

  FerhengRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Tek kelimeyi normalized id ile getirir.
  Future<FerhengEntry?> fetch(String normalizedId) async {
    final snap = await _db
        .collection(_entriesCollection)
        .doc(WordNormalizer.normalize(normalizedId))
        .get();
    final data = snap.data();
    if (data == null) return null;
    return FerhengEntry.fromJson(data);
  }

  /// Prefix bazlı arama. Plan §3'e göre prefixes alanı array-contains ile sorgulanır.
  /// Kullanıcının yazdığı prefix 4 karakterden uzunsa ilk 4 ile aranır (index sınırı).
  Future<List<FerhengEntry>> searchPrefix(
    String prefix, {
    String dialect = 'kmr',
    int limit = 20,
  }) async {
    final normalized = WordNormalizer.normalize(prefix);
    if (normalized.isEmpty) return const [];
    final p = normalized.length > 4 ? normalized.substring(0, 4) : normalized;
    final q = await _db
        .collection(_entriesCollection)
        .where('dialect', isEqualTo: dialect)
        .where('prefixes', arrayContains: p)
        .limit(limit)
        .get();
    final entries = q.docs.map((d) => FerhengEntry.fromJson(d.data())).toList();
    // Eğer kullanıcı 4'ten uzun yazdıysa client-side'da daha sıkı filtreyle daralt.
    if (normalized.length > 4) {
      return entries
          .where((e) => e.normalized.startsWith(normalized))
          .toList(growable: false);
    }
    return entries;
  }

  Future<List<FerhengEntry>> byCategory(
    String categoryId, {
    String dialect = 'kmr',
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(_entriesCollection)
        .where('dialect', isEqualTo: dialect)
        .where('categories', arrayContains: categoryId)
        .orderBy('normalized')
        .limit(limit);
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.get();
    return snap.docs.map((d) => FerhengEntry.fromJson(d.data())).toList();
  }

  Future<List<FerhengEntry>> byLetter(
    String letter, {
    String dialect = 'kmr',
    int limit = 50,
  }) async {
    final q = await _db
        .collection(_entriesCollection)
        .where('dialect', isEqualTo: dialect)
        .where('prefixes', arrayContains: WordNormalizer.normalize(letter))
        .orderBy('normalized')
        .limit(limit)
        .get();
    return q.docs.map((d) => FerhengEntry.fromJson(d.data())).toList();
  }

  Future<FerhengMeta?> meta({String dialect = 'kmr'}) async {
    final snap = await _db.collection(_metaCollection).doc(dialect).get();
    final data = snap.data();
    if (data == null) return null;
    return FerhengMeta.fromJson(data);
  }

  // ── Kullanıcı favorileri ────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _favCol(String uid) =>
      _db.collection('users').doc(uid).collection(_favoritesSubcollection);

  Future<List<String>> listFavoriteIds(String uid, {int limit = 200}) async {
    final snap = await _favCol(uid)
        .orderBy('addedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<void> addFavorite(String uid, String wordId) async {
    await _favCol(uid).doc(wordId).set({
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite(String uid, String wordId) async {
    await _favCol(uid).doc(wordId).delete();
  }
}
