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
#   8. Docstring cross-reference (Step 2.5) catches a golden that arms a
#      RELATED knob (cited via "[bracket]" syntax), not the changed one
#      -> FAIL naming "related-via:<changed knob>".
#   9. Non-snake_case bracket citations ("[E]", "[Entering]") are NOT
#      treated as related-knob citations -> OK, exit 0.
#   10. A docstring containing prose "Word:" lines (e.g. "Motivation:",
#       "bug:") BEFORE its genuine "[bracket]" citation does not
#       falsely end the field-declaration block early -> still FAIL,
#       naming the related knob. Mutation-tested: loosening the Step 2.5
#       anchor to match any-indentation "identifier:" makes this
#       assertion (and only this one) fail while the rest of the suite
#       stays green -- see PR #2482 review + this fixture's own comment.
#   11. live-config-overrides.sexp: a NESTED config-record line
#       ("((portfolio_config ((max_position_pct_long 0.14))))") is
#       matched at the OUTER identifier ("portfolio_config") -> FAIL
#       naming "portfolio_config".
#   12. Same nested-record line, but the golden references only the
#       NESTED field name ("max_position_pct_long") and never the outer
#       identifier -> OK, exit 0. Pins the documented known-gap: outer-
#       identifier-only extraction is a false negative for a golden
#       keyed on the nested name alone.
#   13. Acknowledgment path (GOLDENS_AFFECTED_ACK=1): the same
#       knob+golden match that produces a FAIL in assertion 4 instead
#       exits 0 with an "OK (acknowledged)" notice that still lists the
#       affected golden and points at the PR-body requirement.
#   14. (#2531 gap a) A [@sexp.default flip in a NESTED config file
#       (stops/lib/stop_types.mli — outside the old two-file list) that
#       a golden arms -> FAIL.
#   15. (#2531 gap b) A default_config record-literal value change for
#       a REQUIRED field (no [@sexp.default] anywhere) that a golden
#       arms -> FAIL (Step 2b).
#   16. A field-shaped assignment changed inside ORDINARY (non-default)
#       code in a surface .ml -> OK (Step 2b extracts only from
#       top-level `let default*` bindings — no false positive).
#   17. A [@sexp.default change in a test/ file -> OK (the /lib/ filter
#       keeps test fixtures outside the surface).
#   18. (#2531 gap a, historical shape) The golden names only the OUTER
#       embedding field ("stops_config"), never the flipped inner knob
#       -> still FAIL via Step 2c's embedding-field emission.
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

# _run <repo> <base-sha> <head-sha> [ack] — invokes the real script with
# REPO_ROOT pinned to the fixture repo; captures combined output + exit
# code into globals OUT / RC (POSIX sh has no local return-by-value, and
# this test never runs assertions concurrently, so plain globals are
# safe here). Optional 4th arg "ack" sets GOLDENS_AFFECTED_ACK=1, mirroring
# what goldens-affected.yml does when the PR carries the 'paired-run-done'
# label (assertion 13).
_run() {
  repo="$1"
  base="$2"
  head="$3"
  ack="${4:-}"
  set +e
  if [ "$ack" = "ack" ]; then
    OUT="$(REPO_ROOT="$repo" GOLDENS_AFFECTED_ACK=1 sh "$SCRIPT" "$base" "$head" 2>&1)"
  else
    OUT="$(REPO_ROOT="$repo" sh "$SCRIPT" "$base" "$head" 2>&1)"
  fi
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

echo "=== Assertion 10: docstring prose 'Word:' lines before the genuine [bracket] citation do not truncate the field-declaration block early ==="
# Pins the CP4 gap qc-behavioral flagged on PR #2482: the Step 2.5 field-
# declaration anchor requires EXACTLY two leading spaces so that prose
# lines like "Motivation:" / "bug:" -- indented as docstring BODY text,
# not as a field declaration -- are never mistaken for the next field
# and don't falsely end the block before its real [bracket] citation.
# Mirrors the actual entry_order_max_rest_weeks docstring shape that
# motivated this guard (see goldens_affected_check.sh's own comment at
# the anchor). MUTATION-TESTED: replacing the anchor with the looser
# `^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*:[ \t]*[A-Za-z(]` form (any
# indentation) makes ONLY this assertion fail -- the "Motivation:" line
# below satisfies that looser pattern and ends the block before reaching
# "[knob_b]" -- while assertions 1-9 and 11-13 stay green.
REPO10="$(_new_repo)"
mkdir -p "$(dirname "$REPO10/$SURFACE_MLI_REL")" "$REPO10/.github/workflows"
mkdir -p "$REPO10/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "type config = {"
  echo "  knob_a : int; [@sexp.default 0]"
  echo "      (** Old-format long docstring."
  echo ""
  echo "          Motivation: in a fast V-crash the ticket rests too long."
  echo ""
  echo "          bug: a ticket placed on review week N would linger."
  echo ""
  echo "          See [knob_b] -- the only place a clock can bite. *)"
  echo "  knob_b : bool; [@sexp.default false]"
  echo "      (** Unrelated field. *)"
  echo "}"
} > "$REPO10/$SURFACE_MLI_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO10/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((knob_b true)))))"
} > "$REPO10/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA10A="$(_commit "$REPO10" "base")"
sed -i.bak 's/knob_a : int; \[@sexp.default 0\]/knob_a : int; [@sexp.default 26]/' "$REPO10/$SURFACE_MLI_REL"
rm -f "$REPO10/$SURFACE_MLI_REL.bak"
SHA10B="$(_commit "$REPO10" "head: flip knob_a default 0 -> 26")"
_run "$REPO10" "$SHA10A" "$SHA10B"
if [ "$RC" -eq 1 ] \
  && echo "$OUT" | grep -q "knob_b" \
  && echo "$OUT" | grep -q "related-via:knob_a" \
  && echo "$OUT" | grep -q "fixture-golden.sexp"; then
  pass "assertion 10: prose 'Word:' lines do not truncate the block before [knob_b]"
