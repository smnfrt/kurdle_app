enum AppLocale { tr, ku }

class L {
  static AppLocale _current = AppLocale.tr;
  static AppLocale get current => _current;
  static void set(AppLocale l) => _current = l;

  // ── Genel ──────────────────────────────────────────────────────
  static String get appSubtitle    => _s('Kürmanci Kelime Oyunu', 'Lîstika Peyvan');
  static String get wordOfDay      => _s('Günün Kelimesi', 'Peyvê Roja');
  static String get revealMeaning  => _s('Anlamı?', 'Wateya?');
  static String get meaningLabel   => _s('Türkçe anlamı', 'Wateya Tirkî');
  static String get points         => _s('puan', 'xal');

  // ── Ana ekran ──────────────────────────────────────────────────
  static String get ranking        => _s('Sıralama', 'Rêzik');
  static String get weekly         => _s('Haftalık', 'Hefteyî');
  static String get allTime        => _s('Tüm Zamanlar', 'Hemû Dem');
  static String get globalRanking  => _s('Global', 'Global');
  static String get myRank         => _s('Sıran', 'Rêza te');
  static String get newGame        => _s('Yeni Oyun', 'Lîstika Nû');
  static String get howToPlay      => _s('Nasıl oynamak istersin?', 'Tu çawa dixwazî bilîzî?');
  static String get aiPlay         => _s('AI ile Oyna', 'Bi AI re bilîze');
  static String get friendPlay     => _s('Arkadaşlarınla Oyna', 'Bi hevalên xwe re');
  static String get friendPlaySub  => _s('Arkadaşını davet et', 'Hevalê xwe vexwîne');
  static String get findPlayer     => _s('Oyuncu Bul', 'Lîstikvan Bibîne');
  static String get findPlayerSub  => _s('Rastgele eşleş', 'Bi rengekî tesadufî');
  static String get soon           => _s('Yakında', 'Bê dî');
  static String get myGames        => _s('Oyunlarım', 'Lîstikên min');
  static String get noGames        => _s('Henüz oyun yok', 'Hîn lîstik tune');
  static String gamesCount(int n)  => _s('$n oyun', '$n lîstik');
  static String get active         => _s('Devam ediyor', 'Berdewam e');
  static String get finished       => _s('Tamamlandı', 'Qediya');
  static String get paused         => _s('Duraklatıldı', 'Sekinî');
  static String get resume         => _s('Devam Et', 'Berdewam bike');
  static String get comingSoon     => _s('Bu özellik yakında geliyor!', 'Ev taybetmendî bê dî tê!');

