import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Ekran-okuyucu (TalkBack/VoiceOver) anonsu için tek giriş noktası.
///
/// Flutter 3.36+ `SemanticsService.announce` deprecated edildi (çoklu-pencere
/// uyumu için artık bir [FlutterView] istiyor). Peyvok tek-pencereli olduğundan
/// implicit view'i kullanıp bu detayı tek yerde sarmalıyoruz — çağrı yerleri
/// (domain katmanı dahil) BuildContext taşımak zorunda kalmaz.
void announceA11y(String message, {TextDirection textDirection = TextDirection.ltr}) {
  if (message.isEmpty) return;
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view == null) return;
  SemanticsService.sendAnnouncement(view, message, textDirection);
}
