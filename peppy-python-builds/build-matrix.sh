#!/bin/bash
# peppy-python-builds build-matrix.sh
# Build Python packages for peppy_screensaver for all architectures

set -e

VERBOSE=""

# Parse arguments
for arg in "$@"; do
  if [[ "$arg" == "--verbose" ]]; then
    VERBOSE="--verbose"
  fi
done

echo "========================================"
echo "Peppy Python Packages Build Matrix"
echo "========================================"
echo "Target: Python 3.11 (Bookworm)"
echo ""

# Build for all architectures
ARCHITECTURES=("armv6" "armhf" "arm64" "amd64")

for ARCH in "${ARCHITECTURES[@]}"; do
  echo ""
  echo "----------------------------------------"
  echo "Building for: $ARCH"
  echo "----------------------------------------"
  ./docker/run-docker-python.sh "$ARCH" $VERBOSE
done

echo ""
echo "========================================"
echo "Build Matrix Complete"
echo "========================================"
echo ""
echo "Output structure:"
for ARCH in "${ARCHITECTURES[@]}"; do
  if [ -d "out/$ARCH" ]; then
    echo "  out/$ARCH/"
    ls -lh "out/$ARCH/" 2>/dev/null | tail -n +2 | awk '{printf "    %s  %s\n", $9, $5}'
  fi
done
