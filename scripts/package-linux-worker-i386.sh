#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PACKAGE_NAME=${PACKAGE_NAME:-mb3d-worker-linux-i386}
OUT_DIR=${OUT_DIR:-"$ROOT/dist"}
WORKER="$ROOT/build/linux-i386/mb3d_worker"

cleanup() {
  if [ -n "${PACKAGE_TMP:-}" ] && [ -d "$PACKAGE_TMP" ]; then
    rm -rf -- "$PACKAGE_TMP"
  fi
}

trap cleanup EXIT HUP INT TERM

sh "$ROOT/scripts/build-linux-worker-i386.sh"

LOADER=$(readlink -f /lib/ld-linux.so.2)
LIBC=$(ldd "$WORKER" | awk '$1 == "libc.so.6" { print $3; exit }')
LIBPTHREAD=$(find /lib/i386-linux-gnu /usr/lib/i386-linux-gnu \
  -maxdepth 1 -name 'libpthread.so.0' -type f 2>/dev/null | head -n 1)
LIBGCC=$(find /lib/i386-linux-gnu /usr/lib/i386-linux-gnu \
  -maxdepth 1 -name 'libgcc_s.so.1' -type f 2>/dev/null | head -n 1)

if [ ! -f "$LOADER" ] || [ -z "$LIBC" ] || [ ! -f "$LIBC" ] || \
   [ -z "$LIBPTHREAD" ] || [ ! -f "$LIBPTHREAD" ]; then
  echo "Could not locate the required i386 Linux runtime files." >&2
  exit 1
fi

if [ -z "$LIBGCC" ] || [ ! -f "$LIBGCC" ]; then
  echo "Could not locate the i386 GCC unwinding runtime." >&2
  exit 1
fi

PACKAGE_TMP=$(mktemp -d)
PACKAGE_ROOT="$PACKAGE_TMP/$PACKAGE_NAME"
mkdir -p "$PACKAGE_ROOT/runtime" "$OUT_DIR"

cp "$WORKER" "$PACKAGE_ROOT/mb3d_worker"
cp "$ROOT/scripts/run-mb3d-worker.sh" "$PACKAGE_ROOT/run-mb3d-worker"
cp "$LOADER" "$PACKAGE_ROOT/runtime/ld-linux.so.2"
cp "$LIBC" "$PACKAGE_ROOT/runtime/libc.so.6"
cp "$LIBPTHREAD" "$PACKAGE_ROOT/runtime/libpthread.so.0"
cp "$LIBGCC" "$PACKAGE_ROOT/runtime/libgcc_s.so.1"
cp -R "$ROOT/assets" "$PACKAGE_ROOT/assets"
cp "$ROOT/docs/headless-renderer.md" "$PACKAGE_ROOT/README.md"

chmod 0755 "$PACKAGE_ROOT/mb3d_worker" \
  "$PACKAGE_ROOT/run-mb3d-worker" \
  "$PACKAGE_ROOT/runtime/ld-linux.so.2"

ARCHIVE="$OUT_DIR/$PACKAGE_NAME.tar.gz"
tar -C "$PACKAGE_TMP" -czf "$ARCHIVE" "$PACKAGE_NAME"
(
  cd "$OUT_DIR"
  sha256sum "$PACKAGE_NAME.tar.gz" > "$PACKAGE_NAME.tar.gz.sha256"
)

echo "Packaged $ARCHIVE"
echo "Checksum $ARCHIVE.sha256"
