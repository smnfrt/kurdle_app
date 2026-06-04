import 'package:flutter/semantics.dart';

/// Ekran-okuyucu (TalkBack/VoiceOver) anonsu için tek giriş noktası.
///
/// Çağrı yerleri (domain katmanı dahil) BuildContext taşımak zorunda kalmasın
/// diye ekran okuyucu anonsunu tek noktada topluyoruz.
void announceA11y(String message, {TextDirection textDirection = TextDirection.ltr}) {
  if (message.isEmpty) return;
  SemanticsService.announce(message, textDirection);
}