  // ── Oyun ekranı ────────────────────────────────────────────────
  static String get options        => _s('Seçenekler', 'Vebijêrk');
  static String get passTurn       => _s('Pas Geç', 'Derbas bike');
  static String get passTurnSub    => _s('Bu turu atla', 'Ev gerê derbas bike');
  static String get exchangeTiles  => _s('Harf Değiştir', 'Tîpan biguherîne');
  static String get exchangeSub    => _s('değiştirmek istediklerini seç', 'yên ku dixwazî biguherînî hilbijêre');
  static String get resign         => _s('Teslim Ol', 'Teslîm bibe');
  static String get resignSub      => _s('Oyunu bitir, rakibin kazanır', 'Lîstikê biqedîne, heyfa te bi ser dikeve');
  static String get resignConfirm  => _s('Gerçekten teslim olmak istiyor musun?', 'Tu bi rastî dixwazî teslîm bibî?');
  static String get cancel         => _s('Vazgeç', 'Dev berde');
  static String get play           => _s('Oyna', 'Bilîze');
  static String get recall         => _s('Geri Al', 'Vegerîne');
  static String get shuffle        => _s('Karıştır', 'Tevlihev bike');
  static String get newGameBtn     => _s('Yeni Oyun', 'Lîstika Nû');
  static String get won            => _s('🎉 Kazandın!', '🎉 Tu bûyî!');
  static String get lost           => _s('😔 Kaybettin', '😔 Tu lê xwar!');
  static String get placeTile      => _s('Tahtaya harf yerleştir!', 'Tîpê li ser texteyê bide!');
  static String get sameRowCol     => _s('Harfler aynı satır veya sütunda olmalı!', 'Tîp divê di heman rêz an stûnê de bin!');
  static String get centerFirst    => _s('İlk hamle merkez kareden (★) geçmeli!', 'Yekem livê divê ji navenda (★) derbas bibe!');
  static String get touchLocked    => _s('Harfler mevcut kelimelerle bitişik olmalı!', 'Tîp divê bi peyvên heyî re bitişik bin!');
  static String get noWord         => _s('Geçerli bir kelime oluşmadı!', 'Peyva derbasdar nehat!');
  static String get aiTurn         => _s('AI düşünüyor...', 'AI difikirine...');
  static String get yourTurn       => _s('Senin sıran', 'Rêza te');
  static String get tilesLeft      => _s('Torbada', 'Di torê de');
  static String passesLeft(int n)  => _s('$n hak kaldı', '$n maf maye');
  static String get noPassLeft     => _s('Pas hakkın kalmadı!', 'Mafê te yê derbasbûnê nemaye!');
  static String get notEnoughTiles => _s('Torbada yeterli harf yok!', 'Di torê de tîpên têr nîn!');
  static String get selectTile     => _s('En az bir harf seç!', 'Herî kêm yek tîp hilbijêre!');
  static String get exchangeConfirm=> _s('Değiştir', 'Biguherîne');
  static String get exchangeTitle  => _s('Hangi harfleri değiştirmek istiyorsun?', 'Tu dixwazî kîjan tîpan biguherînî?');
  static String get meaningNotFound=> _s('Anlam bulunamadı', 'Wate nehat dîtin');
  static String get gameEndedByPasses => _s('Toplam pas limiti doldu — oyun bitti!', 'Sînorê derbasbûnê temam bû — lîstik qediya!');
  static String exchanged(int n)   => _s('$n harf değiştirildi', '$n tîp hatin guhertin');
  static String invalidWords(String s) => _s('"$s" geçerli kelime değil!', '"$s" peyva derbasdar nîne!');
  static String get noTilesInBag   => _s('Torbada harf kalmadı', 'Di torê de tîp nemaye');
  static String get rankingGreat   => _s('Harika gidiyorsun! 🎉', 'Gelek baş e! 🎉');
  static String rankingBehind(int rank, String gap) =>
      _s('$rank. sıraya $gap puan kaldı', 'Ji rêza $rank $gap xal maye');
  static String get howToPlayShort => _s('Nasıl Oynanır?', 'Çawa tê lîstin?');

  // ── Nasıl Oynanır ekranı ───────────────────────────────────────
  static String get howToTitle        => _s('NASIL OYNANIR', 'ÇAWA TÊTE LÎSTIN');
  static String get howToIntro        => _s('KURDLE', 'KURDLE');
  static String get howToIntroSuffix  => _s("'ı altı denemede bul.", "'yê di şeş hewlan de texmîn bike.");
  static String get howToRule1        => _s('Her tahmin geçerli bir beş harfli kelime olmalıdır. Göndermek için ENTER\'a basın.', 'Her texmîn divê peyva pênc-tîpî ya derbasdar be. Ji bo şandinê bişkoka ENTER bixin.');
  static String get howToRule2        => _s('Her tahminden sonra karoların rengi, tahminin kelimeye ne kadar yakın olduğunu göstermek için değişir.', 'Piştî her texmînê, rengê kelikên dê biguheze da ku nîşan bide texmîna te çiqas nêzîkî peyvê bû.');
  static String get howToExamples     => _s('Örnekler', 'Mînak');
  static String get howToCorrect      => _s('harfi kelimede ve doğru yerde.', 'di peyvê de ye û di cîhê rast de ye.');
  static String get howToPresent      => _s('harfi kelimede ama yanlış yerde.', 'di peyvê de ye lê di cîhê şaş de ye.');
  static String get howToAbsent       => _s('harfi kelimede yok.', 'di peyvê de tune ye.');
  static String get howToLetter       => _s('Harf', 'Tîpa');
  static String get howToDaily        => _s('Her gün yeni bir ', 'Her roj ');
  static String get howToDailySuffix  => _s(' var.', 'yeke nû heye.');
  static String get about          => _s('Hakkında', 'Derbarê');
  static String get settings       => _s('Ayarlar', 'Mîheng');
  static String get statistics     => _s('İstatistikler', 'Statîstîk');
  static String get language       => _s('Dil', 'Ziman');
  static String get totalGames     => _s('Toplam Oyun', 'Hemû Lîstik');
  static String get winRate        => _s('Kazanma Oranı', 'Rêjeya Berdestiyê');
  static String get bestScore      => _s('En Yüksek Skor', 'Herî Bilind');
  static String get version        => _s('Sürüm', 'Guherto');
  static String get accountProfile => _s('Hesap & Profil', 'Hesab & Profîl');
  static String get editProfile    => _s('Profili Düzenle', 'Profîlê Biguherîne');
  static String get signOut        => _s('Çıkış Yap', 'Derkeve');
  static String get gameSettings   => _s('Oyun Ayarları', 'Mîhengên Lîstikê');
  static String get sound          => _s('Ses Efektleri', 'Dengên Lîstikê');
  static String get haptic         => _s('Titreşim', 'Lerizîn');
  static String get notifications  => _s('Bildirimler', 'Agahdarî');
  static String get darkMode       => _s('Karanlık Mod', 'Mod Tarî');
  static String get general        => _s('Genel', 'Giştî');
  static String get chat           => _s('Sohbet', 'Sohbet');
  static String get remaining      => _s('kalan', 'maye');

