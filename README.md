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
- pygame 2.5.2
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
