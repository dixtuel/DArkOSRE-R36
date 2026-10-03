#!/usr/bin/env bash
set -euo pipefail

readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly apply_script="$script_dir/apply-r36-overrides.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 FCAMOD_SOURCE_DIR" >&2
  exit 2
fi
src=$(cd -- "$1" && pwd)
"$apply_script" "$src"
binary="$src/emulationstation"
if [[ -e "$binary" ]]; then
  echo "Refusing to overwrite an existing file in the temporary source checkout: $binary" >&2
  exit 1
fi

cmake_args=(
  -S "$src"
  -B "$src/build-r36-candidate"
  -DGLES=ON
  -DGL=OFF
  -DGAMESDB_APIKEY=
  -DCMAKE_BUILD_TYPE=Release
)
if [[ -n "${CMAKE_TOOLCHAIN_FILE:-}" ]]; then
  cmake_args+=("-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE")
fi
if [[ -n "${CMAKE_SYSROOT:-}" ]]; then
  cmake_args+=("-DCMAKE_SYSROOT=$CMAKE_SYSROOT")
fi
if [[ -n "${CC:-}" ]]; then
  cmake_args+=("-DCMAKE_C_COMPILER=$CC")
fi
if [[ -n "${CXX:-}" ]]; then
  cmake_args+=("-DCMAKE_CXX_COMPILER=$CXX")
fi

host_arch=$(uname -m)
if [[ "$host_arch" != aarch64 && ( -z "${CMAKE_TOOLCHAIN_FILE:-}" || -z "${CMAKE_SYSROOT:-}" ) ]]; then
  echo "Host is $host_arch. Cross builds require both CMAKE_TOOLCHAIN_FILE and CMAKE_SYSROOT for the R36 AArch64 target." >&2
  exit 1
fi
if [[ -n "${CMAKE_SYSROOT:-}" && ! -d "$CMAKE_SYSROOT" ]]; then
  echo "CMAKE_SYSROOT is not a directory: $CMAKE_SYSROOT" >&2
  exit 1
fi

cmake "${cmake_args[@]}"
cmake --build "$src/build-r36-candidate" --parallel "${JOBS:-2}"

if [[ ! -f "$binary" ]]; then
  echo "Expected CMake output was not found in the source checkout: $binary" >&2
  exit 1
fi
if command -v readelf >/dev/null 2>&1; then
  machine=$(readelf -h "$binary" | awk -F: '/Machine:/ { sub(/^[[:space:]]+/, "", $2); print $2 }')
  if [[ "$machine" != AArch64 ]]; then
    echo "Build output has unexpected ELF machine: $machine" >&2
    exit 1
  fi
fi
sha256sum "$binary"
printf 'Candidate built at %s; this script does not install or package it.\n' "$binary"
