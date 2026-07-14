import 'package:flutter/material.dart';
import 'package:kurdle_app/services/app_locale.dart';

/// Peyvok gizlilik politikası — uygulama içi sürüm.
///
/// Web sürümü `docs/privacy/index.html` altında yayınlanır. Play Console
/// gizlilik politikası ve Data Safety beyanları bu içerikle tutarlı kalmalı.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _kBgDark = Color(0xFF0F1923);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kBgDark : const Color(0xFFF4F8FA);
    final textColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white70 : const Color(0xFF52636E);
    final accent = const Color(0xFF4CAF50);
    final sections = L.current == AppLocale.tr ? _trSections : _kmrSections;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          L.privacyPolicy,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: sections.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  L.privacyPolicyUpdated,
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
              );
            }
            final section = sections[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

const _trSections = <_Section>[
  _Section(
    'Hangi verileri topluyoruz?',
    'Peyvok yalnızca oyun ve hesap özellikleri için gerekli verileri işler:\n'
        '• Hesap ve kimlik bilgileri — anonim giriş, Google veya e-posta ile giriş ve ilerleme senkronizasyonu için.\n'
        '• Profil bilgileri — oyuncu adı, avatar/profil görünümü ve oyun içi kimlik için.\n'
        '• Oyun verileri — skorlar, günlük oyun ilerlemesi, rozetler, liderlik tablosu, hamleler ve oyun geçmişi için.\n'
        '• Çok oyunculu veriler — davet, oda, eşleşme, sıra durumu ve oyun sonuçları için.\n'
        '• Oyun içi sohbet mesajları — aynı maçtaki oyuncuların mesajlaşması ve kötüye kullanım incelemesi için.\n'
        '• Bildirim token\'ı — sadece bildirim izni verildiğinde oyun sırası, davet ve hatırlatma bildirimleri için.\n'
        '• Çökme, performans ve kullanım verileri — hataları bulmak ve uygulamayı iyileştirmek için.',
  ),
  _Section(
    'Hangi verileri toplamıyoruz?',
    'Kesin konum, rehber/kişiler, SMS, arama kayıtları, kamera, mikrofon, sağlık verileri, finansal bilgiler, '
        'resmi kimlik bilgileri, fotoğraflar veya takvim verileri için erişim istemiyoruz.',
  ),
  _Section(
    'Verilerinizi nasıl kullanıyoruz?',
    'Veriler oyun deneyimini çalıştırmak, hesap/ilerleme senkronizasyonu yapmak, çok oyunculu davet ve sohbeti yönetmek, '
        'bildirim göndermek, güvenlik/kötüye kullanım sorunlarını incelemek ve hata/performans sorunlarını düzeltmek için kullanılır.',
  ),
  _Section(
    'Verileriniz kiminle paylaşılır?',
    'Peyvok temel altyapı için Google Firebase hizmetlerini kullanır: Firebase Authentication, Cloud Firestore, '
        'Firebase Cloud Messaging, Firebase Crashlytics ve Firebase Analytics. Veriler reklam amaçlı satılmaz; '
        'reklam ağlarına, veri brokerlerine veya pazarlama şirketlerine aktarılmaz.',
  ),
  _Section(
    'Güvenlik',
    'Veri aktarımı güvenli bağlantılar üzerinden yapılır. Firebase kimlik doğrulama, erişim kuralları ve güvenlik '
        'kontrolleri kullanılır. Yine de internet üzerinden hiçbir veri aktarımı tamamen risksiz değildir.',
  ),
  _Section(
    'Veri saklama ve silme',
    'Hesap, oyun ilerlemesi, skor, davet, sohbet ve ilgili oyun verileri hesabınız aktif olduğu sürece saklanabilir. '
        'Hesabınızı veya kişisel verilerinizi silmek için uygulama içinden ya da smnfrt@gmail.com adresinden talep gönderebilirsiniz. '
        'Silme talebi doğrulandıktan sonra hesabınızla ilişkilendirilebilen kişisel veriler makul süre içinde silinir.',
  ),
  _Section(
    'Çocukların gizliliği',
    'Peyvok 13 yaş altı çocukları aktif olarak hedeflemez. 13 yaş altı bir kullanıcının veri girdiğini fark edersek '
        'verileri sileriz.',
  ),
  _Section(
    'Politika güncellemeleri',
    'Bu politika güncellenebilir. Önemli değişikliklerde uygulama içinde veya yayınlanan politika sayfasında bildirim yapılabilir.',
  ),
  _Section(
    'İletişim',
    'Sorularınız için: smnfrt@gmail.com',
  ),
];

const _kmrSections = <_Section>[
  _Section(
    'Em kîjan daneyan kom dikin?',
    'Peyvok tenê daneyên ji bo lîstik û hesabê pêwîst in diparêze:\n'
        '• Agahiyên hesab û nasnameyê — ji bo têketina anonîm, Google an e-posta û senkronîzekirina pêşveçûnê.\n'
        '• Agahiyên profîlê — navê lîstikvan, avatar/profîl û nasnameya nav lîstikê.\n'
        '• Daneyên lîstikê — pûan, pêşveçûna rojane, rozet, tabloya pûanan, tevger û dîroka lîstikê.\n'
        '• Daneyên gelek-lîstikvan — vexwendin, ode, hevrêzî, dora lîstikê û encam.\n'
        '• Peyamên chatê — peyamên di navbera lîstikvanên heman maçê de û lêkolîna xerab-bikaranînê.\n'
        '• Token a agahdariyan — tenê dema destûr hatiye dayîn.\n'
        '• Daneyên xeletî, performans û bikaranînê — ji bo çaksazkirin û baştirkirina sepanê.',
  ),
  _Section(
    'Em kîjan daneyan kom nakin?',
    'Em cihê rast, têkilî/rehber, SMS, tomarên bangê, kamera, mîkrofon, daneyên tenduristî, agahiyên darayî, '
        'nasnameya fermî, wêne an salnameyê naxwazin.',
  ),
  _Section(
    'Daneyên te çawa tê bikaranîn?',
    'Daneyan ji bo xebitandina lîstikê, senkronîzekirina hesabê, vexwendin û chatê, agahdariyan, ewlehî, '
        'lêkolîna xerab-bikaranînê û çaksazkirina xeletî/performance tê bikaranîn.',
  ),
  _Section(
    'Daneyên te bi kê re tê parvekirin?',
    'Peyvok ji bo binesaziyê xizmetên Google Firebase bikar tîne: Firebase Authentication, Cloud Firestore, '
        'Firebase Cloud Messaging, Firebase Crashlytics û Firebase Analytics. Daneyên te ji bo reklamê nayên firotin '
        'û bi torên reklamê, brokerên daneyan an pargîdaniyên bazariyê re nayên parvekirin.',
  ),
  _Section(
    'Ewlehî',
    'Veguhestina daneyan bi girêdanên ewle tê kirin. Nasnamekirin, rêgezên gihîştinê û kontrolên ewlehiyê yên Firebase têne bikaranîn. '
        'Lê ti rêbazeke internetê bi temamî bê xeter nîne.',
  ),
  _Section(
    'Hilanîn û jêbirina daneyan',
    'Hesab, pêşveçûna lîstikê, pûan, vexwendin, chat û daneyên têkildar heta hesab aktîf be dikarin werin hilanîn. '
        'Ji bo jêbirina hesab an daneyên kesane ji nav sepanê an ji smnfrt@gmail.com re daxwaz bişîne.',
  ),
  _Section(
    'Veşariya zarokan',
    'Peyvok zarokên di bin 13 saliyê de ne armanc dike. Ger em fêr bibin ku bikarhênerek di bin 13 saliyê de daneyan dixe, em wan daneyan jê dibin.',
  ),
  _Section(
    'Nûkirinên polîtîkayê',
    'Ev polîtîka dikare were nûkirin. Di guhertinên girîng de em dikarin di nav sepanê an li ser rûpela polîtîkayê agahdarî bidin.',
  ),
  _Section(
    'Têkilî',
    'Ji bo pirsên xwe: smnfrt@gmail.com',
  ),
];
