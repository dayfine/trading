#!/bin/sh
# goldens_affected_check_test.sh — fixture-driven smoke test for
# goldens_affected_check.sh (issue #2393).
#
# Builds small, real git repos under a temp REPO_ROOT (the script needs an
# actual `git diff` between two real commits, so a synthetic diff string
# won't do) and drives the real script against them via the REPO_ROOT
# env-var override that `_check_lib.sh:repo_root()` already supports —
# same pattern as check_universe_deps_test.sh / record_qc_audit_test.sh.
#
# Assertions:
#   1. No config-default surface file exists at HEAD -> OK, exit 0.
#   2. Surface file changes, but not a "[@sexp.default" line -> OK.
#   3. A "[@sexp.default" default value changes for a knob that NO golden
#      spec references -> OK, exit 0.
#   4. Same knob change, and a golden spec under a discovered
#      GOLDEN_SP500_SUBDIRS directory DOES reference the knob -> FAIL,
#      exit 1, naming both the knob and the golden spec path.
#   5. The live-config-overrides.sexp file gains a new
#      "((<knob> <value>))" line, and a golden spec references that knob
#      -> FAIL (the second surface shape, sexp field name not
#      "[@sexp.default").
#   6. A knob changes but no .github/workflows/golden-runs-*.yml file
#      exists -> OK (nothing to check the change against).
#   7. A golden-runs-*.yml workflow with NO explicit
#      GOLDEN_SP500_SUBDIRS line still finds a match via the documented
#      default ("goldens-sp500 goldens-sp500-historical").
#
# Run:
#   sh trading/devtools/checks/goldens_affected_check_test.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/goldens_affected_check.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: script not executable: ${SCRIPT}" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
pass() { echo "  PASS: $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }

SURFACE_ML_REL="trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml"
SURFACE_MLI_REL="trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli"
SURFACE_OVERRIDES_REL="dev/weekly-picks/live-config-overrides.sexp"

# _new_repo — creates a fresh, empty git repo under a temp dir and prints
# its path. Local commits only (GIT_AUTHOR_*/GIT_COMMITTER_* env, not the
# global git config) so the test never touches the real user's git setup.
_new_repo() {
  repo="$(mktemp -d -t goldens_affected_test.XXXXXX)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test"
  # Seed a placeholder file so the very first commit always has something
  # to commit, regardless of what the caller adds before calling _commit.
  echo "fixture repo for goldens_affected_check_test.sh" > "$repo/README.md"
  echo "$repo"
}

_commit() {
  repo="$1"
  msg="$2"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "$msg"
  git -C "$repo" rev-parse HEAD
}

# _run <repo> <base-sha> <head-sha> — invokes the real script with
# REPO_ROOT pinned to the fixture repo; captures combined output + exit
# code into globals OUT / RC (POSIX sh has no local return-by-value, and
# this test never runs assertions concurrently, so plain globals are
# safe here).
_run() {
  repo="$1"
  base="$2"
  head="$3"
  set +e
  OUT="$(REPO_ROOT="$repo" sh "$SCRIPT" "$base" "$head" 2>&1)"
  RC=$?
  set -e
}

echo "=== Assertion 1: no config-default surface file at HEAD -> OK ==="
REPO1="$(_new_repo)"
mkdir -p "$REPO1/.github/workflows"
SHA1A="$(_commit "$REPO1" "base: empty repo")"
mkdir -p "$REPO1/dev/notes"
echo "unrelated" > "$REPO1/dev/notes/x.md"
SHA1B="$(_commit "$REPO1" "head: unrelated change")"
_run "$REPO1" "$SHA1A" "$SHA1B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no known config-default surface"; then
  pass "assertion 1: no surface files -> OK"
else
  fail "assertion 1: expected OK/exit0, got rc=$RC output=$OUT"
fi
rm -rf "$REPO1"

echo "=== Assertion 2: surface file changes, but no [@sexp.default line -> OK ==="
REPO2="$(_new_repo)"
mkdir -p "$(dirname "$REPO2/$SURFACE_MLI_REL")" "$REPO2/.github/workflows"
{
  echo "type config = {"
  echo "  entry_order_max_rest_weeks : int; [@sexp.default 0]"
  echo "      (** old comment *)"
  echo "}"
} > "$REPO2/$SURFACE_MLI_REL"
SHA2A="$(_commit "$REPO2" "base")"
sed -i.bak 's/old comment/new comment/' "$REPO2/$SURFACE_MLI_REL"
rm -f "$REPO2/$SURFACE_MLI_REL.bak"
SHA2B="$(_commit "$REPO2" "head: comment-only change")"
_run "$REPO2" "$SHA2A" "$SHA2B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no \[@sexp.default"; then
  pass "assertion 2: comment-only change -> OK"
else
  fail "assertion 2: expected OK/exit0, got rc=$RC output=$OUT"
fi
rm -rf "$REPO2"

# Shared fixture builder for assertions 3/4/6/7: a repo with the .mli
# surface file at a known default, plus (for 4/7) a golden spec directory.
_make_default_change_repo() {
  add_workflow="$1"     # "yes" | "no"
  workflow_has_subdirs="$2"  # "yes" | "no" (only meaningful if add_workflow=yes)
  add_matching_golden="$3"   # "yes" | "no"
  golden_subdir="$4"    # subdir name under backtest_scenarios/

  repo="$(_new_repo)"
  mkdir -p "$(dirname "$repo/$SURFACE_MLI_REL")"
  {
    echo "type config = {"
    echo "  entry_order_max_rest_weeks : int; [@sexp.default 0]"
    echo "}"
  } > "$repo/$SURFACE_MLI_REL"

  if [ "$add_workflow" = "yes" ]; then
    mkdir -p "$repo/.github/workflows"
    if [ "$workflow_has_subdirs" = "yes" ]; then
      {
        echo "name: golden-runs-fixture"
        echo "    env:"
        echo "      GOLDEN_SP500_SUBDIRS: ${golden_subdir}"
      } > "$repo/.github/workflows/golden-runs-fixture.yml"
    else
      {
        echo "name: golden-runs-fixture"
        echo "    env:"
        echo "      SOME_OTHER_VAR: unrelated"
      } > "$repo/.github/workflows/golden-runs-fixture.yml"
    fi
  fi

  if [ "$add_matching_golden" = "yes" ]; then
    gdir="$repo/trading/test_data/backtest_scenarios/${golden_subdir}"
    mkdir -p "$gdir"
    {
      echo "((name \"fixture-golden\")"
      echo " (config_overrides"
      echo "  (((entry_order_max_rest_weeks 26)))))"
    } > "$gdir/fixture-golden.sexp"
  fi

  echo "$repo"
}

echo "=== Assertion 3: default changes, no golden references the knob -> OK ==="
REPO3="$(_make_default_change_repo yes yes no goldens-sp500)"
SHA3A="$(_commit "$REPO3" "base")"
sed -i.bak 's/\[@sexp.default 0\]/[@sexp.default 26]/' "$REPO3/$SURFACE_MLI_REL"
rm -f "$REPO3/$SURFACE_MLI_REL.bak"
SHA3B="$(_commit "$REPO3" "head: flip default 0 -> 26")"
_run "$REPO3" "$SHA3A" "$SHA3B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "zero postsubmit golden specs"; then
  pass "assertion 3: knob changed, no golden references it -> OK"
else
  fail "assertion 3: expected OK/exit0, got rc=$RC output=$OUT"
fi
rm -rf "$REPO3"

echo "=== Assertion 4: default changes AND a golden arms the knob -> FAIL ==="
REPO4="$(_make_default_change_repo yes yes yes goldens-sp500)"
SHA4A="$(_commit "$REPO4" "base")"
sed -i.bak 's/\[@sexp.default 0\]/[@sexp.default 26]/' "$REPO4/$SURFACE_MLI_REL"
rm -f "$REPO4/$SURFACE_MLI_REL.bak"
SHA4B="$(_commit "$REPO4" "head: flip default 0 -> 26")"
_run "$REPO4" "$SHA4A" "$SHA4B"
if [ "$RC" -eq 1 ] \
  && echo "$OUT" | grep -q "entry_order_max_rest_weeks" \
  && echo "$OUT" | grep -q "fixture-golden.sexp" \
  && echo "$OUT" | grep -q "config-default-blast-radius.md"; then
  pass "assertion 4: knob changed + golden arms it -> FAIL naming both"
else
  fail "assertion 4: expected FAIL/exit1 naming the knob+spec, got rc=$RC output=$OUT"
fi
rm -rf "$REPO4"

echo "=== Assertion 5: live-config-overrides.sexp gains a knob a golden arms -> FAIL ==="
REPO5="$(_new_repo)"
mkdir -p "$REPO5/dev/weekly-picks" "$REPO5/.github/workflows"
mkdir -p "$REPO5/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "; live overrides, empty at base"
} > "$REPO5/$SURFACE_OVERRIDES_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO5/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((reject_declining_ma_long_entry true)))))"
} > "$REPO5/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA5A="$(_commit "$REPO5" "base")"
echo "((reject_declining_ma_long_entry false))" >> "$REPO5/$SURFACE_OVERRIDES_REL"
SHA5B="$(_commit "$REPO5" "head: arm reject_declining_ma_long_entry override")"
_run "$REPO5" "$SHA5A" "$SHA5B"
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "reject_declining_ma_long_entry"; then
  pass "assertion 5: overrides-file knob change + golden match -> FAIL"
