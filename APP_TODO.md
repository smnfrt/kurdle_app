# Leyar Yapilacaklar

Bu dosya yeni Codex sohbetlerinde de okunabilsin diye repoda tutuluyor. Yeni bir sohbette "APP_TODO.md dosyasina bak" demek yeterli.

## Yapilacak

- App Store yas siniri / sosyal medya sorulari uyarisi tekrar cikarsa Age Rating bolumunden cevaplari kontrol et.

## Test Edilecek

- Arkadasla multiplayer oyunda `Secenekler > Harf Degistir` akisini test et. Harf secme, yeni harf alma ve sirayi rakibe gecirme dogru calismali.
- Oyun tahtasinin ustundeki kelime dogrulama bolumunu test et. Birden fazla kelime olustugunda her kelimenin gecerlilik durumu ayri ayri gorunmeli; tek gecersiz kelime digerlerini yanlis gibi gostermemeli.
- Multiplayer oyunda sira oyuncuya geldiginde gorunen bos kelime bilgi alanini test et. Ilk gorundukten sonra puan hesaplama / kelime onizleme alani aktif olana kadar kayarak kaybolmali.
- `Oyuncu Bul` arka plan eslesmesini test et. Kullanici arama ekranindan `Arka planda ara` ile ayrildiktan sonra bekleme odasi aktif kalmali; baska oyuncu eslesince oyun aktif oyunlara dusmeli.
- Apple ile girisi yeni kurulum / uygulamayi tamamen kapatip acma senaryosunda tekrar test et. Ilk denemede hata, ikinci denemede giris gibi davranis tekrar etmemeli.
- Ayarlar > Hesap & Profil > Hesabı Sil akisini test et. Apple inceleme videosunda hesap silme secenegi ve onay penceresi gosterilmeli; gercek ana hesabi silmeden test hesabi kullanilmali.
- App Store'a yuklenecek yeni build icin ekran goruntuleri ve inceleme videosu son kez dogru cihaz/model ve boyutlarla kontrol edilmeli.
- Yeni iOS archive/build yuklenince MinimumOSVersion'in 15.0 olarak gittigini kontrol et. Eski App Store uyarisi onceki build'in 12.0 olmasindan kaynaklaniyordu.

## Tamamlanan Kod Degisiklikleri

- Oyun tahtasinin ustundeki kelime dogrulama bolumu iyilestirildi. Birden fazla kelime olustugunda baslik artik gecersiz kelime sayisini ayri gosteriyor; kelimeler kendi dogruluk durumuna gore renkleniyor.
- Multiplayer oyunda bos kelime bilgi alani animasyonlu hale getirildi. Sira oyuncuya gelince kisa sure gorunup kayarak kayboluyor, kelime/puan olusunca tekrar gorunuyor.
- `Oyuncu Bul` ekranindan cikinca rastgele eslesme istegi silinmiyor. Buton `Arka planda ara` olarak guncellendi.
- iOS Deployment Target / MinimumOSVersion 15.0 olarak ayarli. Yeni build ile App Store minimum iOS uyarisi temizlenmeli.
- Google Cloud / Firebase OAuth branding guncellendi. Google hesap paylasim mailinde `project-221162003973` yerine Leyar gorunmesi bekleniyor; gerekirse yayina alinma/dogrulama sonrasi tekrar test edilecek.
- Google Play kisa aciklama guncellendi ve incelemeye gonderildi.
- Uygulama icine hesap silme ozelligi eklendi. Ayarlar > Hesap & Profil altinda `Hesabı Sil` gorunur; onaydan sonra Firebase Auth hesabi ve kullaniciya ait profil/oyun/liderlik verileri silinir. Firestore rules deploy edildi.
- Gercek iPhone'da multiplayer bildirimleri test edildi. Firebase APNs Authentication Key yenilendi; davet ve rakip hamlesi/sira bildirimi iOS tarafinda calisir hale getirildi. Cloud Functions bildirim loglari basari/hata kodlarini gosterecek sekilde guncellendi.

## Notlar

- Mevcut yerel degisiklikler: iOS bildirim ayarlari, hesap silme, multiplayer `Secenekler > Harf Degistir`, kelime dogrulama UI'i, arka plan eslesme ve App Store inceleme hazirliklari.
- App Store'da bekleyen mevcut build bu yerel degisiklikleri icermez; yeni build ile gider.
