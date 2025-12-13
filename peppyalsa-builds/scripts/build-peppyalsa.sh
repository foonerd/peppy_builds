#!/bin/bash
# peppyalsa-builds scripts/build-peppyalsa.sh
# Build script for peppyalsa library and client (runs inside Docker container)

set -e

echo "[+] Starting peppyalsa build"
echo "[+] Architecture: $ARCH"
echo "[+] Library path: $LIB_PATH"
echo "[+] Extra CFLAGS: $EXTRA_CFLAGS"
echo ""

# Directories
BUILD_BASE="/build"
SOURCE_DIR="$BUILD_BASE/peppyalsa"
OUTPUT_DIR="$BUILD_BASE/output"

mkdir -p "$OUTPUT_DIR"

#
# Step 1: Clone peppyalsa from GitHub
#
echo "[+] Cloning peppyalsa from GitHub..."
cd "$BUILD_BASE"

if [ ! -d "peppyalsa" ]; then
  git clone --depth 1 https://github.com/project-owner/peppyalsa.git
fi

cd peppyalsa

#
# Step 2: Build peppyalsa library
#
echo ""
echo "[+] Building peppyalsa library..."

# Apply architecture-specific flags
if [ -n "$EXTRA_CFLAGS" ]; then
  export CFLAGS="$EXTRA_CFLAGS -fPIC -O2"
  export CXXFLAGS="$EXTRA_CFLAGS -fPIC -O2"
fi

# Run autotools
aclocal
libtoolize --force
autoconf
automake --add-missing --force-missing

# Ensure configure is executable
chmod +x configure

# Configure with static fftw3 linking
# CRITICAL: Volumio plugins require static linking - no upstream dependencies
#
# Libtool often ignores -Bstatic flags, so we need to:
# 1. Find the static library location
# 2. Pass it directly to the linker
FFTW3_STATIC=$(find /usr -name 'libfftw3.a' 2>/dev/null | head -1)
if [ -z "$FFTW3_STATIC" ]; then
  echo "[!] ERROR: libfftw3.a not found - cannot build with static linking"
  exit 1
fi
echo "[+] Found static fftw3: $FFTW3_STATIC"

# Configure normally first
./configure --prefix=/usr/local

# Patch ALL Makefiles to use static fftw3
# Replace -lfftw3 with the full path to static library
echo "[+] Patching Makefiles for static fftw3 linking..."
find . -name 'Makefile' -exec sed -i "s|-lfftw3|$FFTW3_STATIC|g" {} \;
find . -name '*.la' -exec sed -i "s|-lfftw3|$FFTW3_STATIC|g" {} \; 2>/dev/null || true

# Build
make -j$(nproc)

# The library is built - copy to output
echo "[+] Copying library to output..."
cp -v .libs/libpeppyalsa.so* "$OUTPUT_DIR/"

# Create a tarball of the library for easy extraction
echo "[+] Creating library tarball..."
cd .libs
tar -czf "$OUTPUT_DIR/peppyalsa-lib.tar.gz" libpeppyalsa.so*
cd "$BUILD_BASE/peppyalsa"

#
# Step 3: Build peppyalsa-client
#
echo ""
echo "[+] Building peppyalsa-client..."
cd src

# Fix the FIFO path in source
if grep -q '/home/pi/myfifo' peppyalsa-client.c; then
  sed -i 's|/home/pi/myfifo|/tmp/myfifo|g' peppyalsa-client.c
fi

# Compile the client
gcc $CFLAGS -o peppyalsa-client peppyalsa-client.c

# Strip the binary
strip peppyalsa-client

# Copy to output
cp -v peppyalsa-client "$OUTPUT_DIR/"

#
# Step 4: Show results
#
echo ""
echo "[+] Build complete"
echo "[+] Output files:"
ls -lh "$OUTPUT_DIR"

# Verify the library
echo ""
echo "[+] Library info:"
file "$OUTPUT_DIR/libpeppyalsa.so"* 2>/dev/null || true

echo ""
echo "[+] Checking library dependencies (should NOT show libfftw3):"
ldd "$OUTPUT_DIR/libpeppyalsa.so" 2>/dev/null || true
if ldd "$OUTPUT_DIR/libpeppyalsa.so" 2>/dev/null | grep -q fftw3; then
  echo "[!] WARNING: libfftw3 is dynamically linked - this will break on Volumio!"
  exit 1
else
  echo "[+] OK: libfftw3 is statically linked"
fi

echo ""
echo "[+] Client info:"
file "$OUTPUT_DIR/peppyalsa-client"
