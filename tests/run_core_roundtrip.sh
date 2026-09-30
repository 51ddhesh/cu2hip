#!/bin/sh
# run_core_roundtrip.sh — verified-core gate that needs NO frontend
# (no Clang/CUDA). Exercises the extracted map + printer on committed
# MiniCUDA fixtures and byte-compares the emitted .hip, so the core path
# (mini_json parse -> minimap -> hip_print) can be regression-tested on a
# CUDA-less host (e.g. macOS via docker/build) as well as in CI.
#
# Usage: sh tests/run_core_roundtrip.sh
# Exit 0 iff: fixtures validate, each supported core fixture round-trips
# byte-identically, and a malformed atomic is rejected by the extracted
# well-formedness gate before printing.
set -e
cd "$(dirname "$0")/.."
eval "$(opam env --switch=cuda-rocm-rocq 2>/dev/null)" || true
MM="${MINIMAP:-_build/default/core/bin/minimap.exe}"
HP="${HIP_PRINT:-_build/default/printer/hip_print.exe}"

python3 tests/check_fixtures.py

# name : the MiniCUDA fixture stem under tests/fixtures/ whose mapped output
# must match tests/expected/<name>.hip byte-for-byte.
for name in bitops atomics; do
  "$MM" tests/fixtures/$name.minicuda.json -o /tmp/core.$name.minihip.json
  "$HP" /tmp/core.$name.minihip.json -o /tmp/core.$name.hip
  cmp /tmp/core.$name.hip tests/expected/$name.hip
  echo "CORE ROUND-TRIP OK: $name"
done

# Fail closed before mapping/printing: this is structurally valid JSON but a
# binary atomic with no value. The extracted well-formedness gate must reject it.
python3 - <<'PY'
import json
with open("tests/fixtures/atomics.minicuda.json") as source:
    doc = json.load(source)
call = doc["program"]["kernels"][0]["body"][1]["then"][0]["expr"]
call["args"] = call["args"][:1]
with open("/tmp/core.bad-atomic.minicuda.json", "w") as output:
    json.dump(doc, output)
PY
if "$MM" /tmp/core.bad-atomic.minicuda.json -o /tmp/core.bad-atomic.minihip.json >/dev/null 2>&1; then
  echo "CORE REJECT FAIL: malformed atomic was accepted"
  exit 1
fi
feature=$(python3 -c "import json; print(json.load(open('/tmp/core.bad-atomic.minihip.json'))['diagnostics'][0]['feature'])")
[ "$feature" = "invalid-program" ] || {
  echo "CORE REJECT FAIL: expected invalid-program, got $feature"
  exit 1
}
echo "CORE REJECT OK: malformed atomic -> invalid-program"

echo "ALL CORE ROUND-TRIP GREEN"
