#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

echo "Cleaning build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Prefer cmake on PATH, otherwise fallback to CMake.app on macOS
if command -v cmake >/dev/null 2>&1; then
  CMAKE_CMD="cmake"
else
  CMAKE_CMD="/Applications/CMake.app/Contents/bin/cmake"
fi

echo "Using CMake: $CMAKE_CMD"

pushd "$BUILD_DIR" >/dev/null

echo "Configuring with CMake..."
"$CMAKE_CMD" .. -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

echo "Building..."
"$CMAKE_CMD" --build . --config Release

echo "Running tests (ctest)..."
# Prefer ctest on PATH, otherwise try CMake's ctest
if command -v ctest >/dev/null 2>&1; then
  CTEST_CMD="ctest"
else
  CTEST_CMD="$CMAKE_CMD --build . --target test --config Release && $CMAKE_CMD -E echo 'ctest not available; used CMake test target instead'"
fi

if [ "$CTEST_CMD" = "ctest" ]; then
  ctest --output-on-failure
else
  # run the fallback CMake test target
  eval "$CTEST_CMD"
fi

popd >/dev/null

echo "CI script completed successfully."