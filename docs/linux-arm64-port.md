# Linux ARM64 Port Audit

## Scope

This audit covers the native Linux runner, the Flutter Linux bundle path, and the DXcore loading surface for an ARM64/AArch64 build.

## Current Status

- Public ARM64 port scaffolding is complete.
- Native Linux runner build is not yet proven end-to-end in this workspace.
- A functional VPN remains blocked by the missing proprietary AArch64 `libDXcore.so`.
- No release artifact should be treated as functional until a real AArch64 DXcore binary is supplied and tested.

## Architecture Assumptions

- The native Linux runner now normalizes `x86_64` and `amd64` to `x64`.
- The native Linux runner now normalizes `aarch64` and `arm64` to `arm64`.
- Unknown Linux architectures are rejected instead of being mapped to `x64`.
- The Flutter bundle path follows the standard shape:

  ```text
  build/linux/<architecture>/<configuration>/bundle
  ```

- Existing `x64` builds remain supported.

## Hard-Coded X64 Paths Found During Audit

The repository originally contained hard-coded Linux `x64` bundle references in:

- `linux/runner/CMakeLists.txt`
- `.github/workflows/linux.yml`

Other non-Linux scripts also contained `x64` references, but they are outside the Linux runner bundle path itself.

## Native Libraries and Plugins

### Native Linux Libraries

- GTK 3 from `libgtk-3-dev`
- AppIndicator from `libayatana-appindicator3-dev`
- GStreamer from `libgstreamer1.0-dev` and `libgstreamer-plugins-base1.0-dev`
- Secret storage support from `libsecret-1-dev`
- `dl` and `Threads` from the system toolchain

### Flutter Linux Plugins

- `audioplayers_linux`
- `flutter_secure_storage_linux`
- `flutter_timezone`
- `url_launcher_linux`

### Linux Handling Notes

- Firebase is removed from the Linux generated plugin registrant.
- The Dart app skips Firebase initialization on Linux.
- Desktop ad code routes Linux to internal ads only.
- Secure storage, timezone, and audio plugins have Linux implementations through their Linux packages.
- AppIndicator/system tray support is native and depends on the system package, not on a Flutter plugin.

## Source Availability

| Component | Source available? | Notes |
| --- | --- | --- |
| `flutter_secure_storage_linux` | Yes | Pulled from pub and built as part of the Flutter Linux toolchain |
| `flutter_timezone` | Yes | Pulled from pub |
| `audioplayers_linux` | Yes | Pulled from pub |
| `url_launcher_linux` | Yes | Pulled from pub |
| GTK/AppIndicator/GStreamer/libsecret | Yes | Available from Debian/Ubuntu packages |
| DXcore implementation | No | Public repo does not include proprietary source |
| `libDXcore.so` binary | Not in public repo | Must be supplied separately for a functional VPN build |

## DXcore ABI Expected by the Runner

The Linux runner expects these exported C ABI symbols from `libDXcore.so`:

- `StartVPN(const char*, const char*, const char*) -> int`
- `StopVPN() -> int`
- `StartTun2Socks(long long, const char*) -> void`
- `StopTun2Socks() -> void`
- `Stop() -> void`
- `MeasurePing() -> long long`
- `GetFlag() -> char*`
- `SetAsnName() -> void`
- `SetTimeZone(float) -> void`
- `GetFlowLine(int) -> char*`
- `GetCachedFlowLine() -> char*`
- `DecodeAndVerifyFlowline(const char*) -> char*`
- `GetVpnStatus() -> char*`
- `SetProgressCallback(void (*)(char*)) -> void`
- `SetVerboseLogging(int) -> void`
- `FreeString(char*) -> void`
- `SetConnectionMethod(const char*) -> void`
- `SetCacheDir(const char*) -> void`
- `IsTunnelRunning() -> int`

The runner now treats missing required exports as a hard failure during library load.

## Debian/Ubuntu ARM64 Build Prerequisites

Install the following packages on ARM64 Debian/Ubuntu hosts:

- `libayatana-appindicator3-dev`
- `libgtk-3-dev`
- `libgstreamer1.0-dev`
- `libgstreamer-plugins-base1.0-dev`
- `gstreamer1.0-plugins-good`
- `gstreamer1.0-plugins-bad`
- `gstreamer1.0-plugins-ugly`
- `libsecret-1-dev`
- `pkg-config`
- `cmake`
- `ninja-build`
- `clang`
- `file`
- `git`
- `unzip`
- `xz-utils`
- `zip`
- `go` if building `libDXcore.so` from the private source tree

The repo also uses the standard Flutter Linux tooling and the Flutter SDK version pinned by CI.

## Known Blockers

| Blocker | Owner | Status |
| --- | --- | --- |
| Proprietary ARM64 `libDXcore.so` is unavailable in the public repository | DXcore private source owner | Blocks a functional VPN build |
| Redistributable rights for any supplied DXcore binary are not documented here | DXcore private source owner | Must be confirmed before packaging |
| ARM64 Flutter host SDK availability for CI | Build/CI owner | Required for native ARM64 bundle builds |
| Any Linux-only plugin regressions outside the current set | App/runtime owner | Must be handled with explicit Linux fallbacks or error propagation |

## Validation Commands

Use these commands before packaging a DXcore build:

```bash
uname -m
file path/to/libDXcore.so
readelf -h path/to/libDXcore.so
nm -D --defined-only path/to/libDXcore.so
```

The repository also provides:

```bash
bash scripts/validate_dxcore.sh /absolute/path/to/libDXcore.so arm64
```

## Local Build Commands

Build from a prebuilt DXcore library:

```bash
DEFYX_DXCORE_LIB=/absolute/path/to/libDXcore.so flutter build linux --release
```

Build from a private DXcore source tree:

```bash
DEFYX_DXCORE_DIR=/absolute/path/to/private/DXcore/source flutter build linux --release
```
