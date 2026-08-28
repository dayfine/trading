#!/bin/sh
# Smoke test for adapter_effectiveness_check.sh (silent-null config-thread
# guard, issue #2567).
#
# Builds a synthetic fixture tree (REPO_ROOT override, same pattern as
# check_universe_deps_test.sh) so this test never depends on the real
# repo's current field-copy population -- it pins the guard's SCANNING +
# DECISION logic against known-correct fixtures.
#
# Assertions:
#   1. A field-copy line with no EFFECTIVENESS-PIN and no exception -> FAIL,
#      naming the field and the file:line.
#   2. The same field, pinned via a test-file comment -> PASS.
#   3. A field listed in the exceptions file (with a valid review_at) is
#      skipped even with no pin -> PASS.
#   4. A field-copy line inside a */test/*.ml or */bin/*.ml file is NOT
#      scanned (fixtures / one-off binaries are not production threads).
#   5. A line that is NOT the exact "field = config.field2" shape (e.g. a
#      derived expression, "field = not (config.field2)") is not flagged --
#      documents the known regex-is-syntactic-not-semantic limitation.
#   6. An exceptions entry with no parseable review_at annotation -> FAIL,
#      naming the entry.
#   7. Two DIFFERENT field-copy sites for the SAME field name are both
#      satisfied by a single pin (field-name-keyed, not site-keyed).
#  11. A pin tag whose "EFFECTIVENESS-PIN:" prefix and field name are
#      split across two physical lines by ocamlformat's comment reflow
#      (H-ADAPTER-PIN-LINEWRAP, a real bug found on this check's first
#      run against the live repo -- see the assertion's own comment) is
#      still found -> PASS.
#
# Mutation-proof of the detector itself (issue #2567 dispatch "Acceptance"
# requirement -- the #2580 lesson: a check must not be reducible to
# matching nothing while staying green). Two independent mutations are
# applied to a WORKING COPY of the real script (never the fixture data);
# together with assertion 1 (a real fixture with an untested field-copy
# pair -- the positive control) that is >= 3 independent break-directions:
#   8. MUTATION A ("matches nothing") -- narrow the field-copy regex to
#      only match a literal field name that cannot appear in any real
#      fixture ("this_field_does_not_exist") instead of the general
#      shape -- the violating fixture must go from FAIL to a false PASS,
#      AND the false-PASS output must be the DISTINCT "no field-copy
#      lines found" message, not the "every field is pinned or excepted"
#      message a real, fully-audited clean tree would print. This is the
#      #2580 regression shape pinned directly: a detector silently
#      narrowed to vacuous must not read the same as a genuine clean pass.
#   9. MUTATION B (pin-lookup corrupted) -- change the live pin-lookup's
#      literal tag prefix so it can never match a real fixture comment --
#      every previously-pinned field must revert to FAIL, proving the pin
#      lookup (not something else) is what turns assertion 2 green.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/adapter_effectiveness_check_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

CHECK="$(dirname "$0")/adapter_effectiveness_check.sh"
[ -f "$CHECK" ] || die "adapter_effectiveness_check_test: $CHECK not found"

PASS=0
FAIL=0

ok() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

bad() {
  echo "  FAIL: $1" >&2
  FAIL=$((FAIL + 1))
}

FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FAKE_ROOT"' EXIT

mkdir -p "$FAKE_ROOT/.claude"
mkdir -p "$FAKE_ROOT/trading/trading/weinstein/strategy/lib"
mkdir -p "$FAKE_ROOT/trading/trading/weinstein/strategy/test"
mkdir -p "$FAKE_ROOT/trading/trading/weinstein/strategy/bin"
mkdir -p "$FAKE_ROOT/trading/devtools/checks"

# Fixture adapter: one UNPINNED field-copy pair (assertion 1), one
# NON-COPY derived line that must not be flagged (assertion 5).
write_adapter() {
  cat > "$FAKE_ROOT/trading/trading/weinstein/strategy/lib/fixture_adapter.ml" <<'EOF'
let _fixture_config_for ~config =
  {
    Fixture_sub.default_config with
    widget_threshold = config.widget_threshold;
    require_gate = not (config.gate_disabled);
  }
EOF
}

# Fixture in a test/ dir -- must NOT be scanned (assertion 4).
write_test_dir_copy() {
  cat > "$FAKE_ROOT/trading/trading/weinstein/strategy/test/fixture_in_test.ml" <<'EOF'
let _helper_config_for ~config =
  { Fixture_sub.default_config with test_only_field = config.test_only_field }
EOF
}

# Fixture in a bin/ dir -- must NOT be scanned (assertion 4).
write_bin_dir_copy() {
  cat > "$FAKE_ROOT/trading/trading/weinstein/strategy/bin/fixture_in_bin.ml" <<'EOF'
let _runner_config_for ~config =
  { Fixture_sub.default_config with bin_only_field = config.bin_only_field }
EOF
}

