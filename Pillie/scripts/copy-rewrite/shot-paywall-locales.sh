#!/usr/bin/env bash
set -euo pipefail

UDID="${PILLIE_SIMULATOR_UDID:-124DC75F-0771-4C81-841D-F13655138260}"
BUNDLE="com.idrisskone.pillie"
OUT="${1:-/tmp/pillie-paywall-l10n}"
BOARD="${2:-c1}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

LANGS=(
  en de it
  fr es pt-BR pt-PT nl ca da sv nb fi
  pl cs sk hr sl hu ro el tr
  ru uk ar he
  hi bn ur gu pa mr or ta te kn ml
  id ms vi th ja ko zh-Hans zh-Hant
)

mkdir -p "$OUT/$BOARD"

url_for() {
  local lang="$1"
  case "$BOARD" in
    c1) echo "pillie://debug/honest-paywall?board=c1&lang=${lang}" ;;
    c3) echo "pillie://debug/honest-paywall?board=c3&lang=${lang}" ;;
    c2) echo "pillie://debug/trial-end-paywall?cohort=blocker&terms=hard&lang=${lang}" ;;
    *) echo "unknown board $BOARD" >&2; exit 1 ;;
  esac
}

if [[ "$BOARD" == "c2" ]]; then
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 0.4
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep 1.2
fi

for lang in "${LANGS[@]}"; do
  if [[ "$BOARD" == "c2" ]]; then
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    sleep 0.25
    defaults write "$BUNDLE" pillie.appLanguage "$lang"
    xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
    sleep 1.0
  fi
  xcrun simctl openurl "$UDID" "$(url_for "$lang")"
  sleep 1.3
  xcrun simctl io "$UDID" screenshot "$OUT/$BOARD/${lang}.png" >/dev/null
  echo "$BOARD $lang"
done

# Labeled thumbs, then a contact sheet.
THUMBS="$OUT/$BOARD/thumbs"
mkdir -p "$THUMBS"
for lang in "${LANGS[@]}"; do
  magick "$OUT/$BOARD/${lang}.png" -resize 240x \
    -font /System/Library/Fonts/Helvetica.ttc -gravity south -background '#111111' -fill white -splice 0x28 \
    -annotate +0+6 "$lang" "$THUMBS/${lang}.png"
done

THUMB_FILES=()
for lang in "${LANGS[@]}"; do
  THUMB_FILES+=("$THUMBS/${lang}.png")
done
magick montage "${THUMB_FILES[@]}" -tile 9x -geometry +8+8 -background '#0b0b0b' \
  "$OUT/${BOARD}-sheet.png"
echo "wrote $OUT/${BOARD}-sheet.png"
