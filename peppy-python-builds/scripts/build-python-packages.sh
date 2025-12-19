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
# Pin setuptools < 70 to avoid distutils.ccompiler.spawn issue with pygame build
pip install --upgrade pip wheel "setuptools<70"

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
echo "[+] Installing pygame==$PYGAME_VERSION (building from source with SIMD optimizations)..."
# Build from source to enable NEON (ARM) / SSE/AVX (x86) optimizations
# Pre-built manylinux wheels disable these for maximum compatibility
# Use --no-build-isolation to use our pinned setuptools (pip's isolated build env ignores it)
export PYGAME_DETECT_AVX2=1
pip install cython  # pygame build dependency
pip install pygame==$PYGAME_VERSION --no-binary pygame --no-build-isolation

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

# Install websocket-client (required for python-socketio websocket transport)
echo "[+] Installing websocket-client..."
pip install websocket-client

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
for pkg in pygame socketio engineio PIL cairosvg pyscreenshot requests urllib3 certifi charset_normalizer idna websocket; do
  if [ -d "$pkg" ]; then
    echo "  Copying $pkg/"
    cp -r "$pkg" "$PACKAGES_DIR/"
  fi
done

# Copy pygame.libs (bundled SDL2 libraries from manylinux wheel)
if [ -d "pygame.libs" ]; then
  echo "  Copying pygame.libs/ (bundled SDL2)"
  cp -r "pygame.libs" "$PACKAGES_DIR/"
fi

# Copy pillow.libs (bundled image libraries from manylinux wheel)
if [ -d "pillow.libs" ]; then
  echo "  Copying pillow.libs/ (bundled image libs)"
  cp -r "pillow.libs" "$PACKAGES_DIR/"
fi

# Also copy dist-info directories for package metadata
for pkg in pygame python_socketio python_engineio pillow cairosvg pyscreenshot requests urllib3 certifi charset_normalizer idna websocket_client; do
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

# Verify pygame.libs was included
echo ""
echo "[+] Verifying bundled SDL2 libraries..."
if [ -d "$PACKAGES_DIR/pygame.libs" ]; then
  echo "  pygame.libs found:"
  ls -la "$PACKAGES_DIR/pygame.libs/"
else
  echo "  WARNING: pygame.libs not found - pygame may fail to load on systems without system SDL2"
fi

# Verify pillow.libs was included
echo ""
echo "[+] Verifying bundled image libraries..."
if [ -d "$PACKAGES_DIR/pillow.libs" ]; then
  echo "  pillow.libs found:"
  ls -la "$PACKAGES_DIR/pillow.libs/"
else
  echo "  WARNING: pillow.libs not found - Pillow may fail to load on systems without system image libs"
fi