else
  fail "assertion 10: expected FAIL/exit1 naming knob_b via related-via:knob_a despite prose colons, got rc=$RC output=$OUT"
fi
rm -rf "$REPO10"

echo "=== Assertion 11: live-config-overrides.sexp nested config-record line is matched at the OUTER identifier -> FAIL ==="
# Pins the header comment's documented claim (Step 2, "Nested config
# records ... are only matched at the OUTER identifier"): a change that
# adds "((portfolio_config ((max_position_pct_long 0.14))))" is detected
# as a change to "portfolio_config", the outer name -- which is exactly
# what a golden's config_overrides entry keys on.
REPO11="$(_new_repo)"
mkdir -p "$REPO11/dev/weekly-picks" "$REPO11/.github/workflows"
mkdir -p "$REPO11/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "; live overrides, empty at base"
} > "$REPO11/$SURFACE_OVERRIDES_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO11/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((portfolio_config ((max_position_pct_long 0.20)))))))"
} > "$REPO11/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA11A="$(_commit "$REPO11" "base")"
echo "((portfolio_config ((max_position_pct_long 0.14))))" >> "$REPO11/$SURFACE_OVERRIDES_REL"
SHA11B="$(_commit "$REPO11" "head: arm nested portfolio_config override")"
_run "$REPO11" "$SHA11A" "$SHA11B"
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "'portfolio_config'"; then
  pass "assertion 11: nested config-record line matched at the outer identifier -> FAIL"
else
  fail "assertion 11: expected FAIL/exit1 naming portfolio_config, got rc=$RC output=$OUT"
fi
rm -rf "$REPO11"

echo "=== Assertion 12: golden references ONLY the nested field name, never the outer identifier -> OK (documented known gap) ==="
# Same nested-record change as assertion 11, but the golden's text
# contains only "max_position_pct_long", never "portfolio_config". Per
# the header comment this is a known false negative, not a defect --
# this assertion pins that the documented gap is real current behaviour
# rather than an accidental claim with no fixture.
REPO12="$(_new_repo)"
mkdir -p "$REPO12/dev/weekly-picks" "$REPO12/.github/workflows"
mkdir -p "$REPO12/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "; live overrides, empty at base"
} > "$REPO12/$SURFACE_OVERRIDES_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO12/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((max_position_pct_long 0.20)))))"
} > "$REPO12/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA12A="$(_commit "$REPO12" "base")"
echo "((portfolio_config ((max_position_pct_long 0.14))))" >> "$REPO12/$SURFACE_OVERRIDES_REL"
SHA12B="$(_commit "$REPO12" "head: arm nested portfolio_config override")"
_run "$REPO12" "$SHA12A" "$SHA12B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "zero postsubmit golden specs"; then
  pass "assertion 12: nested-field-only golden not matched (known gap) -> OK"
else
  fail "assertion 12: expected OK/exit0 (outer-only extraction misses nested-only reference), got rc=$RC output=$OUT"
fi
rm -rf "$REPO12"

