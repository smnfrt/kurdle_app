class KurdishMeanings {
  static const Map<String, String> _meanings = {
    'AV': 'su',
    'KITÊB': 'kitap',
    'BAJAR': 'şehir',
    'ÇAV': 'göz',
    'ŞEV': 'gece',
    'AZADÎ': 'özgürlük',
    // Conflict test: "İSTANBUL" has Turkish-only İ — should be filtered out.
    'İSTANBUL': 'İstanbul (geçersiz olmalı)',
  };
}
