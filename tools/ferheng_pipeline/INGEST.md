# Firestore'a Ferheng Entry'lerini Yükleme

`build/out/ferheng_entries.ndjson` (4948 entry, ~2.6 MB) Firestore'a tek
seferlik yüklenmelidir. Sonraki güncellemeler için aynı script idempotent
çalışır.

## Hızlı kullanım

1. Firebase Console → Project Settings → Service Accounts →
   "Generate new private key" → JSON dosyayı indir.

2. Ortam değişkenini ayarla ve firebase-admin'i kur:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
   cd tools/ferheng_pipeline
   .venv/bin/pip install firebase-admin
   ```

3. **Önce dry-run** ile doğrula:
   ```bash
   .venv/bin/python scripts/08_firestore_ingest.py --dry-run
   ```

4. **10 entry ile test** et:
   ```bash
   .venv/bin/python scripts/08_firestore_ingest.py --limit 10
   ```
   Firebase Console → Firestore → `ferheng/` koleksiyonuna 10 doc geldiğini
   doğrula. Bir entry'i aç, schema'nın doğru olduğunu gör (definitions, prefixes).

5. **Tamamı**:
   ```bash
   .venv/bin/python scripts/08_firestore_ingest.py
   ```
   ~10 batch (her biri 500 entry) ≈ 1-2 dakika. `ferheng_meta/kmr` da yazılır.

## Sonra

- Uygulama `ferheng_meta/kmr.ferhengEnabled` kill-switch'i okur. Sorun çıkarsa
  Firebase Console'dan `false` yap → Ferheng tab gizlenir (next app start).
- Versiyon güncellemesi gerekirse `tools/ferheng_pipeline/scripts/06_emit_artifacts.py`
  içinde `VERSION` bump → `make all && make deploy-assets` → bu script'i tekrar
  koştur. Client'lar `version` mismatch görünce Hive cache'lerini temizler.

## Maliyet beklentisi

- Yazma: ~5000 doc (~5000 yazma) — bir kerelik, ücretsiz katman içinde.
- Saklama: ~7-8 MB → ücretsiz katmanın çok altında (1 GB limit).
- Okuma: Hive cache + LRU sayesinde tipik kullanıcı session'ı ~50-75 read.
  Free tier (50k/gün) ≈ 650-1000 günlük active user için yeterli.
