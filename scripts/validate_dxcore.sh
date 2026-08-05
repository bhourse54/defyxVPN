#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: validate_dxcore.sh <path-to-libDXcore.so> [target-arch]

target-arch values:
  x64
  arm64

If target-arch is omitted, the current machine architecture is used.
EOF
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage

LIB_PATH="$1"
TARGET_ARCH="${2:-$(uname -m)}"

[[ -e "$LIB_PATH" ]] || fail "DXcore library not found: $LIB_PATH"
[[ -f "$LIB_PATH" ]] || fail "DXcore path is not a regular file: $LIB_PATH"

FILE_OUTPUT="$(file -b "$LIB_PATH")"
echo "file: $FILE_OUTPUT"

case "$FILE_OUTPUT" in
  *"ELF"*"shared object"*) ;;
  *) fail "DXcore library is not an ELF shared object: $LIB_PATH" ;;
esac

EXPECTED_MACHINE=""
case "$(printf '%s' "$TARGET_ARCH" | tr '[:upper:]' '[:lower:]')" in
  x64|x86_64|amd64)
    EXPECTED_MACHINE="Advanced Micro Devices X86-64"
    ;;
  arm64|aarch64)
    EXPECTED_MACHINE="AArch64"
    ;;
  *)
    fail "Unsupported target architecture '$TARGET_ARCH'"
    ;;
esac

READ_ELF_OUTPUT="$(readelf -h "$LIB_PATH")"
echo "$READ_ELF_OUTPUT" | grep -q "Machine:" || fail "readelf could not determine machine type for $LIB_PATH"

if ! echo "$READ_ELF_OUTPUT" | grep -q "Machine:[[:space:]]*$EXPECTED_MACHINE"; then
  ACTUAL_MACHINE="$(echo "$READ_ELF_OUTPUT" | awk -F: '/Machine:/ {print $2}' | sed 's/^[[:space:]]*//')"
  fail "DXcore machine type mismatch: expected '$EXPECTED_MACHINE' for target '$TARGET_ARCH', got '${ACTUAL_MACHINE:-unknown}'"
fi

if ! command -v nm >/dev/null 2>&1; then
  fail "nm is required but was not found in PATH"
fi

DEFINED_SYMBOLS="$(nm -D --defined-only "$LIB_PATH" | awk '{print $3}' | sort -u)"

required_symbols=(
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
)

missing=()
for symbol in "${required_symbols[@]}"; do
  if ! printf '%s\n' "$DEFINED_SYMBOLS" | grep -Fxq "$symbol"; then
    missing+=("$symbol")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'ERROR: DXcore is missing required exported symbols:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "DXcore validation passed for target '$TARGET_ARCH': $LIB_PATH"
