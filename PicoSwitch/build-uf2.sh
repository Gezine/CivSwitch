#!/bin/bash
# build-uf2.sh — rebuild the PicoSwitch UF2 with your own options/payload.
#
# Usage:
#   bash build-uf2.sh [--board pico1|pico2|both] [--layout us|jis]
#                     [--ime none|grave|grave-each-line]
#                     [--payload path/to/payload.js]
#
# Defaults: --board both --layout jis --ime grave-each-line (the
# combination verified on real hardware with a Japanese console).
# For --layout us the IME option is forced to none.
# The default payload is this repository's core.js (the ipfix3 loader).
#
# Requirements: Pico SDK 2.3.1 at ~/pico-sdk (or $PICO_SDK_PATH),
# arm-none-eabi-gcc + ninja in PATH, node + npm, python3, cmake.
# Output: PicoSwitch/out/civ7-<board>-<layout>[-ime].uf2
set -euo pipefail
cd "$(dirname "$0")"          # PicoSwitch/
REPO_ROOT="$(cd .. && pwd)"   # repository root (core.js lives here)

BOARD=both
LAYOUT=jis
IME=grave-each-line
PAYLOAD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --board)   BOARD="$2"; shift 2 ;;
    --layout)  LAYOUT="$2"; shift 2 ;;
    --ime)     IME="$2"; shift 2 ;;
    --payload) PAYLOAD="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ "$LAYOUT" = us ] && IME=none
case "$IME" in none|grave|grave-each-line) ;; *) echo "bad --ime: $IME" >&2; exit 2 ;; esac
case "$LAYOUT" in us|jis) ;; *) echo "bad --layout: $LAYOUT" >&2; exit 2 ;; esac

export PICO_SDK_PATH="${PICO_SDK_PATH:-$HOME/pico-sdk}"
[ -d "$PICO_SDK_PATH" ] || {
  echo "Pico SDK not found at $PICO_SDK_PATH" >&2
  echo "Get it with:" >&2
  echo "  git clone --branch 2.3.1 --depth 1 --recurse-submodules --shallow-submodules https://github.com/raspberrypi/pico-sdk.git ~/pico-sdk" >&2
  exit 1
}
for t in arm-none-eabi-gcc ninja cmake node npm python3; do
  command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done

# Scratch copy of the repository tree (the checked-out tree stays pristine).
BUILD=.build
rm -rf "$BUILD"
mkdir -p "$BUILD/src"
( cd "$REPO_ROOT" && tar --exclude=.git --exclude=PicoSwitch/.build --exclude='PicoSwitch/build-*' -cf - . ) \
  | ( cd "$BUILD/src" && tar -xf - )
chmod +x "$BUILD/src/PicoSwitch/tools/"*.py   # zip extraction drops +x
if [ -n "$PAYLOAD" ]; then
  cp "$PAYLOAD" "$BUILD/src/core.js"
  echo "payload: $PAYLOAD"
else
  echo "payload: core.js (this repository's loader)"
fi

cd "$BUILD/src/PicoSwitch"
npm install --no-audit --no-fund >/dev/null
node compress.js
cd - >/dev/null

mkdir -p out
build_one() {
  local preset="$1"
  ( cd "$BUILD/src/PicoSwitch" \
    && cmake --preset "$preset" \
         -DCIV7_KEYBOARD_LAYOUT="$LAYOUT" -DCIV7_IME_START="$IME" >/dev/null \
    && cmake --build --preset "$preset" )
  local suffix="$LAYOUT"
  [ "$IME" != none ] && suffix="$LAYOUT-ime"
  cp "$BUILD/src/PicoSwitch/build-$preset/src/civ7-$preset.uf2" \
     "out/civ7-$preset-$suffix.uf2"
  echo "built: out/civ7-$preset-$suffix.uf2"
}
case "$BOARD" in
  pico1) build_one pico1 ;;
  pico2) build_one pico2 ;;
  both)  build_one pico2; build_one pico1 ;;
  *) echo "bad --board: $BOARD" >&2; exit 2 ;;
esac
echo "done. Flash with BOOTSEL + copy, like any Pico UF2."