echo "=== Assertion 13: GOLDENS_AFFECTED_ACK=1 downgrades a real match to OK (acknowledged) ==="
# Reuses assertion 4's exact fixture (a real FAIL) but runs it with the
# ack env var goldens-affected.yml sets from the 'paired-run-done' label
# (B3 resolution path, PR #2482 rework). Exit must flip to 0, and the
# notice must still name the affected golden plus point at the PR-body
# requirement -- the label acknowledges the paired run happened, it
# doesn't hide which golden was affected.
REPO13="$(_make_default_change_repo yes yes yes goldens-sp500)"
SHA13A="$(_commit "$REPO13" "base")"
sed -i.bak 's/\[@sexp.default 0\]/[@sexp.default 26]/' "$REPO13/$SURFACE_MLI_REL"
rm -f "$REPO13/$SURFACE_MLI_REL.bak"
SHA13B="$(_commit "$REPO13" "head: flip default 0 -> 26")"
_run "$REPO13" "$SHA13A" "$SHA13B" ack
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q "acknowledged" \
  && echo "$OUT" | grep -q "fixture-golden.sexp" \
  && echo "$OUT" | grep -q "PR body"; then
  pass "assertion 13: GOLDENS_AFFECTED_ACK=1 downgrades FAIL to OK (acknowledged), still naming the golden"
else
  fail "assertion 13: expected OK/exit0 acknowledged notice naming the golden, got rc=$RC output=$OUT"
fi
rm -rf "$REPO13"

echo "=== Assertion 14: nested-config file (stops/lib/stop_types.mli) [@sexp.default flip armed by a golden -> FAIL ==="
# Pins the #2531 gap (b-file): reset_anchor_on_stalled_cycle's default
# lives in trading/trading/weinstein/stops/lib/stop_types.{ml,mli} —
# entirely outside the old two-file scan list. The whole-subtree surface
# must catch a default flip there.
NESTED_MLI_REL="trading/trading/weinstein/stops/lib/stop_types.mli"
REPO14="$(_new_repo)"
mkdir -p "$(dirname "$REPO14/$NESTED_MLI_REL")" "$REPO14/.github/workflows"
mkdir -p "$REPO14/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "type config = {"
  echo "  reset_anchor_on_stalled_cycle : bool; [@sexp.default false]"
  echo "}"
} > "$REPO14/$NESTED_MLI_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO14/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((stops_config ((reset_anchor_on_stalled_cycle false)))))))"
} > "$REPO14/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA14A="$(_commit "$REPO14" "base")"
sed -i.bak 's/\[@sexp.default false\]/[@sexp.default true]/' "$REPO14/$NESTED_MLI_REL"
rm -f "$REPO14/$NESTED_MLI_REL.bak"
SHA14B="$(_commit "$REPO14" "head: flip reset_anchor_on_stalled_cycle default")"
_run "$REPO14" "$SHA14A" "$SHA14B"
if [ "$RC" -eq 1 ] \
  && echo "$OUT" | grep -q "reset_anchor_on_stalled_cycle" \
  && echo "$OUT" | grep -q "fixture-golden.sexp"; then
  pass "assertion 14: nested-config-file default flip caught"
else
  fail "assertion 14: expected FAIL/exit1 naming reset_anchor_on_stalled_cycle, got rc=$RC output=$OUT"
fi
rm -rf "$REPO14"

echo "=== Assertion 15: default_config record-literal value change (no [@sexp.default]) armed by a golden -> FAIL ==="
# Pins the #2531 gap (b-shape): initial_stop_buffer is a REQUIRED field;
# its default lives only in the default_config record literal. Step 2b
# must extract the changed field from the literal region.
REPO15="$(_new_repo)"
mkdir -p "$(dirname "$REPO15/$SURFACE_ML_REL")" "$REPO15/.github/workflows"
mkdir -p "$REPO15/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "let default_config ~universe ~index_symbol ="
  echo "  {"
  echo "    universe;"
  echo "    initial_stop_buffer = 1.02;"
  echo "    lookback_bars = 52;"
  echo "  }"
} > "$REPO15/$SURFACE_ML_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO15/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((initial_stop_buffer 1.02)))))"
} > "$REPO15/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA15A="$(_commit "$REPO15" "base")"
sed -i.bak 's/initial_stop_buffer = 1.02;/initial_stop_buffer = 1.0;/' "$REPO15/$SURFACE_ML_REL"
rm -f "$REPO15/$SURFACE_ML_REL.bak"
SHA15B="$(_commit "$REPO15" "head: flip initial_stop_buffer literal 1.02 -> 1.0")"
_run "$REPO15" "$SHA15A" "$SHA15B"
if [ "$RC" -eq 1 ] \
  && echo "$OUT" | grep -q "initial_stop_buffer" \
  && echo "$OUT" | grep -q "fixture-golden.sexp"; then
  pass "assertion 15: default_config record-literal change caught"
else
  fail "assertion 15: expected FAIL/exit1 naming initial_stop_buffer, got rc=$RC output=$OUT"
fi
rm -rf "$REPO15"

