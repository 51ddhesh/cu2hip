#!/bin/sh
# check_assumptions.sh — machine gate on the proof's trusted base.
#
# The project's entire claim is a machine-checked `transpile_correct` with
# ZERO admits and no classic axioms (SRS §5 VR-2; docs/ADMITS.md). As the
# accepted subset grows, this gate mechanically enforces that: it runs
# `Print Assumptions transpile_correct` and fails if the theorem depends on
# anything beyond the whitelisted IEEE-754 `PrimFloat.*` primitives (the same
# trusted arithmetic class as CompCert's), or if any admit is present.
#
# Usage: sh scripts/check_assumptions.sh   (proofs must be built first)
# Exit 0 iff the only assumptions are PrimFloat.* and there are no admits.
set -e
cd "$(dirname "$0")/.."
eval "$(opam env --switch=cuda-rocm-rocq 2>/dev/null)" || true

if [ ! -f rocq/Sim.vo ]; then
  echo "check_assumptions: rocq/Sim.vo not found — run 'make proofs' first" >&2
  exit 1
fi

chk="$(mktemp -d)/assume_check.v"
printf 'Require Import Cu2Hip.Sim.\nPrint Assumptions transpile_correct.\n' > "$chk"
# Print Assumptions output goes to stdout; warnings to stderr.
out="$(cd rocq && rocq compile -Q . Cu2Hip "$chk" 2>/dev/null)"
echo "$out"

# No admits, ever.
if printf '%s' "$out" | grep -qiE 'admit'; then
  echo "check_assumptions: FAIL — an admit is reachable from transpile_correct" >&2
  exit 1
fi

# A fully axiom-free proof prints this and is trivially fine.
if printf '%s' "$out" | grep -q 'Closed under the global context'; then
  echo "check_assumptions: OK (no axioms at all)"
  exit 0
fi

# Otherwise every listed assumption (axiom-name lines start in column 0 and
# contain ' :'; wrapped type lines are indented) must be a PrimFloat.* primitive.
bad="$(printf '%s\n' "$out" | awk '
  /^Axioms:/ { next }
  /^[A-Za-z_][A-Za-z0-9_.]* :/ {
    if ($1 !~ /^PrimFloat\./) print $1
  }')"

if [ -n "$bad" ]; then
  echo "check_assumptions: FAIL — non-whitelisted assumptions:" >&2
  printf '  %s\n' $bad >&2
  exit 1
fi

echo "check_assumptions: OK (assumptions limited to PrimFloat.* IEEE-754 primitives)"