else
  fail "assertion 5: expected FAIL/exit1, got rc=$RC output=$OUT"
fi
rm -rf "$REPO5"

echo "=== Assertion 6: knob changes, no golden-runs-*.yml workflow exists -> OK ==="
REPO6="$(_make_default_change_repo no no no goldens-sp500)"
SHA6A="$(_commit "$REPO6" "base")"
sed -i.bak 's/\[@sexp.default 0\]/[@sexp.default 26]/' "$REPO6/$SURFACE_MLI_REL"
rm -f "$REPO6/$SURFACE_MLI_REL.bak"
SHA6B="$(_commit "$REPO6" "head: flip default 0 -> 26")"
_run "$REPO6" "$SHA6A" "$SHA6B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no .github/workflows/golden-runs"; then
  pass "assertion 6: no golden-runs workflow -> OK"
else
  fail "assertion 6: expected OK/exit0, got rc=$RC output=$OUT"
fi
rm -rf "$REPO6"

echo "=== Assertion 7: workflow with no GOLDEN_SP500_SUBDIRS falls back to default subdirs -> FAIL ==="
REPO7="$(_make_default_change_repo yes no yes goldens-sp500)"
SHA7A="$(_commit "$REPO7" "base")"
sed -i.bak 's/\[@sexp.default 0\]/[@sexp.default 26]/' "$REPO7/$SURFACE_MLI_REL"
rm -f "$REPO7/$SURFACE_MLI_REL.bak"
SHA7B="$(_commit "$REPO7" "head: flip default 0 -> 26")"
_run "$REPO7" "$SHA7A" "$SHA7B"
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "fixture-golden.sexp"; then
  pass "assertion 7: fallback default subdirs still find the match"
