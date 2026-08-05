# Linux Dependencies

## Required Packages

Install the following packages before building the Flutter Linux app:

```bash
sudo apt update && sudo apt install -y \
    libayatana-appindicator3-dev \
    libgtk-3-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    libsecret-1-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang
```

## Package Details

| Package | Purpose |
|---------|---------|
| `libayatana-appindicator3-dev` | System tray support |
| `libgtk-3-dev` | GTK 3 UI framework |
| `libgstreamer1.0-dev` | GStreamer core (audio playback) |
| `libgstreamer-plugins-base1.0-dev` | GStreamer base plugins |
| `gstreamer1.0-plugins-good` | GStreamer good codecs |
| `gstreamer1.0-plugins-bad` | GStreamer additional codecs |
| `gstreamer1.0-plugins-ugly` | GStreamer patent-encumbered codecs |
| `libsecret-1-dev` | Secure storage (flutter_secure_storage) |
| `pkg-config` | Build configuration tool |
| `cmake` | Build system |
| `ninja-build` | Fast build tool |
| `clang` | C/C++ compiler |

## ARM64 Notes

On native ARM64/AArch64 Linux, the Flutter bundle should be produced under:

```text
build/linux/arm64/<configuration>/bundle
```

The Linux runner normalizes architecture names as follows:

- `x86_64` and `amd64` map to `x64`
- `aarch64` and `arm64` map to `arm64`

## Local Validation

Before packaging `libDXcore.so`, validate it with:

```bash
uname -m
file path/to/libDXcore.so
readelf -h path/to/libDXcore.so
nm -D --defined-only path/to/libDXcore.so
```

The repository also includes a bundle validator:

```bash
bash scripts/validate_dxcore.sh /absolute/path/to/libDXcore.so arm64
```

## Build Commands

Build using a prebuilt library:

```bash
DEFYX_DXCORE_LIB=/absolute/path/to/libDXcore.so flutter build linux --release
```

Build using the private DXcore source directory:

```bash
DEFYX_DXCORE_DIR=/absolute/path/to/private/DXcore/source flutter build linux --release
```

## Build & Run

```bash
flutter clean
flutter pub get
flutter run -d linux
```
