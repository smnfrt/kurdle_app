# Peyvok — Mağaza Yayın Kontrol Listesi

Bu doküman Google Play Store ve Apple App Store yayınına çıkarken kontrol edilmesi gerekenleri özetler.

---

## 1. Mağaza listing metni

### App Name
- **Google Play:** `Peyvok — Kurmancî Kelime Oyunu`
- **App Store:** `Peyvok: Kurmancî Wordle`

### Subtitle (App Store, max 30 karakter)
`Wordle + Scrabble bi kurdî`

### Short description (Google Play, max 80 karakter)
`Kurmancî Wordle, AI Scrabble ve 216k entry'lik sözlük. Her gün bir kelime!`

### Full description (Google Play / App Store, max 4000 / 4000 karakter)

```
Peyvok — Kurmancî kelime oyunlarının buluştuğu yer.

🎯 ÖZELLİKLER
• Günün Kelimesi — her gün 5 harflik yeni Wordle
• AI ile Scrabble — 15×15 tahta, 3 zorluk seviyesi (Hêsan / Navîn / Zehmet)
• Arkadaşlarla Oyna — davet kodu veya kullanıcı adıyla eşleş
• Rastgele Eşleşme — anında rakip bul
• Ferheng — 216,000+ Kurmancî entry'lik gömülü sözlük
  (ku.wiktionary + FreeDict + curated kaynaklar)
• Achievement + günlük seri — istatistiklerini takip et

🌍 ÇİFT DİL
Türkçe ve Kurmancî arayüz — runtime'da geçiş yapabilirsin.

📚 ÖĞRENCİ DOSTU
Her oynanan kelimenin sözlükteki anlamına tek dokunuşla ulaşırsın.
Türkçe ve Kurmancî tanımlar birlikte gösterilir.

🔒 GİZLİLİK
Sadece anonim kimlik, oyun istatistikleri ve çökme raporları saklanır.
Konum, kişiler, mikrofon erişimi YOKTUR.
Detay: [Gizlilik Politikası] uygulamada Settings → Gizlilik Politikası

💚 KURMANCÎ DİLİNE DESTEK
Peyvok, Kurmancî'yi oyun yoluyla öğrenmeyi ve canlı tutmayı amaçlar.
ku.wiktionary, FreeDict ve Kurmancî Hunspell sözlüklerinin
açık kaynak verisini kullanır (CC BY-SA 4.0, GPL-2.0+).
```

### Keywords (App Store, max 100 karakter, virgülle)
`kurmancî, kürtçe, wordle, scrabble, kelime, oyun, ferheng, sözlük, kürt, dil`

### Category
- **Google Play:** Games → Word
- **App Store:** Games → Word

### Privacy URL
`<host edilmiş PRIVACY.md URL'si>` — örnek: `https://peyvok.app/privacy`

### Support URL
`<destek e-posta veya destek sayfası>` — örnek: `mailto:smnfrt@gmail.com`

### Age rating
- **Google Play IARC:** Everyone (Tüm yaşlar)
- **App Store:** 4+ (uygunsuz içerik yok)

---

## 2. Görsel varlıklar

### App Icon
- ✅ Üretildi: `assets/branding/icon-1024.png`
- ✅ `dart run flutter_launcher_icons` ile tüm iOS/Android boyutları otomatik
- Adaptive icon foreground + background: `#1B5E20`

### Splash
- ✅ Üretildi: `assets/branding/splash-{light,dark}.png`
- ✅ `dart run flutter_native_splash:create` ile native splash
- Android 12+ destekli

### Screenshots (manuel — kullanıcı yapacak)
Tavsiye edilen 5-8 screenshot:

1. Ana ekran — günün kelimesi kartı vurgulu
2. Wordle ekranı — orta seviye, renkli hücreler
3. Scrabble tahtası — AI ile oyun
4. Word meaning popup — TR + KMR
5. Ferheng kategori — örn. "Hayvanlar"
6. Multiplayer lobby / davet ekranı
7. Achievement / streak ekranı
8. Settings — dil geçişi vurgu