  // ── HowToPlayScreen ────────────────────────────────────────────
  static String get rulesTitle   => _s('Oyun Kuralları', 'Rêzikên Lîstikê');
  static String get demoLabel      => _s('CANLI DEMO', 'DEMO ZINDÎ');
  static String get boardDemoLabel => _s('SÜRÜKLE & BIRAK', 'BIKIŞÎNE & BERDE');
  static String get validWord    => _s('Geçerli!', 'Derbasdar!');
  static String get letterValues => _s('Harf Değerleri', 'Nirxên Tîpan');

  static String get step1Title   => _s('Harfleri Yerleştir', 'Tîpan Datîne');
  static String get step1Body    => _s("Raftaki harfleri tahtaya surukle veya secip bos kareye dokun.", 'Tîpên ji reyê li ser textê bikişîne an hilbijêre û li qada vala pêk bixin.');
  static String get step2Title   => _s('Geçerli Kelime', 'Peyveke Derbasdar');
  static String get step2Body    => _s('Kürmanci kelimeler oluştur. Tüm harfler mevcut kelimelerle bitişik olmalı.', 'Peyvên Kürmancî çêke. Divê hemû tîp bi peyvên heyî re bitişik bin.');
  static String get step3Title   => _s('AI Sırasını Bekle', 'Rêza AI Bisekine');
  static String get step3Body    => _s('Sen oynarken AI da hamlesini yapar. Tahtayı stratejik kullan!', 'Dema tu dilîzî, AI jî livê xwe dike. Texteyê stratejîk bikar bîne!');
  static String get step4Title   => _s('Bonus Kareler', 'Qadên Bonus');
  static String get step4Body    => _s('2W / 3W kelime puanını, 2L / 3L harf puanını katlar. ★ merkez kare ilk hamle için zorunlu.', '2W / 3W nirxa peyvê, 2L / 3L nirxa tîpê du-sê qat dike. ★ ji bo yekem livê hewce ye.');
  static String get step5Title   => _s('Oyunu Kazan', 'Lîstikê Bibe');
  static String get step5Body    => _s('Tüm harfler bittiğinde ya da toplam 5 pas geçilince en yüksek skora sahip oyuncu kazanır.', 'Dema hemû tîp qedin an bi tevayî 5 caran derbas bibe, yê ku xalên herî zêde hebe bi ser dikeve.');

  // ── Günün Kelimesi (Wordle) ────────────────────────────────────
  static String get wordleSectionTitle => _s('Günün Kelimesi', 'Peyvê Roja');
  static String get wordleIntro        => _s('6 denemede 5 harfli Kürmancî kelimeyi bul.', 'Di 6 hewlan de peyveke 5 tîpî ya Kürmancî bibîne.');
  static String get wordleCorrectTitle => _s('Doğru Harf, Doğru Yer', 'Tîpa Rast, Cîhê Rast');
  static String get wordleCorrectBody  => _s('Harf kelimede ve tam doğru konumda.', 'Tîp di peyvê de ye û di cîhê rast de ye.');
  static String get wordlePresentTitle => _s('Kelimede Var, Yanlış Yer', 'Di Peyvê de ye, Cîhê Şaş');
  static String get wordlePresentBody  => _s('Harf kelimede var ama farklı bir konumda.', 'Tîp di peyvê de ye lê di cîhê şaş de ye.');
  static String get wordleAbsentTitle  => _s('Kelimede Yok', 'Di Peyvê de Tune');
  static String get wordleAbsentBody   => _s('Bu harf kelimede hiç yok.', 'Ev tîp di peyvê de tune ye.');
  static String get wordleTip          => _s('Her gün saat 09:00\'da yeni kelime!', 'Her roj saet 09:00 de peyveke nû!');
  static String get scrabbleSectionTitle => _s('Scrabble Modu', 'Moda Scrabble');

  static String _s(String tr, String ku) => _current == AppLocale.tr ? tr : ku;
}
