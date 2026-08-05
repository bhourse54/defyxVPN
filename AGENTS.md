# AGENTS.md

## Mission

Port the public DefyxVPN Linux client to native Linux ARM64/AArch64 using the standard Flutter Linux GTK runner.

The target is a real native ARM64 Linux bundle, not a `flutter-pi` bundle and not an x86-64 binary running under Box64/QEMU.

## Critical constraint

The actual VPN backend is loaded from `libDXcore.so`. Do not claim that the VPN works unless a real AArch64 `libDXcore.so` is present, loads successfully, exposes every required ABI symbol, and passes functional smoke tests.

The public repository may not contain the proprietary DXcore implementation. Never attempt to fabricate, reverse-engineer, decompile, translate, or recreate that proprietary implementation from an x86-64 binary.

If no real ARM64 DXcore binary or source is available, complete all open-source ARM64 porting work, create explicit validation and fail-closed behavior, document the remaining blocker, and stop. A mock DXcore may be used only for automated tests and UI development; it must never be packaged in a release build.

## Repository areas to inspect first

Read these before changing code:

- `pubspec.yaml`
- `linux/CMakeLists.txt`
- `linux/runner/CMakeLists.txt`
- `linux/runner/defyx_core.cpp`
- `linux/runner/defyx_core.h`
- `linux/runner/defyx_linux_plugin.cc`
- `linux/runner/vpn_channel_handler.cpp`
- `linux/flutter/generated_plugin_registrant.cc`
- `.github/workflows/`
- `DEPENDENCIES.md` if present
- any scripts that assume `x64`, `x86_64`, or `amd64`

Search the entire repository for:

```bash
grep -RInE 'x64|x86_64|amd64|linux-x64|libDXcore|DXcore-private|DEFYX_DXCORE' .
```

## Selected architecture approach

Implement support for option 1: a native AArch64 `libDXcore.so` using the existing C ABI expected by the Linux runner.

The application must accept either:

- `DEFYX_DXCORE_LIB=/absolute/path/to/libDXcore.so`, or
- `DEFYX_DXCORE_DIR=/absolute/path/to/private/DXcore/source`

Do not commit a proprietary library unless its license explicitly permits redistribution.

## Required work

### 1. Produce an architecture audit

Create `docs/linux-arm64-port.md` covering:

- host and target architecture assumptions;
- all hard-coded x64 paths;
- every native library and plugin;
- whether source is available for each native dependency;
- the exact DXcore ABI expected by the runner;
- build prerequisites for Debian/Ubuntu ARM64;
- known blockers and their owners.

Use evidence from repository files and command output. Do not guess.

### 2. Make Linux bundle paths architecture-aware

Remove hard-coded `linux/x64/...` paths.

Derive a normalized architecture name:

- `x86_64`/`amd64` -> `x64`
- `aarch64`/`arm64` -> `arm64`

Preserve existing x64 behavior.

Ensure the resulting bundle path follows the Flutter convention where possible:

```text
build/linux/<architecture>/<configuration>/bundle
```

Do not silently map unknown architectures to x64. Fail with a clear CMake error or use an explicitly documented generic path.

### 3. Validate DXcore before packaging

Add a script such as `scripts/validate_dxcore.sh` that:

- accepts the path to `libDXcore.so`;
- verifies the file exists;
- verifies it is an ELF shared object;
- verifies its machine type matches the target;
- verifies all required exported symbols;
- exits nonzero with actionable messages.

At minimum validate these symbols, plus any additional symbols actually used by the current runner:

```text
StartVPN
StopVPN
StartTun2Socks
StopTun2Socks
Stop
MeasurePing
GetFlag
SetAsnName
SetTimeZone
GetFlowLine
GetCachedFlowLine
DecodeAndVerifyFlowline
GetVpnStatus
SetProgressCallback
SetVerboseLogging
FreeString
SetConnectionMethod
SetCacheDir
IsTunnelRunning
```

Use standard tools such as `file`, `readelf`, and `nm -D` or `objdump -T`.

Integrate validation into CMake before the library is copied into a release bundle.

### 4. Make DXcore loading fail closed

Audit `linux/runner/defyx_core.cpp`.

The current production behavior must never report fake success when the real core is unavailable. In non-test builds:

