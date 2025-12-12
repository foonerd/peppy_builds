#!/bin/bash
# peppyalsa-builds build-matrix.sh
# Build peppyalsa library and client for all architectures

set -e

VERBOSE=""

# Parse arguments
for arg in "$@"; do
  if [[ "$arg" == "--verbose" ]]; then
    VERBOSE="--verbose"
  fi
done

echo "========================================"
echo "peppyalsa Build Matrix"
echo "========================================"
echo ""

# Build for all architectures
ARCHITECTURES=("armv6" "armhf" "arm64" "amd64")

for ARCH in "${ARCHITECTURES[@]}"; do
  echo ""
  echo "----------------------------------------"
  echo "Building for: $ARCH"
  echo "----------------------------------------"
  ./docker/run-docker-peppyalsa.sh "$ARCH" $VERBOSE
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
