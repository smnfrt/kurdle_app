import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kurdle_app/services/logging_service.dart';

/// Cihazın ağ bağlantısını izleyen singleton.
///
/// `isOnline` sync flag; `onStatusChange` stream UI'ı reactive olarak günceller.
/// Bağlantı durumu sadece interface seviyesinde (WiFi / mobil / hiçbiri) —
/// "Firestore'a erişebiliyor muyum" ayrı bir katman. Çoğu offline UX için
/// bu seviye yeterli.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    try {
      final initial = await _conn.checkConnectivity();
      _isOnline = _hasNetwork(initial);
    } catch (e) {
      Log.warn('ConnectivityService', 'initial check failed', e);
      _isOnline = true; // fallback: optimist
    }

    _sub = _conn.onConnectivityChanged.listen(
      (results) {
        final online = _hasNetwork(results);
        if (online != _isOnline) {
          _isOnline = online;
          _controller.add(online);
        }
      },
      onError: (e) => Log.warn('ConnectivityService', 'stream error', e),
    );
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
