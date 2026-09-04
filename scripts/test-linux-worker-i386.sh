#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FPC_BIN=${FPC_BIN:-fpc}
OUT_DIR="$ROOT/build/linux-i386-tests"

mkdir -p "$OUT_DIR"
for TEST_NAME in test_headless_fog test_headless_ambient_shadow test_headless_reflection; do
  "$FPC_BIN" -Pi386 -dMB3D_HEADLESS -Mdelphi -O2 \
    -Fu"$ROOT" -Fu"$ROOT/core" -FE"$OUT_DIR" -FU"$OUT_DIR" \
    "$ROOT/tests/$TEST_NAME.lpr"
  "$OUT_DIR/$TEST_NAME"
done
