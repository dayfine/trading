#!/bin/sh
# fmt_check_smoke.sh -- fixture-driven RED/GREEN regression test for
# fmt_check.sh (issue #2598).
#
# Bug: `.ocamlformat` lives at the workspace root (`trading/.ocamlformat`),
# but ocamlformat's ancestor search for a project root stops at the nearest
# `dune-project` -- which for real source paths under `trading/trading/...`
# is ONE LEVEL BELOW where `.ocamlformat` lives. With no project root
# containing `.ocamlformat`, ocamlformat prints "Ocamlformat disabled" and
# exits 0 on every file -- fmt_check.sh silently reported OK on badly
# formatted trees, forever, on every run.
#
# Fix: fmt_check.sh now passes `--root="$TRADING_DIR"` to ocamlformat,
# pinning the project root explicitly to where `.ocamlformat` actually
# lives, so `--check` performs the real check.
#
# This test builds an isolated fixture that reproduces the exact directory
# shape (a workspace root carrying `.ocamlformat` + `dune-workspace`, and a
# `dune-project` ONE LEVEL BELOW containing the source files -- the same
# relationship as `trading/.ocamlformat` vs. `trading/trading/dune-project`)
# and checks three things:
#   1. The underlying bug reproduces directly: a bare `ocamlformat --check`
#      (no --root) on a malformed file in that shape wrongly exits 0. This
#      pins the root cause fmt_check.sh's --root flag defends against --
#      if ocamlformat's search behavior ever changes such that this stops
#      reproducing, that is signal the fix (or this test) needs revisiting.
#   2. The SHIPPED fmt_check.sh (copied into the fixture, unmodified) FAILs
#      with nonzero exit on a tree containing that malformed file.
#   3. The SHIPPED fmt_check.sh exits 0 with "OK:" on a clean tree.
#
# Local regression check performed when this test was written: assertion 2
# was run against a copy of fmt_check.sh with the `--root="$TRADING_DIR"`
# fix reverted (bare `ocamlformat --check "$f"`) -- it went RED, printing
# "OK: all .ml/.mli files are correctly formatted." despite bad.ml being
# malformed (exit 0), matching assertion 1's reproduction exactly. Restoring
# the fix made it GREEN again.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAL_FMT_CHECK="$SCRIPT_DIR/fmt_check.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Directory shape mirrors the real repo: `.ocamlformat` + `dune-workspace`
# at the workspace root; `dune-project` (and the source files) ONE LEVEL
# BELOW that root -- the exact shape that disables ocamlformat's ancestor
# search.
cat >"$FIXTURE/.ocamlformat" <<'EOF'
profile = default
version = 0.29.0
EOF
: >"$FIXTURE/dune-workspace"
mkdir -p "$FIXTURE/devtools/checks" "$FIXTURE/proj"
: >"$FIXTURE/proj/dune-project"
cp "$REAL_FMT_CHECK" "$FIXTURE/devtools/checks/fmt_check.sh"

# A deliberately malformed file (missing spaces around operators);
# ocamlformat reformats this under `profile = default`.
printf 'let x=1+2\n' >"$FIXTURE/proj/bad.ml"
# A correctly formatted sibling, to confirm it is never falsely flagged.
printf 'let x = 1 + 2\n' >"$FIXTURE/proj/good.ml"

FAILED=0

# --- Assertion 1: reproduce the underlying ocamlformat behavior --------
# Bare `--check`, no --root, on a file under the one-level-below project:
# ocamlformat disables itself and exits 0 even though bad.ml needs
# reformatting. This is the exact symptom #2598 pins.
set +e
(cd "$FIXTURE/proj" && ocamlformat --check bad.ml) >/dev/null 2>&1
BARE_RC=$?
set -e
if [ "$BARE_RC" -eq 0 ]; then
  echo "PASS: reproduced the root cause -- bare 'ocamlformat --check' (no --root) silently exits 0 on a malformed file in this directory shape"
else
  echo "FAIL: expected bare 'ocamlformat --check' (no --root) to silently exit 0 in this directory shape; got exit=$BARE_RC (has ocamlformat's ancestor-search behavior changed?)"
  FAILED=1
fi

# --- Assertion 2: the SHIPPED fmt_check.sh must FAIL on the malformed tree
set +e
OUT="$(sh "$FIXTURE/devtools/checks/fmt_check.sh" 2>&1)"
RC=$?
set -e
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q 'FAIL:' && printf '%s' "$OUT" | grep -q 'bad\.ml'; then
  echo "PASS: fmt_check.sh correctly FAILs on the malformed tree (exit=$RC)"
else
  echo "FAIL: fmt_check.sh did not correctly report the malformed file (exit=$RC)"
  printf '%s\n' "$OUT"
  FAILED=1
fi

# --- Assertion 3: the SHIPPED fmt_check.sh must pass OK on a clean tree --
rm -f "$FIXTURE/proj/bad.ml"
set +e
OUT="$(sh "$FIXTURE/devtools/checks/fmt_check.sh" 2>&1)"
RC=$?
set -e
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'OK:'; then
  echo "PASS: fmt_check.sh correctly reports OK on a clean tree (exit=$RC)"
else
  echo "FAIL: fmt_check.sh did not report OK on a clean tree (exit=$RC)"
  printf '%s\n' "$OUT"
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "FAIL: fmt_check_smoke.sh"
  exit 1
fi

echo "OK: fmt_check_smoke.sh -- all assertions passed"
