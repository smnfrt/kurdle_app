class WordNormalizer {
  const WordNormalizer._();

  /// Ferheng, oyun doğrulama ve oyun içi anlam eşleşmeleri için tek normalize
  /// noktası. Kürtçe/Türkçe karakterleri değiştirmez; yalnızca boşluğu ve
  /// büyük/küçük harf farkını standartlaştırır.
  static String normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }
}