else
  fail "assertion 7: expected FAIL/exit1 via default subdirs, got rc=$RC output=$OUT"
fi
rm -rf "$REPO7"

echo "=== Assertion 8: docstring cross-reference (Step 2.5) catches a golden that arms a RELATED knob, not the changed one ==="
# Pins the actual #2384 shape: the affected golden never mentions the
# changed knob's name at all -- it arms a DIFFERENT knob that the
# changed knob's own docstring cites via "[bracket]" syntax. Verified
# against the real repo diff (5c278bb78^..5c278bb78) during development;
# this fixture is the durable regression pin.
REPO8="$(_new_repo)"
mkdir -p "$(dirname "$REPO8/$SURFACE_MLI_REL")" "$REPO8/.github/workflows"
mkdir -p "$REPO8/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "type config = {"
  echo "  knob_a : int; [@sexp.default 0]"
  echo "      (** See [knob_b] -- the only place knob_a's clock can bite. *)"
  echo "  knob_b : bool; [@sexp.default false]"
  echo "      (** Unrelated field. *)"
  echo "}"
} > "$REPO8/$SURFACE_MLI_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO8/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((knob_b true)))))"
} > "$REPO8/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA8A="$(_commit "$REPO8" "base")"
sed -i.bak 's/knob_a : int; \[@sexp.default 0\]/knob_a : int; [@sexp.default 26]/' "$REPO8/$SURFACE_MLI_REL"
rm -f "$REPO8/$SURFACE_MLI_REL.bak"
SHA8B="$(_commit "$REPO8" "head: flip knob_a default 0 -> 26")"
_run "$REPO8" "$SHA8A" "$SHA8B"
if [ "$RC" -eq 1 ] \
  && echo "$OUT" | grep -q "knob_b" \
  && echo "$OUT" | grep -q "related-via:knob_a" \
  && echo "$OUT" | grep -q "fixture-golden.sexp"; then
  pass "assertion 8: docstring cross-reference finds the golden that arms the RELATED knob"
else
  fail "assertion 8: expected FAIL/exit1 naming knob_b via related-via:knob_a, got rc=$RC output=$OUT"
fi
rm -rf "$REPO8"

echo "=== Assertion 9: non-snake_case bracket citations ([E], [Entering]) are NOT treated as related knobs ==="
# Regression pin: an earlier version matched ANY "[identifier]" citation,
# which pulled in single-letter / capitalized prose shorthand (real
# example from the live .mli: "[E]" for "entry price E") and produced
# false-positive FAILs against goldens that merely contain the letter
# "E" somewhere in their text. The bracket-citation extraction requires
# a lowercase snake_case identifier (at least one underscore).
REPO9="$(_new_repo)"
mkdir -p "$(dirname "$REPO9/$SURFACE_MLI_REL")" "$REPO9/.github/workflows"
mkdir -p "$REPO9/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "type config = {"
  echo "  knob_c : int; [@sexp.default 0]"
  echo "      (** Entering a position at price [E] is unrelated to [knob_d]. *)"
  echo "  knob_d : bool; [@sexp.default false]"
  echo "}"
} > "$REPO9/$SURFACE_MLI_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO9/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (description \"mentions the letter E and the word Entering in prose\"))"
} > "$REPO9/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA9A="$(_commit "$REPO9" "base")"
sed -i.bak 's/knob_c : int; \[@sexp.default 0\]/knob_c : int; [@sexp.default 26]/' "$REPO9/$SURFACE_MLI_REL"
rm -f "$REPO9/$SURFACE_MLI_REL.bak"
SHA9B="$(_commit "$REPO9" "head: flip knob_c default 0 -> 26")"
_run "$REPO9" "$SHA9A" "$SHA9B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "zero postsubmit golden specs"; then
  pass "assertion 9: [E] / [Entering] excluded from related-knob extraction -> OK"
else
  fail "assertion 9: expected OK/exit0 (non-snake_case citations excluded), got rc=$RC output=$OUT"
fi
rm -rf "$REPO9"

echo ""
echo "=== Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed ==="
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
echo "OK: goldens_affected_check_test -- all assertions passed."
