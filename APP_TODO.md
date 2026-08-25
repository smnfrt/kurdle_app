# Leyar Yapilacaklar

Bu dosya yeni Codex sohbetlerinde de okunabilsin diye repoda tutuluyor. Yeni bir sohbette "APP_TODO.md dosyasina bak" demek yeterli.

## Yapilacak

- App Store yas siniri / sosyal medya sorulari uyarisi tekrar cikarsa Age Rating bolumunden cevaplari kontrol et.

## Test Edilecek

- Arkadasla multiplayer oyunda `Secenekler > Harf Degistir` akisini test et. Harf secme, yeni harf alma ve sirayi rakibe gecirme dogru calismali.
- Arkadasla multiplayer oyunda `Cal` ve kelime koruma akisini test et. Rakibin yeni yazdigi kelime ilk tur korunmali; sonraki turda basindan/sonundan uzatilinca calinabilmeli; basarisiz denemede neden mesajda gorunmeli.
- Haftalik ve tum zamanlar siralamanin yeni performans puaniyla arttigini test et. AI/multiplayer skor, Wordle galibiyeti ve gunluk challenge skoru leaderboard'a yansimali; profil `En Yuksek Skor` tek oyun rekoru olarak kalmali.
- App Store tekrar gonderiminde giris ekranini kontrol et. Google ve Apple giris butonlari ayni boyut, renk sistemi ve hiyerarside gorunmeli.
- Oyun tahtasinin ustundeki kelime dogrulama bolumunu cihazda test et. Birden fazla kelime olustugunda her kelime ayri rozet olarak gorunmeli; gecerli kelimede onay, gecersiz kelimede hata isareti cikmali.
- AI ve multiplayer oyunlarda hamle puanini cihazda karsilastir. Kilitli/eski harfler kelimeyi olusturmali ama hamle puanina eklenmemeli; puan yalnizca oyuncunun yeni yerlestirdigi taslardan gelmeli.
- Multiplayer oyunda sira oyuncuya geldiginde gorunen bos kelime bilgi alanini cihazda test et. Ilk gorundukten sonra kayarak kaybolmali ve oda verisi yenilendikce tekrar tekrar sabit kalmamali.
- Ana ekrandaki `Siralama` kartini kucuk ekran ve Kurmanci/Turkce dilde test et. Baslik, sekmeler, oyuncu adi ve skor metinleri karttan tasmamali.
- `Oyuncu Bul` arka plan eslesmesini test et. Kullanici arama ekranindan `Arka planda ara` ile ayrildiktan sonra bekleme odasi aktif kalmali; baska oyuncu eslesince oyun aktif oyunlara dusmeli.
- Apple ile girisi yeni kurulum / uygulamayi tamamen kapatip acma senaryosunda tekrar test et. Ilk denemede hata, ikinci denemede giris gibi davranis tekrar etmemeli.
- Ayarlar > Hesap & Profil > Hesabı Sil akisini test et. Apple inceleme videosunda hesap silme secenegi ve onay penceresi gosterilmeli; gercek ana hesabi silmeden test hesabi kullanilmali.
- App Store'a yuklenecek yeni build icin ekran goruntuleri ve inceleme videosu son kez dogru cihaz/model ve boyutlarla kontrol edilmeli.
- Yeni iOS archive/build yuklenince MinimumOSVersion'in 15.0 olarak gittigini kontrol et. Eski App Store uyarisi onceki build'in 12.0 olmasindan kaynaklaniyordu.

## Tamamlanan Kod Degisiklikleri

- Oyun tahtasinin ustundeki kelime dogrulama bolumu rozetli hale getirildi. Birden fazla kelime olustugunda her kelime kendi onay/hata isareti ve puaniyla ayri gorunur.
- Hamle puani hesaplama tek merkezden guncellendi. Eski/kilitli harfler kelime dogrulamasinda kullanilir ama puana eklenmez; puan yalnizca yeni yerlestirilen taslardan hesaplanir.
- Multiplayer oyunda bos kelime bilgi alani animasyonlu hale getirildi. Sira oyuncuya gelince kisa sure gorunup kayarak kaybolur; oda verisi tekrar geldikce sureyi bastan baslatmaz.
- Ana ekrandaki `Siralama` kartinda metin tasmalari icin baslik, sekmeler, oyuncu adlari ve skorlar sinirlandi.
- `Oyuncu Bul` ekranindan cikinca rastgele eslesme istegi silinmiyor. Buton `Arka planda ara` olarak guncellendi.
- iOS Deployment Target / MinimumOSVersion 15.0 olarak ayarli. Yeni build ile App Store minimum iOS uyarisi temizlenmeli.
- Google Cloud / Firebase OAuth branding guncellendi. Google hesap paylasim mailinde `project-221162003973` yerine Leyar gorunmesi bekleniyor; gerekirse yayina alinma/dogrulama sonrasi tekrar test edilecek.
- Google Play kisa aciklama guncellendi ve incelemeye gonderildi.
- Uygulama icine hesap silme ozelligi eklendi. Ayarlar > Hesap & Profil altinda `Hesabı Sil` gorunur; onaydan sonra Firebase Auth hesabi ve kullaniciya ait profil/oyun/liderlik verileri silinir. Firestore rules deploy edildi.
- Gercek iPhone'da multiplayer bildirimleri test edildi. Firebase APNs Authentication Key yenilendi; davet ve rakip hamlesi/sira bildirimi iOS tarafinda calisir hale getirildi. Cloud Functions bildirim loglari basari/hata kodlarini gosterecek sekilde guncellendi.
- Multiplayer `Cal` akisi kalici kelime gecmisiyle guncellendi. Artik hangi kelimenin kime ait oldugu, kac tur korumada kaldigi ve kac kez calindigi oda verisinde tutulur; basarisiz calmalarda koruma/hedef/hak nedeni mesajda gorunur.
- Siralama puani tek oyun rekoru yerine performans toplamina cevrildi. Haftalik siralama haftalik toplam katkiyi, tum zamanlar siralamasi kariyer toplam skor + galibiyet bonuslarini kullanir; profil highScore alani korunur.
- App Store Guideline 4 reddi icin Apple ile giris butonu Google giris butonuyla ayni ortak sosyal giris tasarimina alindi. Apple secenegi artik diger giris secenegiyle esit boyut ve hiyerarside gorunur.

## Notlar

- Mevcut yerel degisiklikler: iOS bildirim ayarlari, hesap silme, multiplayer `Secenekler > Harf Degistir`, kelime dogrulama UI'i, arka plan eslesme ve App Store inceleme hazirliklari.
- App Store'da bekleyen mevcut build bu yerel degisiklikleri icermez; yeni build ile gider.
- Bundan sonra bir madde `Tamamlanan Kod Degisiklikleri` altina alinmadan once hem kodda uygulanmis olmali hem de `Test Edilecek` altinda cihazda dogrulama adimi kalmali.
