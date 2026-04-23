#!/usr/bin/env bash
# Build the pgmicro sdk-kit static/shared library for the current host
# platform and copy it into libs/<platform>/ so go:embed picks it up.
#
# Required env:
#   PGMICRO_BUILD_REF       pgmicro git ref (tag or branch)
#
# Optional env:
#   PGMICRO_REPO            default: https://github.com/glommer/pgmicro.git
#   PGMICRO_BUILD_PROFILE   cargo profile (default: lib-release)
#   PGMICRO_BUILD_DIR       local clone dir (default: pgmicro)
#   PGMICRO_CARGO_PACKAGE   cargo -p target (default: turso_sdk_kit — pgmicro's upstream crate name)
#   PGMICRO_CARGO_FEATURES  comma-sep cargo features (default: default-postgres)
#   PGMICRO_LIBC_VARIANT    "" or "_musl" (auto-detected on Linux)
#   PGMICRO_GO_LIB_DIR      output root (default: libs)
#   PGMICRO_OUTPUT_NAME     output library basename (default: libpgmicro_sdk_kit; upstream produces libturso_sdk_kit and we rename)
set -euo pipefail

PGMICRO_REPO=${PGMICRO_REPO:-https://github.com/ainvyu/pgmicro.git}
PGMICRO_BUILD_PROFILE=${PGMICRO_BUILD_PROFILE:-lib-release}
PGMICRO_BUILD_DIR=${PGMICRO_BUILD_DIR:-pgmicro}
PGMICRO_CARGO_PACKAGE=${PGMICRO_CARGO_PACKAGE:-turso_sdk_kit}
PGMICRO_CARGO_FEATURES=${PGMICRO_CARGO_FEATURES:-default-postgres}
PGMICRO_LIBC_VARIANT=${PGMICRO_LIBC_VARIANT:-""}
PGMICRO_GO_LIB_DIR=${PGMICRO_GO_LIB_DIR:-libs}
PGMICRO_OUTPUT_NAME=${PGMICRO_OUTPUT_NAME:-pgmicro_sdk_kit}

if [[ "${PGMICRO_BUILD_REF:-}" == "" ]]; then
    echo "PGMICRO_BUILD_REF env var must be set" >&2
    exit 1
fi

CARGO_ARGS_ARR=(--profile "$PGMICRO_BUILD_PROFILE")
if [[ -n "$PGMICRO_CARGO_FEATURES" ]]; then
    CARGO_ARGS_ARR+=("--features" "$PGMICRO_CARGO_FEATURES")
fi

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

echo "UNAME_S: $UNAME_S"
echo "UNAME_M: $UNAME_M"

case "$UNAME_S" in
  Linux*)  OS=linux  ;;
  Darwin*) OS=darwin ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  *) echo "Unsupported OS: $UNAME_S"; exit 1 ;;
esac

if [[ "$OS" == "windows" ]]; then
  case "$UNAME_S" in
    *ARM64)  ARCH=arm64  ;;
    *) ARCH=amd64 ;;
  esac
else
  # cygwin reports x86_64 even for windows on ARM
  case "$UNAME_M" in
    x86_64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    i386|i686) ARCH=386 ;;
    *) echo "Unsupported arch: $UNAME_M"; exit 1 ;;
  esac
fi

# Detect libc variant on Linux
if [[ "$PGMICRO_LIBC_VARIANT" == "" ]]; then
    if [[ "$UNAME_S" == Linux* ]]; then
        if ldd --version 2>&1 | grep -qi musl; then
            PGMICRO_LIBC_VARIANT="_musl"
        elif [ -f /etc/alpine-release ]; then
            PGMICRO_LIBC_VARIANT="_musl"
        fi
    fi
fi

PLATFORM="${OS}_${ARCH}${PGMICRO_LIBC_VARIANT}"
PGMICRO_GO_LIB_PATH="${PGMICRO_GO_LIB_DIR}/${PLATFORM}"

# Upstream cargo output name (what we rename FROM)
case "$OS" in
  linux)   UPSTREAM_OUT="lib${PGMICRO_CARGO_PACKAGE}.so" ;;
  darwin)  UPSTREAM_OUT="lib${PGMICRO_CARGO_PACKAGE}.dylib" ;;
  windows) UPSTREAM_OUT="${PGMICRO_CARGO_PACKAGE}.dll" ;;
