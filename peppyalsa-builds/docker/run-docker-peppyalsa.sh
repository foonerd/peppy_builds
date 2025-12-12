#!/bin/bash
# peppyalsa-builds docker/run-docker-peppyalsa.sh
# Core Docker build logic for peppyalsa library and client

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

VERBOSE=0

# Parse arguments
ARCH="$1"
shift || true

for arg in "$@"; do
  if [[ "$arg" == "--verbose" ]]; then
    VERBOSE=1
  fi
done

# Show usage if missing required parameters
if [ -z "$ARCH" ]; then
  echo "Usage: $0 <arch> [--verbose]"
  echo ""
  echo "Arguments:"
  echo "  arch: armv6, armhf, arm64, amd64"
  echo "  --verbose: Show detailed build output"
  echo ""
  echo "Example:"
  echo "  $0 arm64"
  echo "  $0 armv6 --verbose"
  exit 1
fi

# Platform mappings for Docker
declare -A PLATFORM_MAP
PLATFORM_MAP=(
  ["armv6"]="linux/arm/v7"
  ["armhf"]="linux/arm/v7"
  ["arm64"]="linux/arm64"
  ["amd64"]="linux/amd64"
)

# Library path mappings
declare -A LIB_PATH_MAP
LIB_PATH_MAP=(
  ["armv6"]="/usr/lib/arm-linux-gnueabihf"
  ["armhf"]="/usr/lib/arm-linux-gnueabihf"
  ["arm64"]="/usr/lib/aarch64-linux-gnu"
  ["amd64"]="/usr/lib/x86_64-linux-gnu"
)

# Validate architecture
if [[ -z "${PLATFORM_MAP[$ARCH]}" ]]; then
  echo "Error: Unknown architecture: $ARCH"
  echo "Supported: armv6, armhf, arm64, amd64"
  exit 1
fi

PLATFORM="${PLATFORM_MAP[$ARCH]}"
LIB_PATH="${LIB_PATH_MAP[$ARCH]}"
DOCKERFILE="docker/Dockerfile.peppyalsa.$ARCH"
IMAGE_NAME="peppyalsa-builder:$ARCH"
OUTPUT_DIR="out/$ARCH"

if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: Dockerfile not found: $DOCKERFILE"
  exit 1
fi

echo "========================================"
echo "Building peppyalsa for $ARCH"
echo "========================================"
echo "  Platform: $PLATFORM"
echo "  Lib Path: $LIB_PATH"
echo "  Dockerfile: $DOCKERFILE"
echo "  Image: $IMAGE_NAME"
echo "  Output: $OUTPUT_DIR"
echo ""

# Build Docker image with platform flag
echo "[+] Building Docker image..."
if [[ "$VERBOSE" -eq 1 ]]; then
  DOCKER_BUILDKIT=1 docker build --platform=$PLATFORM --progress=plain -t "$IMAGE_NAME" -f "$DOCKERFILE" .
else
  docker build --platform=$PLATFORM --progress=auto -t "$IMAGE_NAME" -f "$DOCKERFILE" . > /dev/null 2>&1
fi
echo "[+] Docker image built: $IMAGE_NAME"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Architecture-specific CFLAGS
EXTRA_CFLAGS=""
if [[ "$ARCH" == "armv6" ]]; then
  EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -marm"
elif [[ "$ARCH" == "armhf" ]]; then
  EXTRA_CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard"
elif [[ "$ARCH" == "arm64" ]]; then
  EXTRA_CFLAGS="-march=armv8-a"
fi

# Run build inside container
echo "[+] Running build inside container..."
if [[ "$VERBOSE" -eq 1 ]]; then
  docker run --rm --platform=$PLATFORM \
    -v "$(pwd)/scripts:/build/scripts:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/build/output" \
    -e "ARCH=$ARCH" \
    -e "LIB_PATH=$LIB_PATH" \
    -e "EXTRA_CFLAGS=$EXTRA_CFLAGS" \
    "$IMAGE_NAME" \
    bash /build/scripts/build-peppyalsa.sh
else
  docker run --rm --platform=$PLATFORM \
    -v "$(pwd)/scripts:/build/scripts:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/build/output" \
    -e "ARCH=$ARCH" \
    -e "LIB_PATH=$LIB_PATH" \
    -e "EXTRA_CFLAGS=$EXTRA_CFLAGS" \
    "$IMAGE_NAME" \
    bash /build/scripts/build-peppyalsa.sh 2>&1 | grep -E "^\[|^Error|^Building|warning:"
fi

echo ""
echo "[+] Build complete for $ARCH"
echo "[+] Output in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
