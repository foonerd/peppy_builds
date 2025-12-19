#!/bin/bash
# build-python-native-pi.sh
# Native build of Python packages for peppy_screensaver on Raspberry Pi
# Run this directly on Pi 4/5 to get NEON-optimized pygame
#
# Usage: sudo bash build-python-native-pi.sh
#
# Output: ./peppy-python-packages.tar.gz

set -e

echo "========================================"
echo "Peppy Python Packages - Native Pi Build"
echo "========================================"
echo ""

# Check if running on Pi
if ! grep -q "Raspberry Pi\|BCM" /proc/cpuinfo 2>/dev/null; then
    echo "WARNING: This doesn't appear to be a Raspberry Pi"
    echo "Continue anyway? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for root/sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script needs sudo to install dependencies."
    echo "Please run: sudo bash $0"
    exit 1
fi

# Directories
BUILD_BASE="/tmp/peppy-build"
VENV_DIR="$BUILD_BASE/venv"
PACKAGES_DIR="$BUILD_BASE/packages"
OUTPUT_DIR="$(pwd)"

# Clean previous build
rm -rf "$BUILD_BASE"
mkdir -p "$BUILD_BASE"
mkdir -p "$PACKAGES_DIR"

echo "[+] Installing build dependencies..."
apt-get update
apt-get install -y \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-wheel \
    python3-setuptools \
    build-essential \
    pkg-config \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-mixer-dev \
    libsdl2-ttf-dev \
    libfreetype6-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf2.0-dev \
    librsvg2-dev

echo ""
echo "[+] Python version: $(python3 --version)"
echo ""

#
# Step 1: Create virtual environment
#
echo "[+] Creating virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Pin setuptools to avoid build issues
pip install --upgrade pip wheel "setuptools<70"

#
# Step 2: Install packages
#
echo ""
echo "[+] Installing Python packages..."

# Package versions
SOCKETIO_VERSION="5.11.0"
ENGINEIO_VERSION="4.9.0"
PILLOW_VERSION="10.2.0"
CAIROSVG_VERSION="2.7.1"
PYSCREENSHOT_VERSION="3.1"

# Extract pygame from Debian package (has NEON optimization)
echo "[+] Installing pygame from Debian package (NEON optimized)..."
apt download python3-pygame
dpkg -x python3-pygame*.deb /tmp/pygame-deb-extract
cp -r /tmp/pygame-deb-extract/usr/lib/python3/dist-packages/pygame "$VENV_DIR/lib/python3.11/site-packages/"
rm -f python3-pygame*.deb
rm -rf /tmp/pygame-deb-extract

# Verify NEON support (no warning = success)
echo ""
echo "[+] Verifying NEON support..."
if PYTHONPATH="$VENV_DIR/lib/python3.11/site-packages" python3 -c "import pygame; pygame.init()" 2>&1 | grep -q "neon capable"; then
    echo "ERROR: NEON not enabled!"
    exit 1
else
    echo "NEON support: OK"
fi
echo ""

echo "[+] Installing python-socketio==$SOCKETIO_VERSION..."
pip install python-socketio==$SOCKETIO_VERSION

echo "[+] Installing python-engineio==$ENGINEIO_VERSION..."
pip install python-engineio==$ENGINEIO_VERSION

echo "[+] Installing Pillow==$PILLOW_VERSION..."
pip install Pillow==$PILLOW_VERSION

echo "[+] Installing cairosvg==$CAIROSVG_VERSION..."
pip install cairosvg==$CAIROSVG_VERSION

echo "[+] Installing pyscreenshot==$PYSCREENSHOT_VERSION..."
pip install pyscreenshot==$PYSCREENSHOT_VERSION

echo "[+] Installing requests..."
pip install requests

echo "[+] Installing websocket-client..."
pip install websocket-client

#
# Step 3: Copy packages
#
echo ""
echo "[+] Copying packages to staging area..."

SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
echo "[+] Site packages: $SITE_PACKAGES"

cd "$SITE_PACKAGES"
for pkg in pygame socketio engineio PIL cairosvg pyscreenshot requests urllib3 certifi charset_normalizer idna websocket; do
    if [ -d "$pkg" ]; then
        echo "  Copying $pkg/"
        cp -r "$pkg" "$PACKAGES_DIR/"
    fi
done

# Copy .libs directories (bundled libraries)
for libdir in pygame.libs pillow.libs; do
    if [ -d "$libdir" ]; then
        echo "  Copying $libdir/"
        cp -r "$libdir" "$PACKAGES_DIR/"
    fi
done

# Copy dist-info directories
for pkg in pygame python_socketio python_engineio pillow cairosvg pyscreenshot requests urllib3 certifi charset_normalizer idna websocket_client; do
    for info in ${pkg}*.dist-info; do
        if [ -d "$info" ]; then
            echo "  Copying $info/"
            cp -r "$info" "$PACKAGES_DIR/"
        fi
    done
done

# Copy additional dependencies
for pkg in bidict cssselect2 defusedxml tinycss2 webencodings EasyProcess entrypoint2 mss; do
    if [ -d "$pkg" ]; then
        echo "  Copying $pkg/"
        cp -r "$pkg" "$PACKAGES_DIR/"
    fi
    pkg_lower=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')
    if [ -d "$pkg_lower" ]; then
        echo "  Copying $pkg_lower/"
        cp -r "$pkg_lower" "$PACKAGES_DIR/"
    fi
done

#
# Step 4: Strip and clean
#
echo ""
echo "[+] Stripping debug symbols..."
find "$PACKAGES_DIR" -name "*.so" -type f -exec strip --strip-debug {} \; 2>/dev/null || true
find "$PACKAGES_DIR" -name "*.so.*" -type f -exec strip --strip-debug {} \; 2>/dev/null || true

echo "[+] Cleaning unnecessary files..."
find "$PACKAGES_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$PACKAGES_DIR" -name "*.pyc" -type f -delete 2>/dev/null || true
find "$PACKAGES_DIR" -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
find "$PACKAGES_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find "$PACKAGES_DIR" -name "*.md" -type f -delete 2>/dev/null || true
find "$PACKAGES_DIR" -name "README*" -type f -delete 2>/dev/null || true

#
# Step 5: Create tarball
#
echo ""
echo "[+] Creating packages tarball..."

cd "$PACKAGES_DIR"
TARBALL_NAME="peppy-python-packages.tar.gz"
tar -czf "$OUTPUT_DIR/$TARBALL_NAME" .

# Deactivate venv
deactivate

#
# Step 6: Results
#
echo ""
echo "========================================"
echo "Build Complete"
echo "========================================"
echo ""
echo "Output: $OUTPUT_DIR/$TARBALL_NAME"
ls -lh "$OUTPUT_DIR/$TARBALL_NAME"
echo ""
echo "Package contents:"
tar -tzf "$OUTPUT_DIR/$TARBALL_NAME" | grep -E "^pygame/|^PIL/|^socketio/" | head -20
echo "..."
echo ""
echo "To install on target system:"
echo "  mkdir -p /data/plugins/user_interface/peppy_screensaver/lib/arm/python"
echo "  tar -xzf $TARBALL_NAME -C /data/plugins/user_interface/peppy_screensaver/lib/arm/python"
echo ""

# Cleanup
rm -rf "$BUILD_BASE"

echo "[+] Done!"