**Boyutlar:**
- Google Play: 1080×1920 (telefon dikey) en az 2 adet, max 8
- App Store: 1290×2796 (iPhone 6.7") en az 3 adet, max 10

### Feature Graphic (Google Play)
1024×500 — App icon + Peyvok yazısı + "Kurmancî Wordle & Scrabble" subtitle

---

## 3. Build & imzalama

### Release keystore (Android)
Daha önce keystore oluşturmadıysan:

```bash
keytool -genkey -v -keystore ~/peyvok-release.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias peyvok
```

Üretilen `.jks` dosyasını **güvenli bir yerde sakla** — kaybedersen aynı paket için yeni sürüm yayınlayamazsın.

Sonra `android/key.properties.example` dosyasını kopyala:

```bash
cp android/key.properties.example android/key.properties
# key.properties'i kendi dosya yolları + şifrelerinle doldur
```

`android/key.properties` `.gitignore`'da — commit edilmez.

### Build komutları

```bash
# Direkt cihaz testi için
flutter build apk --release

# Google Play yayını (.aab — App Bundle)
flutter build appbundle --release

# Crashlytics symbol upload + obfuscation
tool/upload_symbols.sh
```

### Version bump
Her yayında `pubspec.yaml`'da:
- `version: 1.0.0+1` → `1.0.1+2` (semver + build number)
- Build number Play Store içinde her release için artmalı

---

## 4. iOS özellikleri

### Xcode setup
1. `flutter build ios` ile Pods kurulur
2. `ios/Runner.xcworkspace` → Xcode aç
3. Signing & Capabilities → Team seç
4. Bundle Identifier: `com.kurdle.kurdle_app` (mevcut, değiştirme — Firebase config buna bağlı)
5. Archive (Product → Archive) → App Store Connect'e yükle

### Privacy manifest (PrivacyInfo.xcprivacy)
Firebase plugin'leri kendi privacy manifest'lerini bundle eder. Manuel müdahale gerekmez.

### App Tracking Transparency
Peyvok IDFA / cross-app tracking yapmaz → ATT prompt gerekmez. Info.plist'te `NSUserTrackingUsageDescription` yok.

### dSYM upload
Release archive'da otomatik. Crashlytics symbol upload elle istenirse:
```bash
firebase crashlytics:symbols:upload --app=<ios-app-id> /path/to/dSYMs
```

---

## 5. Pre-launch kontrol kapıları

```bash
flutter analyze              # 0 issue olmalı
flutter test                 # tüm test geçmeli
flutter build apk --release  # debug-key fallback ile geçer
flutter build appbundle --release
```

### Manuel kontrol
- [ ] App icon iki platformda da Peyvok logosu (Flutter logosu DEĞİL)
- [ ] Splash native (Android 12+ ve eski) doğru görünüyor
- [ ] Dil değişimi (TR ↔ KU) çalışıyor, layout taşmıyor
- [ ] Light + dark mode geçişi tüm ekranlarda doğru
- [ ] Bildirim toggle kapalıyken hiçbir izin promptu yok
- [ ] Bildirim toggle açılırken izin promptu çıkıyor
- [ ] Offline → banner görünüyor; online → kayboluyor
- [ ] Crashlytics dashboard (Firebase Console) crash alıyor (release build'de)
- [ ] Privacy policy ekranı Settings'ten açılıyor
- [ ] Versiyon "About" diyaloğunda doğru görünüyor

---

## 6. Bilinen iyileştirme alanları (post-launch)

- **TR coverage:** 216k entry'nin %63'ünde TR var. Kalan %37 manuel curation veya AI translation ile büyütülebilir.
- **Onboarding:** Yeni kullanıcı için interaktif "ilk hamle" demosu eklenebilir.
- **Achievement celebration:** Rozet kazanınca toast/animasyon eksik.
- **iOS Launch Screen storyboard:** Native splash kullanıldığı için storyboard yedek; özelleştirilebilir.
- **Tournaments:** Var ama kullanıcıya çok belirgin değil, vitrin çalışması gerek.

---

## 7. Sürüm geçmişi (changelog)

Her sürümün özetini buraya ekle:

### 1.0.0 — İlk yayın hedefi
- Wordle, AI Scrabble, multiplayer, Ferheng (216k entry), achievements, streak
- Türkçe + Kurmancî arayüz
- Firebase: Auth, Firestore, Crashlytics, Analytics
- Offline banner, privacy policy, version sync
