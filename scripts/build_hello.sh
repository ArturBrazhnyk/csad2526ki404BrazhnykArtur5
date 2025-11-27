#!/usr/bin/env bash
set -euo pipefail

# Build project using existing helper and produce build/hello
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

echo "Building project (clean) using scripts/rebuild.sh..."
"$ROOT_DIR/scripts/rebuild.sh"

echo "Locating built executable in $BUILD_DIR..."
EXE=""
# Portable search for an executable regular file in the build directory.
# Some variants of `find` on macOS don't support `-perm /111`, so test -x instead.
for f in "$BUILD_DIR"/*; do
  # skip non-existing matches (in case the glob didn't expand)
  [ -e "$f" ] || continue
  # must be a regular file and executable
  if [ ! -f "$f" ] || [ ! -x "$f" ]; then
    continue
  fi
  bn=$(basename "$f")
  # skip known non-main binaries
  case "$bn" in
    unit_tests|libmath_operations.a) continue ;;
  esac
  EXE="$f"
  break
done

if [ -z "$EXE" ]; then
  echo "No suitable executable found in $BUILD_DIR" >&2
  echo "Listing build directory for debugging:" >&2
  ls -la "$BUILD_DIR" >&2
  exit 1
fi

DEST_BIN="$BUILD_DIR/hello"
echo "Copying '$EXE' -> '$DEST_BIN'"
cp "$EXE" "$DEST_BIN"
chmod +x "$DEST_BIN"

echo "Done. Created: $DEST_BIN"
echo "Run it with: $DEST_BIN"
