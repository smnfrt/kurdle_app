# Leyar Store Release Checklist

Bu kontrol listesi Android ve iOS yayını için son kapı olarak kullanılmalı.

## 1. Kod ve Test Kapısı

- `flutter analyze` sıfır issue ile geçmeli.
- `flutter test` tamamen geçmeli.
- Multiplayer kabul testi tamamlanmalı:
  - Android -> Android davet, kabul, hamle, chat, push, resume.
  - Android -> iPhone davet, kabul, hamle, chat, push, timeout.
  - iPhone -> Android davet, ret, duplicate invite, expired invite.
  - Random match arama, iptal, eşleşme ve forfeit.
- Firestore rules deploy edilmeden önce `gameInvites`, `matches`, `messages` ve `reports` akışları gerçek Firebase projesinde denenmeli.
- Cloud Functions deploy sonrası şu tetikleyiciler loglarda doğrulanmalı:
  - `notifyPersistentInviteOnCreate`
  - `notifyOpponentOnMove`

## 2. Facebook Login

Release öncesi placeholder kalmamalı:

```bash
rg "FACEBOOK_APP_ID_BURAYA|FACEBOOK_CLIENT_TOKEN_BURAYA" android ios
```

Bu komut hiçbir sonuç döndürmemeli.

Android dosyası:

```text
android/app/src/main/res/values/strings.xml
```

iOS dosyası:

```text
ios/Runner/Info.plist
```

Meta Developer, Firebase Auth Facebook provider ve OAuth redirect URI ayarları `docs/FACEBOOK_LOGIN_SETUP.md` dosyasına göre tamamlanmalı.

## 3. Android Release

- `android/key.properties` gerçek upload key ile doldurulmalı.
- Release build debug key ile imzalanmamalı.
- Version code `pubspec.yaml` içinde önceki Play Console sürümünden yüksek olmalı.

```bash
flutter build appbundle --release
```

Çıktı:

```text
build/app/outputs/bundle/release/app-release.aab
```

Crashlytics sembolleri gerekiyorsa:

```bash
tool/upload_symbols.sh
```

## 4. iOS Release

- Bundle identifier, signing team ve provisioning profile Xcode içinde doğrulanmalı.
- Facebook URL scheme `fbAPP_ID` gerçek App ID ile eşleşmeli.
- Push notification capability ve Firebase Messaging gerçek cihazda test edilmeli.

```bash
flutter build ipa --release
```

Ardından Xcode Organizer veya Transporter ile TestFlight yüklemesi yapılmalı.

## 5. Store Listing ve Veri Güvenliği

- Play Console metinleri için `docs/PLAY_STORE_PEYVOK.md` kullanılmalı.
- Gizlilik politikası herkese açık HTTPS URL olarak girilmeli.
- Serbest oyuncu chat'i açık olduğu için veri güvenliği/içerik beyanlarında kullanıcı etkileşimi ve kullanıcı üretimli içerik belirtilmeli.
- Chat raporlama akışı uygulamada uzun basma ile çalışmalı.
- Reklam kimliği kullanılmıyor olarak işaretlenmeli.

## 6. Son Kabul

- Uygulama ilk açılış, onboarding, auth, ana sayfa, günlük oyun, AI oyun, arkadaşla oyun, rastgele oyun, Ferheng ve ayarlar akışları gerçek cihazda açılmalı.
- App kapalıyken davet ve sıra bildirimi doğru ekrana götürmeli.
- İç test build'i en az 2 Android ve 1 iPhone cihazda denenmeden prod yayına geçilmemeli.