echo "=== Assertion 16: surface .ml change OUTSIDE any default binding -> OK (no false positive) ==="
# Guards Step 2b's precision: a field-shaped assignment inside ordinary
# (non-default) code must not be extracted as a knob.
REPO16="$(_new_repo)"
mkdir -p "$(dirname "$REPO16/$SURFACE_ML_REL")" "$REPO16/.github/workflows"
mkdir -p "$REPO16/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "let default_config ~universe ~index_symbol ="
  echo "  {"
  echo "    initial_stop_buffer = 1.0;"
  echo "  }"
  echo "let apply_thing t ="
  echo "  {"
  echo "    initial_stop_buffer = t.buffer;"
  echo "  }"
} > "$REPO16/$SURFACE_ML_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO16/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((initial_stop_buffer 1.02)))))"
} > "$REPO16/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA16A="$(_commit "$REPO16" "base")"
sed -i.bak 's/initial_stop_buffer = t.buffer;/initial_stop_buffer = t.buffer2;/' "$REPO16/$SURFACE_ML_REL"
rm -f "$REPO16/$SURFACE_ML_REL.bak"
SHA16B="$(_commit "$REPO16" "head: change non-default code only")"
_run "$REPO16" "$SHA16A" "$SHA16B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no \[@sexp.default"; then
  pass "assertion 16: non-default-binding change not extracted -> OK"
else
  fail "assertion 16: expected OK/exit0, got rc=$RC output=$OUT"
fi
rm -rf "$REPO16"

echo "=== Assertion 17: [@sexp.default change in a test/ file is outside the surface -> OK ==="
# The /lib/ filter keeps test fixtures out: a [@sexp.default line in a
# test .ml is not a default anyone inherits.
TEST_ML_REL="trading/trading/weinstein/stops/test/test_fixture.ml"
REPO17="$(_new_repo)"
mkdir -p "$(dirname "$REPO17/$TEST_ML_REL")" "$REPO17/.github/workflows"
mkdir -p "$REPO17/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "type fixture = {"
  echo "  catastrophic_stop_pct : float; [@sexp.default 0.0]"
  echo "}"
} > "$REPO17/$TEST_ML_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO17/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((stops_config ((catastrophic_stop_pct 0.10)))))))"
} > "$REPO17/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA17A="$(_commit "$REPO17" "base")"
sed -i.bak 's/\[@sexp.default 0.0\]/[@sexp.default 0.5]/' "$REPO17/$TEST_ML_REL"
rm -f "$REPO17/$TEST_ML_REL.bak"
SHA17B="$(_commit "$REPO17" "head: change test fixture default")"
_run "$REPO17" "$SHA17A" "$SHA17B"
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no \[@sexp.default"; then
  pass "assertion 17: test-file default change outside surface -> OK"
else
  fail "assertion 17: expected OK/exit0 (test files excluded), got rc=$RC output=$OUT"
fi
rm -rf "$REPO17"

echo "=== Assertion 18: nested-config default change caught via the EMBEDDING field when the golden names only the outer identifier -> FAIL ==="
# The historical #2530 shape exactly: the golden's config_overrides arms
# ((stops_config ((catastrophic_stop_pct 0.10)))) and never names the
# flipped inner knob; the inner default changes in stop_types.mli. Step
# 2c must flag it via the outer `stops_config` embedding field.
REPO18="$(_new_repo)"
mkdir -p "$(dirname "$REPO18/$NESTED_MLI_REL")" "$REPO18/.github/workflows"
mkdir -p "$REPO18/trading/test_data/backtest_scenarios/goldens-sp500"
{
  echo "type config = {"
  echo "  reset_anchor_on_stalled_cycle : bool; [@sexp.default false]"
  echo "}"
} > "$REPO18/$NESTED_MLI_REL"
{
  echo "      GOLDEN_SP500_SUBDIRS: goldens-sp500"
} > "$REPO18/.github/workflows/golden-runs-fixture.yml"
{
  echo "((name \"fixture-golden\")"
  echo " (config_overrides (((stops_config ((catastrophic_stop_pct 0.10)))))))"
} > "$REPO18/trading/test_data/backtest_scenarios/goldens-sp500/fixture-golden.sexp"
SHA18A="$(_commit "$REPO18" "base")"
sed -i.bak 's/\[@sexp.default false\]/[@sexp.default true]/' "$REPO18/$NESTED_MLI_REL"
rm -f "$REPO18/$NESTED_MLI_REL.bak"
SHA18B="$(_commit "$REPO18" "head: flip nested default")"
_run "$REPO18" "$SHA18A" "$SHA18B"
if [ "$RC" -eq 1 ] \
  && echo "$OUT" | grep -q "'stops_config'" \
  && echo "$OUT" | grep -q "embeds:stop_types.mli" \
  && echo "$OUT" | grep -q "fixture-golden.sexp"; then
  pass "assertion 18: outer embedding field flags the golden that never names the inner knob"
else
  fail "assertion 18: expected FAIL/exit1 naming stops_config via embeds:stop_types.mli, got rc=$RC output=$OUT"
fi
rm -rf "$REPO18"

echo ""
echo "=== Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed ==="
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
echo "OK: goldens_affected_check_test -- all assertions passed."
