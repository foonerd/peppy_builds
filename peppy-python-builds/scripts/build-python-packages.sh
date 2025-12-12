#!/bin/bash
# peppy-python-builds scripts/build-python-packages.sh
# Build Python packages for peppy_screensaver (runs inside Docker container)

set -e

echo "[+] Starting Python packages build"
echo "[+] Architecture: $ARCH"
echo "[+] Library path: $LIB_PATH"
echo "[+] Python version: $(python3 --version)"
echo ""

# Directories
BUILD_BASE="/build"
VENV_DIR="$BUILD_BASE/venv"
PACKAGES_DIR="$BUILD_BASE/packages"
OUTPUT_DIR="$BUILD_BASE/output"

mkdir -p "$PACKAGES_DIR"
mkdir -p "$OUTPUT_DIR"

# Apply architecture-specific flags
if [ -n "$EXTRA_CFLAGS" ]; then
  export CFLAGS="$EXTRA_CFLAGS"
  export CXXFLAGS="$EXTRA_CFLAGS"
fi

#
# Step 1: Create virtual environment for clean builds
#
echo "[+] Creating virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Upgrade pip and install wheel
pip install --upgrade pip wheel setuptools

#
# Step 2: Install packages with compilation
#
echo ""
echo "[+] Installing Python packages..."

# Package versions - these are compatible with Python 3.11 and socket.io v4
PYGAME_VERSION="2.5.2"
SOCKETIO_VERSION="5.11.0"
ENGINEIO_VERSION="4.9.0"
PILLOW_VERSION="10.2.0"
CAIROSVG_VERSION="2.7.1"
PYSCREENSHOT_VERSION="3.1"

# Install packages
echo "[+] Installing pygame==$PYGAME_VERSION..."
pip install pygame==$PYGAME_VERSION

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

# Also install requests (dependency used in albumart fetching)
echo "[+] Installing requests..."
pip install requests

#
# Step 3: Copy installed packages to packages directory
#
echo ""
echo "[+] Copying packages to staging area..."

# Get site-packages location
SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
echo "[+] Site packages: $SITE_PACKAGES"

# Copy all installed packages (excluding pip, setuptools, wheel, pkg_resources)
cd "$SITE_PACKAGES"
for pkg in pygame socketio engineio PIL cairosvg pyscreenshot requests urllib3 certifi charset_normalizer idna; do
  if [ -d "$pkg" ]; then
    echo "  Copying $pkg/"
    cp -r "$pkg" "$PACKAGES_DIR/"
  fi
done

# Also copy dist-info directories for package metadata
for pkg in pygame python_socketio python_engineio pillow cairosvg pyscreenshot requests urllib3 certifi charset_normalizer idna; do
  for info in ${pkg}*.dist-info; do
    if [ -d "$info" ]; then
      echo "  Copying $info/"
      cp -r "$info" "$PACKAGES_DIR/"
    fi
  done
done

# Copy additional dependencies that may be needed
for pkg in bidict cssselect2 defusedxml tinycss2 webencodings EasyProcess entrypoint2 mss; do
  if [ -d "$pkg" ]; then
    echo "  Copying $pkg/"
    cp -r "$pkg" "$PACKAGES_DIR/"
  fi
  # Also copy lowercase version
  pkg_lower=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')
  if [ -d "$pkg_lower" ]; then
    echo "  Copying $pkg_lower/"
    cp -r "$pkg_lower" "$PACKAGES_DIR/"
  fi
done

#
# Step 4: Strip .so files to reduce size
#
echo ""
echo "[+] Stripping debug symbols from .so files..."
find "$PACKAGES_DIR" -name "*.so" -type f -exec strip --strip-debug {} \; 2>/dev/null || true
find "$PACKAGES_DIR" -name "*.so.*" -type f -exec strip --strip-debug {} \; 2>/dev/null || true

#
# Step 5: Clean unnecessary files
#
echo "[+] Cleaning unnecessary files..."

# Remove __pycache__ directories
find "$PACKAGES_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Remove .pyc files
find "$PACKAGES_DIR" -name "*.pyc" -type f -delete 2>/dev/null || true

# Remove test directories
find "$PACKAGES_DIR" -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
find "$PACKAGES_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true

# Remove documentation
find "$PACKAGES_DIR" -name "*.md" -type f -delete 2>/dev/null || true
find "$PACKAGES_DIR" -name "README*" -type f -delete 2>/dev/null || true
find "$PACKAGES_DIR" -name "CHANGELOG*" -type f -delete 2>/dev/null || true

#
# Step 6: Create tarball
#
echo ""
echo "[+] Creating packages tarball..."

cd "$PACKAGES_DIR"
TARBALL_NAME="peppy-python-packages.tar.gz"
tar -czf "$OUTPUT_DIR/$TARBALL_NAME" .

#
# Step 7: Show results
#
echo ""
echo "[+] Build complete"
echo "[+] Output files:"
ls -lh "$OUTPUT_DIR"

echo ""
echo "[+] Package contents:"
tar -tzf "$OUTPUT_DIR/$TARBALL_NAME" | head -50
echo "..."

echo ""
echo "[+] Total size:"
du -sh "$OUTPUT_DIR/$TARBALL_NAME"

# Deactivate virtual environment
deactivate
