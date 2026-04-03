#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$PROJECT_DIR/build/DerivedDataSimNoSign/Build/Products/Debug-iphonesimulator/MeuLabApp.app"
OUT_DIR="$PROJECT_DIR/Screenshots/apple-silicon"
UDID="${1:-06538A1A-5DFD-4408-80D7-3672D91AD21A}"
BUNDLE_ID="fun.meulab.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App nao encontrado em: $APP_PATH"
  echo "Execute primeiro o build Apple Silicon de simulador."
  exit 1
fi

mkdir -p "$OUT_DIR"

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP_PATH"

xcrun simctl status_bar "$UDID" clear || true
xcrun simctl status_bar "$UDID" override \
  --time 9:41 \
  --dataNetwork wifi \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100

tabs=(adsb satellite system radio alerts weather map)

for tab in "${tabs[@]}"; do
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  SIMCTL_CHILD_MEULAB_INITIAL_TAB="$tab" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/${tab}.png"
done

xcrun simctl status_bar "$UDID" clear || true
echo "Screenshots gerados em: $OUT_DIR"
