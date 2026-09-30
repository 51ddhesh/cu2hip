#!/bin/sh
# run_core_roundtrip.sh — verified-core gate that needs NO frontend
# (no Clang/CUDA). Exercises the extracted map + printer on committed
# MiniCUDA fixtures and byte-compares the emitted .hip, so the core path
# (mini_json parse -> minimap -> hip_print) can be regression-tested on a
# CUDA-less host (e.g. macOS via docker/build) as well as in CI.
#
# Usage: sh tests/run_core_roundtrip.sh
# Exit 0 iff: fixtures valid AND each core fixture round-trips byte-identical
#   to its tests/expected/*.hip.
set -e
cd "$(dirname "$0")/.."
eval "$(opam env --switch=cuda-rocm-rocq 2>/dev/null)" || true
MM="${MINIMAP:-_build/default/core/bin/minimap.exe}"
HP="${HIP_PRINT:-_build/default/printer/hip_print.exe}"

python3 tests/check_fixtures.py

# name : the MiniCUDA fixture stem under tests/fixtures/ whose mapped output
# must match tests/expected/<name>.hip byte-for-byte.
for name in bitops; do
  "$MM" tests/fixtures/$name.minicuda.json -o /tmp/core.$name.minihip.json
  "$HP" /tmp/core.$name.minihip.json -o /tmp/core.$name.hip
  cmp /tmp/core.$name.hip tests/expected/$name.hip
  echo "CORE ROUND-TRIP OK: $name"
done
echo "ALL CORE ROUND-TRIP GREEN"
