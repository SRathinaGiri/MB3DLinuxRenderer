#!/bin/sh
set -eu

PACKAGE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

exec "$PACKAGE_ROOT/runtime/ld-linux.so.2" \
  --library-path "$PACKAGE_ROOT/runtime" \
  "$PACKAGE_ROOT/mb3d_worker" \
  --assets "$PACKAGE_ROOT/assets" \
  "$@"
