import 'package:flutter/material.dart';
import 'package:kurdle_app/services/app_locale.dart';

/// Peyvok gizlilik politikası — uygulama içi sürüm.
///
/// Aynı içerik repo kökündeki PRIVACY.md'de host'lanabilir (App Store /
/// Google Play listing için). İki dilde TR + KMR; locale switch'e göre
/// otomatik geçer.
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
    'Peyvok yalnızca uygulamanın çalışması için gerekli en az veriyi toplar:\n'
        '• Anonim kullanıcı kimliği (Firebase Auth) — oyun ilerlemenizi cihazlar arası senkronize etmek için.\n'
        '• İsteğe bağlı profil adı — sadece kendi seçtiğiniz isim.\n'
        '• Oyun istatistikleri — günlük oyun sonuçları, achievement (rozet) ilerlemeniz, leaderboard skorlarınız.\n'
        '• Çok oyunculu oyun verileri — oda kodu, hamleler. Oyun bittiğinde silinir.\n'
        '• Bildirim token\'ı (Firebase Messaging) — sadece bildirim izni verdiyseniz.\n'
        '• Çökme raporları (Firebase Crashlytics) — uygulama çöktüğünde teknik bilgi (cihaz modeli, hata stack trace).\n'
        '• Anonim kullanım metrikleri (Firebase Analytics) — hangi ekranların kullanıldığı.',
  ),
  _Section(
    'Hangi verileri toplamıyoruz?',
    'Konum, kişiler, mikrofon, kamera, takvim ya da reklam kimliği (IDFA) gibi hiçbir hassas veriyi toplamıyoruz. '
        'Google veya e-posta ile giriş yaparsanız sadece o sağlayıcının verdiği temel kimlik bilgileri kullanılır.',
  ),
  _Section(
    'Verilerinizi kiminle paylaşıyoruz?',
    'Verileriniz yalnızca uygulamanın işleyişi için Firebase (Google) altyapısında saklanır. '
        'Hiçbir verinizi reklam ağlarına, üçüncü taraf veri brokerlerine veya pazarlama şirketlerine satmıyor, '
        'paylaşmıyoruz.',
  ),
  _Section(
    'Verileriniz ne kadar saklanıyor?',
    'Hesabınız aktif olduğu sürece. Hesabınızı silmek isterseniz uygulama içinden veya '
        'destek e-postası üzerinden talep edebilirsiniz; profil, oyun geçmişi ve achievement\'larınız 30 gün '
        'içinde tamamen silinir.',
  ),
  _Section(
    'Çocukların gizliliği',
    'Peyvok 13 yaş altı çocukları aktif olarak hedeflemez. 13 yaş altı bir kullanıcının veri girdiğini fark edersek '
        'verileri sileriz.',
  ),
  _Section(
    'Politika güncellemeleri',
    'Bu politika değişirse uygulama içinde bildirim göstereceğiz. Devam eden kullanım güncel politikayı kabul '
        'ettiğiniz anlamına gelir.',
  ),
  _Section(
    'İletişim',
    'Sorularınız için: smnfrt@gmail.com',
  ),
];

const _kmrSections = <_Section>[
  _Section(
    'Em kîjan daneyan kom dikin?',
    'Peyvok tenê wan daneyan kom dike ku ji bo karkirina sepanê pêwîst in:\n'
        '• Nasnameya bikarhênera anonîm (Firebase Auth) — ji bo senkronîzekirina pêşveçûna lîstikê di navbera amûran de.\n'
        '• Navê profîlê yê bijartî — tenê navê ku tu hilbijêrî.\n'
        '• Statîstîkên lîstikê — encamên rojane, pêşveçûna rozetan, pûanên leaderboard\'ê.\n'
        '• Daneyên lîstika gelek-lîstikvan — koda odeyê, livên lîstikê. Piştî lîstikê tê jêbirin.\n'
        '• Token a agahdariyan (Firebase Messaging) — tenê eger destûr dabe.\n'
        '• Raporên xeletiyê (Firebase Crashlytics) — gava sepan dikeve, agahdariya teknîkî.\n'
        '• Metrîkên bikaranînê yên anonîm (Firebase Analytics) — kîjan ekran tê bikaranîn.',
  ),
  _Section(
    'Em kîjan daneyan kom nakin?',
    'Em ti daneyên hesas wek cih, têkilî, mîkrofon, kamera, jimara reklamê (IDFA) kom nakin. '
        'Eger bi Google an e-posta xwe têxin, tenê agahiyên kîmliyê yên ku ew dabe tê bikaranîn.',
  ),
  _Section(
    'Daneyên te bi kê re tê parvekirin?',
    'Daneyên te tenê di binesaziya Firebase (Google) de têne hilanîn. Em ti daneyan nafiroşin, '
        'bi torên reklamê, broker an pargîdaniyên bazariyê re parve nakin.',
  ),
  _Section(
    'Daneyên te çiqas tê hilanîn?',
    'Heya hesabê te aktîf be. Eger bixwazî hesabê xwe jêbibî, ji nav sepanê yan e-posta '
        'piştgiriyê dikarî daxwaz bikî; di nav 30 rojan de profîl, dîroka lîstikê û rozetên te bi temamî tê jêbirin.',
  ),
  _Section(
    'Veşariya zarokan',
    'Peyvok zarokên di bin 13 saliyê de ne armanc dike. Ger em fêr bibin ku bikarhênerek di bin 13 saliyê de daneyan dixe, em wan daneyan jê dibin.',
  ),
  _Section(
    'Nûkirinên polîtîkayê',
    'Eger ev polîtîka biguhere, em ê di nav sepanê de agahdariyê nîşan bidin. Bikaranîna berdewam tê wateya pejirandina polîtîkaya nûkirî.',
  ),
  _Section(
    'Têkilî',
    'Ji bo pirsên xwe: smnfrt@gmail.com',
  ),
];
