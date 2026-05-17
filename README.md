# Peyvok

**Kurmancî kelime oyunu.** Günlük Wordle, AI ile Scrabble benzeri savaş, arkadaşlarla multiplayer, 216k+ entry'lik gömülü Ferheng sözlük.

Hedef platformlar: Android, iOS. Bu repo Flutter (Dart 3.6+) uygulamasıdır.

## Özellikler

- **Günün Kelimesi** — her gün 5 harflik Wordle, sonuçlar paylaşılabilir
- **AI Scrabble** — 15×15 tahta, 3 zorluk seviyesi (Hêsan / Navîn / Zehmet)
- **Arkadaşlarla Oyna** — davet kodu veya kullanıcı adıyla eşleş
- **Rastgele Eşleşme** — anlık rakip bul
- **Ferheng (sözlük)** — 216k Kurmancî entry, ku.wiktionary + FreeDict kaynaklı, %63'ün TR çevirisi
- **Achievement + streak** — günlük oynama serisi, başarım rozetleri
- **Çift dil arayüz** — Kurmancî (KU) + Türkçe (TR), runtime'da geçiş

## Tech stack

- Flutter 3.27+ / Dart 3.6+
- Firebase: Auth (anon + Google + e-posta), Firestore, Messaging, Crashlytics, Analytics
- Yerel persistence: shared_preferences + Hive (favoriler)
- Sözlük pipeline: Python 3.9 + spylls (Hunspell) + orjson
- AGP 8.9.1, Gradle 8.11.1, Kotlin 2.1.0, compileSdk 36, NDK 27.0.12077973

## Geliştirme

```bash
flutter pub get
flutter run --debug      # debug — Crashlytics kapalı
flutter run --release    # release — Crashlytics aktif
flutter test             # birim testleri
flutter analyze          # statik analiz (0 issue olmalı)
```

### Firebase

- Proje: `peyvok-8e808`
- `google-services.json` ve `GoogleService-Info.plist` repoda **yok** (gitignore'da). `flutterfire configure` ile yenisi üretilebilir veya mevcut konfig dosyaları kullanıcı tarafından sağlanır.
- iOS Podfile ilk `flutter build ios` ile oluşur.

### Ferheng pipeline

Sözlük yeniden derlemek için:
```bash
cd tools/ferheng_pipeline
make all              # fetch → unmunch → filter → merge → categorize → emit
make deploy-assets    # assets/ferheng/ altına dosyaları kopyalar
```
Detay: `tools/ferheng_pipeline/README` (varsa) ve `tool/` altındaki Python araçları.

## Release

Mağaza yayını için **`docs/STORE_RELEASE.md`** kontrol listesini izle. Özet:

```bash
flutter build apk --release         # Direkt cihaz testi için
flutter build appbundle --release   # Google Play yayını için (.aab)
tool/upload_symbols.sh              # Release + Crashlytics symbol upload
```

Release imzalama için `android/key.properties` dosyası gerek — bkz. `docs/STORE_RELEASE.md` "Signing" bölümü.

## Lisans

Kod proje-içi. Sözlük verisi CC BY-SA 4.0 (ku.wiktionary) + FreeDict (GPL-2.0+) — `assets/ferheng/ATTRIBUTION.md`.

## Gizlilik

Bkz. `PRIVACY.md` (uygulama içinde de Settings → Gizlilik Politikası).