- `StartVPN` must return failure if DXcore is unavailable;
- `StopVPN` must not report false success when no core is loaded;
- status methods must return an explicit unavailable/error state;
- no fake ping, fake flowline, fake flag, or fake connected status may be presented as real;
- missing required symbols must make core initialization fail;
- errors must be propagated through the Flutter method channel in a structured form.

Keep any mock behavior behind an explicit test-only build option such as:

```text
DEFYX_ENABLE_MOCK_DXCORE=ON
```

The option must default to `OFF`, and release builds must reject it.

### 5. Preserve the standard Flutter Linux runner

Do not use or add `flutter-pi` as the production path.

Ensure the standard GTK runner registers the generated Linux plugins. Confirm that the following plugin-dependent capabilities are either supported on Linux ARM64 or handled gracefully:

- secure storage;
- timezone;
- audio;
- path/shared-directory access;
- system tray;
- AppIndicator;
- any Firebase or advertising code that should be disabled on Linux.

Do not hide `MissingPluginException` without replacing the behavior or returning a clear unsupported-platform error.

### 6. Add ARM64 build automation

Add a CI workflow for a real ARM64 Linux runner when available.

The workflow must:

1. check out the application;
2. create `.env` from `.env.example` only when required;
3. install documented GTK/AppIndicator/build dependencies;
4. install a Flutter SDK version compatible with the project;
5. run `flutter pub get`;
6. run analysis and tests;
7. build the standard Linux ARM64 bundle;
8. validate every ELF executable and `.so` in the bundle;
9. reject x86-64 files in an ARM64 artifact;
10. upload the complete bundle.

Do not work around an unavailable ARM64 Flutter host SDK by pretending an x64 build is ARM64. If Flutter tooling blocks the build, document the exact command, HTTP response/error, Flutter version, engine revision, and the smallest reproducible case.

Do not put proprietary DXcore material in public CI secrets or artifacts without explicit permission.

### 7. Add test coverage

Add tests for:

- architecture normalization;
- bundle path selection;
- DXcore file architecture validation;
- required-symbol validation;
- missing-library behavior;
- wrong-architecture-library behavior;
- missing-symbol behavior;
- method-channel error propagation;
- prevention of mock DXcore in release builds.

A small test-only shared library implementing the expected ABI is allowed under `test/fixtures/` if it contains no proprietary behavior.

### 8. Provide reproducible local commands

Update documentation with commands for native ARM64 Debian/Ubuntu. Include:

```bash
uname -m
file path/to/libDXcore.so
readelf -h path/to/libDXcore.so
nm -D --defined-only path/to/libDXcore.so
```

Include a single build command using `DEFYX_DXCORE_LIB` and another using `DEFYX_DXCORE_DIR`, based on what the repository actually supports after your changes.

## Acceptance criteria

The task is complete only when all applicable criteria below are met:

- No production Linux path is hard-coded to x64.
- Existing x64 builds are not broken.
- An ARM64 runner can compile all public C/C++ and Dart code.
- The build rejects an x86-64 `libDXcore.so` for an ARM64 target.
- The build rejects a DXcore library missing required symbols.
- The application fails clearly and safely when DXcore is unavailable.
- No UI state falsely claims a functioning VPN without a loaded, validated core.
- Tests demonstrate the validation and fail-closed behavior.
- `docs/linux-arm64-port.md` identifies whether the only remaining blocker is the unavailable proprietary ARM64 DXcore.
- The final report lists every changed file, commands run, test results, and unresolved blockers.

## Stop conditions

Stop and report rather than inventing a workaround when any of these is true:

- the real DXcore source is absent;
- only an x86-64 `libDXcore.so` is available;
- redistribution rights for a supplied library are unclear;
- the ARM64 Flutter engine/host SDK required by the selected Flutter version is unavailable;
- a required native plugin has no ARM64-compatible implementation.

A successful UI build is not evidence of a working VPN.

## Working style

- Inspect before editing.
- Keep changes narrowly scoped to Linux ARM64 support and safe DXcore integration.
- Prefer small commits grouped by purpose.
- Do not delete existing x64 support.
- Do not commit generated build output.
- Do not log credentials, flowlines, tokens, private endpoints, or `.env` values.
- Run relevant tests after each material change.
- Include exact terminal evidence in the final report.
