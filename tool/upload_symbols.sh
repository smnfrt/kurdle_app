#!/usr/bin/env bash
# Peyvok — Release build + Crashlytics symbol upload
#
# Kullanım:
#   tool/upload_symbols.sh
#
# Bu script:
# 1. Release build alır (--obfuscate + --split-debug-info=build/symbols)
# 2. NDK symbol'leri Gradle plugin tarafından otomatik upload edilir
#    (build.gradle'da nativeSymbolUploadEnabled true ayarı sağlar)
# 3. Dart obfuscation symbol'leri build/symbols/ altında saklanır —
#    Crashlytics'te bir crash gördüğünde:
#       flutter symbolize -i <stacktrace.txt> -d build/symbols/app.android-arm64.symbols
#    şeklinde decode edersin. Symbols klasörünü her release için ayrı arşivle.
#
# Firebase App ID (Android): 1:221162003973:android:0879ecda03ae1c0b66866c

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SYMBOLS_DIR="build/symbols"
FLUTTER="${FLUTTER:-/Users/leyar/development/flutter/bin/flutter}"

echo "==> Cleaning previous symbols"
rm -rf "$SYMBOLS_DIR"
mkdir -p "$SYMBOLS_DIR"

echo "==> Building release APK with split-debug-info and obfuscation"
"$FLUTTER" build apk \
  --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR"

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
ARCHIVE="build/symbols-${VERSION}.tar.gz"

echo "==> Archiving symbols → $ARCHIVE"
tar -czf "$ARCHIVE" -C build symbols

echo ""
echo "✓ Release APK: build/app/outputs/flutter-apk/app-release.apk"
echo "✓ Symbols archived: $ARCHIVE"
echo ""
echo "Crashlytics dashboard'da garbled Dart stack görürsen:"
echo "  $FLUTTER symbolize -i <stack.txt> -d $SYMBOLS_DIR/app.android-arm64.symbols"
echo ""
echo "NDK symbol upload Gradle plugin tarafından otomatik yapıldı."
echo "Manuel upload gerekirse:"
echo "  firebase crashlytics:symbols:upload \\"
echo "    --app=1:221162003973:android:0879ecda03ae1c0b66866c \\"
echo "    <NDK-symbols-dir>"