esac

# Our renamed output (what we ship)
case "$OS" in
  linux)   FINAL_NAME="lib${PGMICRO_OUTPUT_NAME}.so" ;;
  darwin)  FINAL_NAME="lib${PGMICRO_OUTPUT_NAME}.dylib" ;;
  windows) FINAL_NAME="${PGMICRO_OUTPUT_NAME}.dll" ;;
esac

# Rust target for musl builds
RUST_TARGET=""
if [[ "$PGMICRO_LIBC_VARIANT" == "_musl" ]]; then
  # https://github.com/rust-lang/rust/issues/59302
  export RUSTFLAGS="-C target-feature=-crt-static"
  case "$ARCH" in
    amd64) RUST_TARGET="x86_64-unknown-linux-musl" ;;
    arm64) RUST_TARGET="aarch64-unknown-linux-musl" ;;
    *) echo "Unsupported musl arch: $ARCH"; exit 1 ;;
  esac
  if command -v rustup >/dev/null 2>&1; then
    if ! rustup target list --installed | grep -q "$RUST_TARGET"; then
      echo "Installing Rust target: $RUST_TARGET"
      rustup target add "$RUST_TARGET"
    fi
  else
    echo "rustup not found, assuming $RUST_TARGET is available"
  fi
  CARGO_ARGS_ARR+=("--target" "$RUST_TARGET")
fi

if [[ -n "$RUST_TARGET" ]]; then
  CARGO_OUT_DIR="${PGMICRO_BUILD_DIR}/target/${RUST_TARGET}/${PGMICRO_BUILD_PROFILE}"
else
  CARGO_OUT_DIR="${PGMICRO_BUILD_DIR}/target/${PGMICRO_BUILD_PROFILE}"
fi
CARGO_LIB_PATH="${CARGO_OUT_DIR}/${UPSTREAM_OUT}"

echo "PGMICRO_REPO:            $PGMICRO_REPO"
echo "PGMICRO_BUILD_REF:       $PGMICRO_BUILD_REF"
echo "PGMICRO_BUILD_DIR:       $PGMICRO_BUILD_DIR"
echo "PGMICRO_CARGO_PACKAGE:   $PGMICRO_CARGO_PACKAGE"
echo "PGMICRO_CARGO_FEATURES:  $PGMICRO_CARGO_FEATURES"
echo "CARGO_ARGS:              ${CARGO_ARGS_ARR[*]}"
echo "CARGO_OUT_DIR:           $CARGO_OUT_DIR"
echo "CARGO_LIB_PATH:          $CARGO_LIB_PATH"
echo "PGMICRO_GO_LIB_PATH:     $PGMICRO_GO_LIB_PATH"
echo "UPSTREAM_OUT:            $UPSTREAM_OUT"
echo "FINAL_NAME:              $FINAL_NAME"

git clone --single-branch --depth 1 --branch "$PGMICRO_BUILD_REF" "$PGMICRO_REPO" "$PGMICRO_BUILD_DIR"

pushd "$PGMICRO_BUILD_DIR"
echo "Building ${PGMICRO_CARGO_PACKAGE} (${PGMICRO_BUILD_PROFILE}, features=${PGMICRO_CARGO_FEATURES}) for ${PLATFORM}"
cargo build "${CARGO_ARGS_ARR[@]}" --package "${PGMICRO_CARGO_PACKAGE}"
popd

if [[ ! -f "$CARGO_LIB_PATH" ]]; then
  echo "Expected artifact not found: $CARGO_LIB_PATH" >&2
  echo "Contents of ${CARGO_OUT_DIR}:" >&2
  ls -la "${CARGO_OUT_DIR}" >&2 || true
  exit 1
fi

mkdir -p "${PGMICRO_GO_LIB_PATH}"
# Rename while copying so libpgmicro_sdk_kit.* is the canonical shipped name
# even when upstream emits libturso_sdk_kit.*.
cp -f "${CARGO_LIB_PATH}" "${PGMICRO_GO_LIB_PATH}/${FINAL_NAME}"

echo "Wrote $(pwd)/${PGMICRO_GO_LIB_PATH}/${FINAL_NAME}"
