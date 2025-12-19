# Peppy Screensaver Build System

This directory contains Docker-based build systems for the peppy_screensaver
plugin dependencies for Volumio 4 (Bookworm).

## Directory Structure

```
peppy_builds/
  peppyalsa-builds/       - Native C library build system
  peppy-python-builds/    - Python packages build system
```

## Target Architectures

- armv6  (Raspberry Pi Zero, Pi 1)
- armhf  (Raspberry Pi 2, 3, 4 - 32-bit)
- arm64  (Raspberry Pi 3, 4, 5 - 64-bit)
- amd64  (x86_64 PCs)

## Prerequisites

- Docker with multi-platform support (buildx)
- QEMU for cross-architecture builds

### Setup Docker Multi-Platform

```bash
# Install QEMU for cross-platform builds
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Verify platforms available
docker buildx ls
```

## Building peppyalsa

```bash
cd peppyalsa-builds

# Build for all architectures
./build-matrix.sh

# Build for single architecture
./docker/run-docker-peppyalsa.sh armhf

# Verbose output
./build-matrix.sh --verbose
```

Output files:
- out/{arch}/libpeppyalsa.so*
- out/{arch}/peppyalsa-lib.tar.gz
- out/{arch}/peppyalsa-client

## Building Python Packages

### Option 1: Docker Matrix Build (Cross-Compilation)

```bash
cd peppy-python-builds

# Build for all architectures
./build-matrix.sh

# Build for single architecture
./docker/run-docker-python.sh arm64

# Verbose output
./build-matrix.sh --verbose
```

Output files:
- out/{arch}/peppy-python-packages.tar.gz

**WARNING - ARM NEON Optimization:**

Docker/QEMU cross-compilation builds pygame WITHOUT NEON SIMD optimization.
This results in significantly higher CPU usage on ARM devices:

| Build Method | Pi5 CPU Usage | Notes |
|--------------|---------------|-------|
| Docker cross-compile | ~40% | No NEON, uses scalar operations |
| Native Pi build | ~30% | NEON enabled via Debian package |
| x64 Docker | ~2% | SSE/AVX optimizations work correctly |

For production ARM builds, use Option 2 below.

### Option 2: Native Pi Build (NEON Optimized) - RECOMMENDED FOR ARM

For ARM devices (Pi 2/3/4/5), build directly on a Raspberry Pi to get
NEON-optimized pygame from Debian packages:

```bash
# Copy script to Pi
scp peppy-python-builds/neon-native/build-python-native-pi.sh volumio@<pi-ip>:~/

# SSH to Pi and run
ssh volumio@<pi-ip>
sudo bash build-python-native-pi.sh

# Copy output back to build machine
scp volumio@<pi-ip>:~/peppy-python-packages.tar.gz \
    peppy-python-builds/out/armhf/
```

This script:
1. Installs build dependencies temporarily
2. Extracts pygame from Debian package (built with NEON)
3. Builds remaining packages via pip
4. Creates peppy-python-packages.tar.gz
5. Cleans up build dependencies

**Important:** The native build produces armv7+ code that will NOT run on
Pi Zero/Pi 1 (ARMv6). For ARMv6 support, use the Docker-built armv6 package
(accepts higher CPU usage as tradeoff).

### Recommended Build Strategy

| Target | Build Method | Output Location |
|--------|--------------|-----------------|
| armv6 (Pi Zero/1) | Docker matrix | out/armv6/ |
| armhf (Pi 2/3/4/5 32-bit) | Native Pi build | out/armhf/ |
| arm64 (Pi 3/4/5 64-bit) | Native Pi build | out/arm64/ |
| amd64 (x86_64) | Docker matrix | out/amd64/ |

## Assembling the Plugin

After building all dependencies, copy the outputs to the plugin:

```bash
# For each architecture (example: armhf)
cp peppyalsa-builds/out/armhf/peppyalsa-lib.tar.gz \
   ../peppy_plugin_v3/dependencies/armhf/
cp peppyalsa-builds/out/armhf/peppyalsa-client \
   ../peppy_plugin_v3/dependencies/armhf/
cp peppy-python-builds/out/armhf/peppy-python-packages.tar.gz \
   ../peppy_plugin_v3/dependencies/armhf/
```

## Package Versions

Python packages built:
- pygame 2.1.2 (from Debian, native build) / 2.5.2 (Docker build)
- python-socketio 5.11.0
- python-engineio 4.9.0
- Pillow 10.2.0
- cairosvg 2.7.1
- pyscreenshot 3.1
- requests (latest)

Native libraries:
- peppyalsa (from GitHub project-owner/peppyalsa)

## Compiler Flags by Architecture

| Arch  | CFLAGS                                          |
|-------|-------------------------------------------------|
| armv6 | -march=armv6 -mfpu=vfp -mfloat-abi=hard -marm   |
| armhf | -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard|
| arm64 | -march=armv8-a                                  |
| amd64 | (none)                                          |

## Clean Build Outputs

```bash
cd peppyalsa-builds && ./clean-all.sh
cd peppy-python-builds && ./clean-all.sh
```

## Troubleshooting

### "neon capable but pygame was not built with support" Warning

This warning indicates pygame was built without NEON optimization.
Use the native Pi build script to get NEON-optimized pygame.

### High CPU Usage on Pi

Expected CPU usage with NEON-optimized build:
- 800x480: 10-15%
- 1024x600: 15-20%
- 1280x720: 25-35%

If CPU usage is significantly higher, verify NEON is enabled:
```bash
PYTHONPATH=/data/plugins/user_interface/peppy_screensaver/lib/arm/python \
  python3 -c "import pygame; pygame.init()"
```
No warning = NEON enabled.

### "Illegal instruction" on Pi Zero/Pi 1

The native Pi build creates armv7+ code incompatible with ARMv6.
Use Docker-built armv6 package for Pi Zero/Pi 1.
