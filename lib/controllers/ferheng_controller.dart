import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_service.dart';

enum FerhengStatus { idle, loading, loaded, error }

/// Ferheng UI durumu — Provider/ChangeNotifier üzerinden tüketilir.
///
/// Sorumluluk:
///   - Search query debounce (250 ms)
///   - Aktif girdi (detail screen)
///   - Tanım dili tercihi (kmr ↔ tr)
///   - Recent searches snapshot
class FerhengController extends ChangeNotifier {
  FerhengController({FerhengService? service})
      : _service = service ?? FerhengService.instance;

  final FerhengService _service;

  static const Duration _searchDebounce = Duration(milliseconds: 250);

  FerhengStatus _status = FerhengStatus.idle;
  String _query = '';
  Timer? _debounce;

  List<FerhengEntry> _searchResults = const [];
  FerhengEntry? _currentEntry;
  AppLocale _definitionLanguage = AppLocale.tr;
  String? _errorMessage;

  // ── Getters ─────────────────────────────────────────────────────

  FerhengStatus get status => _status;
  String get query => _query;
  List<FerhengEntry> get searchResults => _searchResults;
  FerhengEntry? get currentEntry => _currentEntry;
  AppLocale get definitionLanguage => _definitionLanguage;
  String? get errorMessage => _errorMessage;
  bool get isSearching => _status == FerhengStatus.loading;

  // ── Search ──────────────────────────────────────────────────────

  void setQuery(String value) {
    _query = value;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _searchResults = const [];
      _status = FerhengStatus.idle;
      notifyListeners();
      return;
    }
    _status = FerhengStatus.loading;
    notifyListeners();
    _debounce = Timer(_searchDebounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await _service.search(query);
      // Yarış koşulu: kullanıcı sorguyu değiştirdiyse sonucu yutma.
      if (_query != query) return;
      _searchResults = results;
      _status = FerhengStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      if (_query != query) return;
      _searchResults = const [];
      _status = FerhengStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void clearSearch() {
    _debounce?.cancel();
    _query = '';
    _searchResults = const [];
    _status = FerhengStatus.idle;
    notifyListeners();
  }

  // ── Current entry (detail screen) ──────────────────────────────

  Future<void> openEntry(String word) async {
    _status = FerhengStatus.loading;
    _currentEntry = null;
    notifyListeners();
    try {
      final entry = await _service.getOrFallback(word);
      _currentEntry = entry;
      _status = entry == null ? FerhengStatus.error : FerhengStatus.loaded;
      _errorMessage = entry == null ? 'noDefinition' : null;
      // Kullanıcı bu kelimeyi gerçekten açtı — recent'e yaz.
      if (entry != null) {
        await _service.recordSearch(entry.normalized);
      }
    } catch (e) {
      _status = FerhengStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void closeEntry() {
    _currentEntry = null;
    _status = FerhengStatus.idle;
    notifyListeners();
  }

  // ── Language toggle ─────────────────────────────────────────────

  void setDefinitionLanguage(AppLocale lang) {
    if (_definitionLanguage == lang) return;
    _definitionLanguage = lang;
    notifyListeners();
  }

  // ── Recent searches ─────────────────────────────────────────────

  Future<List<String>> recentSearches() => _service.recentSearches();
  Future<void> clearRecentSearches() => _service.clearRecentSearches();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