# A second file with the SAME field name copied at a different site
# (assertion 7 -- field-name-keyed, not site-keyed).
write_second_site() {
  cat > "$FAKE_ROOT/trading/trading/weinstein/strategy/lib/fixture_adapter_2.ml" <<'EOF'
let _other_config_for ~config =
  { Fixture_sub.default_config with widget_threshold = config.widget_threshold }
EOF
}

reset_pin_and_exceptions() {
  rm -f "$FAKE_ROOT/trading/trading/weinstein/strategy/test/fixture_pin.ml"
  rm -f "$FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
}

write_adapter
write_test_dir_copy
write_bin_dir_copy
reset_pin_and_exceptions

# ============================================================
# Assertion 1: unpinned field-copy -> FAIL, names field + file:line
# ============================================================
set +e
OUT1=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE1=$?
set -e

if [ "$CODE1" -ne 0 ] && echo "$OUT1" | grep -q "widget_threshold" \
  && echo "$OUT1" | grep -q "fixture_adapter.ml:4"; then
  ok "assertion 1 — unpinned field-copy -> FAIL naming field + file:line"
else
  bad "assertion 1 — expected non-zero exit naming widget_threshold at fixture_adapter.ml:4; got exit=$CODE1 output=<<$OUT1>>"
fi

# ============================================================
# Assertion 5: the derived line (require_gate = not (config.gate_disabled))
# must never appear in the guard's output at all.
# ============================================================
if ! echo "$OUT1" | grep -q "gate_disabled"; then
  ok "assertion 5 — derived/conditional line is not flagged (syntactic-only regex, documented limitation)"
else
  bad "assertion 5 — gate_disabled should never appear in guard output; got: $OUT1"
fi

# ============================================================
# Assertion 4: test/ and bin/ dir copies are never scanned.
# ============================================================
if ! echo "$OUT1" | grep -q "test_only_field" && ! echo "$OUT1" | grep -q "bin_only_field"; then
  ok "assertion 4 — field copies inside */test/*.ml and */bin/*.ml are not scanned"
else
  bad "assertion 4 — test_only_field / bin_only_field should never appear in guard output; got: $OUT1"
fi

# ============================================================
# Assertion 2: pin the field via a test-file comment -> PASS
# ============================================================
cat > "$FAKE_ROOT/trading/trading/weinstein/strategy/test/fixture_pin.ml" <<'EOF'
(* A real test would arm config.widget_threshold and assert on the built
   sub-config here. *)
(* EFFECTIVENESS-PIN: widget_threshold *)
let test_widget_threshold_thread _ = ()
EOF

set +e
OUT2=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE2=$?
set -e

if [ "$CODE2" -eq 0 ] && echo "$OUT2" | grep -q "^OK: widget_threshold"; then
  ok "assertion 2 — pinned field -> PASS"
else
  bad "assertion 2 — expected exit 0 with an OK line for widget_threshold; got exit=$CODE2 output=<<$OUT2>>"
fi

# ============================================================
# Assertion 7: a SECOND site copying the same field name is also
# satisfied by the one pin (field-name-keyed, not site-keyed).
# ============================================================
write_second_site

set +e
OUT7=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE7=$?
set -e

if [ "$CODE7" -eq 0 ] && echo "$OUT7" | grep -q "^OK: widget_threshold"; then
  ok "assertion 7 — a second site for the same field name is covered by the one pin"
else
  bad "assertion 7 — expected exit 0 with an OK line for widget_threshold with two sites; got exit=$CODE7 output=<<$OUT7>>"
fi

rm -f "$FAKE_ROOT/trading/trading/weinstein/strategy/lib/fixture_adapter_2.ml"

# ============================================================
# Assertion 11 (H-ADAPTER-PIN-LINEWRAP, a REAL bug found on this check's
# first run against the live repo): ocamlformat reflows odoc comments,
# and does NOT keep "EFFECTIVENESS-PIN:" and the field name on the same
# physical line -- confirmed on main:
# test_stock_analysis_config_wiring.ml's virgin_crossing_readmission pin
# was wrapped to "... EFFECTIVENESS-PIN:\n    virgin_crossing_readmission
# -- same mechanism ..." by `dune build @fmt --auto-promote`, and a
# naive per-line grep missed it entirely -- a false FAIL on a field that
# WAS genuinely pinned. Reproduce that exact shape in the fixture and
# confirm the (fixed) checker still finds it.
# ============================================================
rm -f "$FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
printf '(* EFFECTIVENESS-PIN:\n   widget_threshold -- wrapped onto the next line by ocamlformat *)\nlet test_widget_threshold_thread _ = ()\n' \
  > "$FAKE_ROOT/trading/trading/weinstein/strategy/test/fixture_pin.ml"

set +e
OUT11=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE11=$?
set -e

if [ "$CODE11" -eq 0 ] && echo "$OUT11" | grep -q "^OK: widget_threshold"; then
  ok "assertion 11 — a pin tag wrapped across two lines by ocamlformat is still found (H-ADAPTER-PIN-LINEWRAP)"
else
  bad "assertion 11 — expected exit 0 with an OK line for a line-wrapped pin tag; got exit=$CODE11 output=<<$OUT11>>"
fi

