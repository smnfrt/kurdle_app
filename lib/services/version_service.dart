import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/logging_service.dart';

enum VersionStatus { ok, updateAvailable, forceUpdate }

class VersionCheckResult {
  final VersionStatus status;
  final String currentVersion;
  final String? latestVersion;
  final String? updateMessage;

  const VersionCheckResult({
    required this.status,
    required this.currentVersion,
    this.latestVersion,
    this.updateMessage,
  });
}

class VersionService {
  VersionService._();
  static final VersionService instance = VersionService._();

  final _db = FirebaseFirestore.instance;

  // pubspec.yaml ile sync kalan, runtime'da bir kez okunan sürüm.
  // main() içinde loadVersion() bekleyince doldurulur; UI bundan okur.
  static String currentVersion = '';
  static String currentBuildNumber = '';

  Future<PackageInfo> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    currentVersion = info.version;
    currentBuildNumber = info.buildNumber;
    return info;
  }

  // Firestore'daki config/version dokümanıyla karşılaştırır.
  // Döküman yoksa veya Firebase kapalıysa VersionStatus.ok döner.
  Future<VersionCheckResult> checkVersion() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version; // "1.2.3"

    if (!FirebaseService.isAvailable) {
      return VersionCheckResult(status: VersionStatus.ok, currentVersion: current);
    }

    try {
      final snap = await _db.collection('config').doc('version').get();
      if (!snap.exists) {
        return VersionCheckResult(status: VersionStatus.ok, currentVersion: current);
      }

      final data = snap.data()!;
      final minVersion    = data['minVersion']    as String? ?? '0.0.0';
      final latestVersion = data['latestVersion'] as String? ?? current;
      final updateMessage = data['updateMessage'] as String?;

      if (_compareVersions(current, minVersion) < 0) {
        return VersionCheckResult(
          status: VersionStatus.forceUpdate,
          currentVersion: current,
          latestVersion: latestVersion,
          updateMessage: updateMessage ?? 'Uygulamayı güncellemen gerekiyor.',
        );
      }

      if (_compareVersions(current, latestVersion) < 0) {
        return VersionCheckResult(
          status: VersionStatus.updateAvailable,
          currentVersion: current,
          latestVersion: latestVersion,
          updateMessage: updateMessage,
        );
      }

      return VersionCheckResult(status: VersionStatus.ok, currentVersion: current);
    } catch (e) {
      Log.warn('VersionService', 'checkVersion failed', e);
      return VersionCheckResult(status: VersionStatus.ok, currentVersion: current);
    }
  }

  // Negatif: a < b, 0: eşit, pozitif: a > b
  static int _compareVersions(String a, String b) {
    final av = _parse(a);
    final bv = _parse(b);
    for (var i = 0; i < 3; i++) {
      final diff = av[i] - bv[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}
