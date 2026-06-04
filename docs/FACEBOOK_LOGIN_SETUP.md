# Peyvok Facebook Giriş Kurulumu

Kod tarafı eklendi. Girişin gerçekten çalışması için aşağıdaki panel ayarları yapılmalı.

## 1. Meta Developer

1. https://developers.facebook.com/apps adresinden yeni uygulama oluştur.
2. Uygulama adı: `Peyvok`
3. Use case / ürün: `Facebook Login`
4. Android platformu ekle.
5. Package name:
   `com.kurdle.kurdle_app`
6. Main Activity:
   `com.kurdle.kurdle_app.MainActivity`
7. Android key hash ekle.

Key hash için terminalde:

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
```

Release / Play imzalı sürüm için Meta paneline Play App Signing sertifikasının key hash'i de eklenmeli.

Bu projede hesaplanan key hash'ler:

```text
Debug: OnhbuWBMEAfX6xpKVSHC7uzhExU=
Release upload key: HyE6dtwNWYuxhxGVZfEpDlma4I8=
Play App Signing key: C+Tp/7r2BZAEUye8VbMfE2uI2X4=
```

## 2. Firebase

Firebase Console:

1. Authentication > Sign-in method
2. Facebook sağlayıcısını aç.
3. Meta panelindeki `App ID` ve `App Secret` değerlerini gir.
4. Firebase'in verdiği OAuth redirect URI değerini kopyala.
5. Meta Developer > Facebook Login > Settings bölümünde `Valid OAuth Redirect URIs` alanına ekle.

## 3. Kodda Doldurulacak Değerler

Meta panelinden aldığın `App ID` ve `Client Token` değerleri şu dosyalara yazılmalı:

Android:
`android/app/src/main/res/values/strings.xml`

```xml
<string name="facebook_app_id">APP_ID</string>
<string name="fb_login_protocol_scheme">fbAPP_ID</string>
<string name="facebook_client_token">CLIENT_TOKEN</string>
```

iOS:
`ios/Runner/Info.plist`

```xml
<key>FacebookAppID</key>
<string>APP_ID</string>
<key>FacebookClientToken</key>
<string>CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>Peyvok</string>
```

`CFBundleURLSchemes` içinde de `fbAPP_ID` olmalı.

## 4. Test

1. Meta uygulaması development mode'daysa test edecek Facebook hesabını role/tester olarak ekle.
2. Firebase'de Facebook sağlayıcısı açık olsun.
3. `flutter run -d 7xrgusn7ced6caoz` ile cihazda test et.
4. Play Store iç test sürümünde test edeceksen yeni AAB build al ve yükle.

## 5. Kod Tarafında Eklenenler

- `flutter_facebook_auth`
- `AuthService.signInWithFacebook()`
- Giriş ekranında `Facebook ile Giriş Yap` butonu
- Android manifest Facebook activity / custom tab ayarları
- iOS Info.plist Facebook ayar alanları
