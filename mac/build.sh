#!/bin/bash
# Compila NetSwitch.app con il compilatore Swift incluso negli Strumenti da riga di comando
# di Xcode (nessun progetto Xcode necessario), per processori Apple Silicon (arm64).
# Uso:  ./build.sh [-o cartella_output]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT"
while getopts "o:" opt; do
  case "$opt" in
    o) OUT_DIR="$OPTARG" ;;
    *) echo "Uso: $0 [-o cartella_output]"; exit 1 ;;
  esac
done

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc non trovato. Installa gli 'Strumenti da riga di comando di Xcode' con: xcode-select --install" >&2
  exit 1
fi

APP="$OUT_DIR/NetSwitch.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "Compilazione (arm64, Apple Silicon)..."
swiftc -O \
  -target arm64-apple-macosx11.0 \
  -o "$BIN_DIR/NetSwitch" \
  "$ROOT"/src/*.swift

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

echo "Generazione icona..."
"$BIN_DIR/NetSwitch" --make-icon "$RES_DIR/AppIcon.icns" || echo "  (icona non generata: iconutil non disponibile, l'app userà l'icona generica)"

# Firma ad-hoc: senza un certificato Apple Developer non è possibile notarizzare l'app,
# ma la firma ad-hoc evita il blocco immediato di Gatekeeper per un'app compilata in locale.
echo "Firma ad-hoc..."
codesign --force --deep -s - "$APP"

echo "OK -> $APP"
echo
echo "Al primo avvio macOS potrebbe comunque chiedere conferma (Preferenze di Sistema >"
echo "Privacy e Sicurezza > 'Apri comunque'), perché l'app non è firmata con un certificato"
echo "Apple Developer né notarizzata."