# ============================================================
# Assertion 3: remove the pin, add an exceptions entry instead -> PASS
# ============================================================
rm -f "$FAKE_ROOT/trading/trading/weinstein/strategy/test/fixture_pin.ml"
cat > "$FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf" <<'EOF'
widget_threshold  # review_at: 2026-12-01 (test fixture)
EOF

set +e
OUT3=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE3=$?
set -e

if [ "$CODE3" -eq 0 ] && echo "$OUT3" | grep -q "SKIP (exceptions list): widget_threshold"; then
  ok "assertion 3 — exceptions-listed field skipped, overall PASS"
else
  bad "assertion 3 — expected exit 0 with a SKIP line for widget_threshold; got exit=$CODE3 output=<<$OUT3>>"
fi

# ============================================================
# Assertion 6: exceptions entry with no review_at -> FAIL
# ============================================================
cat > "$FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf" <<'EOF'
widget_threshold
EOF

set +e
OUT6=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE6=$?
set -e

if [ "$CODE6" -ne 0 ] && echo "$OUT6" | grep -q "widget_threshold" && echo "$OUT6" | grep -qi "review_at"; then
  ok "assertion 6 — exceptions entry with no review_at -> FAIL, naming the entry"
else
  bad "assertion 6 — expected non-zero exit naming widget_threshold with a review_at complaint; got exit=$CODE6 output=<<$OUT6>>"
fi

reset_pin_and_exceptions

# ============================================================
# Mutation-proof block (assertions 8-10): apply three independent
# break-directions to a WORKING COPY of the real detector script and
# confirm each moves the RED/GREEN verdict as expected. This is what
# proves the detector itself is load-bearing, not vacuously green.
# ============================================================
# The mutated copy must live alongside a real _check_lib.sh (it sources
# "$(dirname "$0")/_check_lib.sh"), so use a directory, not a bare
# mktemp file.
MUT_DIR="$(mktemp -d)"
trap 'rm -rf "$FAKE_ROOT" "$MUT_DIR"' EXIT
cp "$(dirname "$0")/_check_lib.sh" "$MUT_DIR/_check_lib.sh"
MUT_CHECK="$MUT_DIR/adapter_effectiveness_check.sh"

# --- Mutation A: narrow the field-copy regex to only ever match a field
# name that cannot appear in any real fixture. If the detector's
# generality is load-bearing, this must turn the assertion-1 FAIL into a
# false PASS (nothing found) -- proving the real (unmutated) regex is
# actually doing the work, not incidentally matching.
sed 's/config\\\.\[a-z\]\[A-Za-z0-9_\]\*/config\\.this_field_does_not_exist/' \
  "$CHECK" > "$MUT_CHECK"
chmod +x "$MUT_CHECK"

set +e
OUT8=$(REPO_ROOT="$FAKE_ROOT" sh "$MUT_CHECK" 2>&1)
CODE8=$?
set -e

if [ "$CODE8" -eq 0 ] && echo "$OUT8" | grep -q "no field-copy-into-sub-config lines found"; then
  ok "assertion 8 — MUTATION A (regex narrowed to a nonexistent field name) flips FAIL -> false PASS, proving the real regex is load-bearing"
else
  bad "assertion 8 — expected the narrowed-regex mutation to produce a false PASS (no lines found); got exit=$CODE8 output=<<$OUT8>>"
fi

# --- Mutation B: corrupt the pin lookup to grep for a tag that can never
# appear. A previously-pinned field must revert to FAIL, proving the pin
# lookup (not something else) is what turns assertion 2 green.
cat > "$FAKE_ROOT/trading/trading/weinstein/strategy/test/fixture_pin.ml" <<'EOF'
(* EFFECTIVENESS-PIN: widget_threshold *)
let test_widget_threshold_thread _ = ()
EOF
# Global text substitution of the tag's literal prefix -- simpler and less
# fragile than trying to hand-escape the bracket-heavy live regex, and it
# still corrupts the exact grep pattern the pin lookup depends on (every
# occurrence of the literal string is part of either the live lookup or
# human-facing help text; mutating both is fine, the assertion only cares
# that the LOOKUP no longer matches the fixture's tag comment).
sed 's/EFFECTIVENESS-PIN/EFFECTIVENESS-PIN-NEVER-MATCHES/g' "$CHECK" > "$MUT_CHECK"
chmod +x "$MUT_CHECK"

set +e
OUT9=$(REPO_ROOT="$FAKE_ROOT" sh "$MUT_CHECK" 2>&1)
CODE9=$?
set -e

if [ "$CODE9" -ne 0 ] && echo "$OUT9" | grep -q "widget_threshold"; then
  ok "assertion 9 — MUTATION B (pin-lookup tag corrupted) reverts a previously-pinned field to FAIL, proving the lookup is load-bearing"
else
  bad "assertion 9 — expected the corrupted-pin-lookup mutation to FAIL naming widget_threshold; got exit=$CODE9 output=<<$OUT9>>"
fi

reset_pin_and_exceptions

echo ""
echo "adapter_effectiveness_check_test: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
