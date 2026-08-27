#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FPC_BIN=${FPC_BIN:-fpc}
OUT_DIR="$ROOT/build/linux-i386"

command -v "$FPC_BIN" >/dev/null 2>&1 || {
  echo "Free Pascal compiler not found. Install fpc or set FPC_BIN." >&2
  exit 1
}

mkdir -p "$OUT_DIR"
"$FPC_BIN" -Pi386 -dMB3D_HEADLESS -Mdelphi -O2 -Fu"$ROOT" -Fu"$ROOT/core" -Fu"$ROOT/maps" \
  -FE"$OUT_DIR" -FU"$OUT_DIR" "$ROOT/headless/mb3d_worker.lpr"
echo "Built $OUT_DIR/mb3d_worker"
