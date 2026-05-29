#!/usr/bin/env bash
# test_extract_metrics.sh — smoke test for dev/scripts/lib/extract_metrics.sh.
#
# Verifies the helpers used by promote_config.sh's cross-scenario validation
# step parse a real-shape actual.sexp correctly, with explicit coverage for
# the Calmar + Sortino fields added under the 2026-05-29 reframed gate.
#
# Run:
#   bash dev/scripts/test_extract_metrics.sh
#
# Exit: 0 on success, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/extract_metrics.sh"

TMP_BASE="$(mktemp -d -t extract_metrics_test.XXXXXX)"
trap 'rm -rf "${TMP_BASE}"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  PASS: $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

assert_eq() {
  # assert_eq <description> <actual> <expected>
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$desc"
  else
    fail "$desc — expected '$expected', got '$actual'"
  fi
}

# Sample actual.sexp body matching the shape emitted by scenario_runner.exe
# (lifted from a real 2026-05-29 sp500-2010-2026 run). The trailing fields
# (force_liquidations_count, crashed, crash_message) are included because
# real actual.sexps carry them; the extractor should be unaffected.
ACTUAL_SEXP="${TMP_BASE}/actual.sexp"
cat > "${ACTUAL_SEXP}" <<'EOF'
((total_return_pct 296.49190416254925) (total_trades 389)
 (win_rate 35.732647814910024) (sharpe_ratio 0.73551363113327972)
 (max_drawdown_pct 15.848585379540324) (avg_holding_days 83.151670951156817)
 (open_positions_value 3521015.0714) (unrealized_pnl 434533.86503149988)
 (sortino_ratio_annualized 1.1444644384357856)
 (calmar_ratio 0.55548519115359263) (ulcer_index 5.4973598250647333)
 (force_liquidations_count 0) (crashed false) (crash_message ""))
EOF

# ---------------------------------------------------------------------------
# extract_metric — Calmar / Sortino are the load-bearing new fields
# ---------------------------------------------------------------------------
assert_eq "extract_metric calmar_ratio" \
  "$(extract_metric "${ACTUAL_SEXP}" calmar_ratio)" \
  "0.55548519115359263"
assert_eq "extract_metric sortino_ratio_annualized" \
  "$(extract_metric "${ACTUAL_SEXP}" sortino_ratio_annualized)" \
  "1.1444644384357856"

# Pre-existing fields still extract correctly (regression coverage).
assert_eq "extract_metric sharpe_ratio" \
  "$(extract_metric "${ACTUAL_SEXP}" sharpe_ratio)" \
  "0.73551363113327972"
assert_eq "extract_metric total_return_pct" \
  "$(extract_metric "${ACTUAL_SEXP}" total_return_pct)" \
  "296.49190416254925"
assert_eq "extract_metric max_drawdown_pct" \
  "$(extract_metric "${ACTUAL_SEXP}" max_drawdown_pct)" \
  "15.848585379540324"
assert_eq "extract_metric total_trades (integer)" \
  "$(extract_metric "${ACTUAL_SEXP}" total_trades)" \
  "389"

# Missing field returns empty.
assert_eq "extract_metric missing_field" \
  "$(extract_metric "${ACTUAL_SEXP}" no_such_field)" \
  ""

# ---------------------------------------------------------------------------
# signed_delta — used to produce per-scenario rows for validation.sexp
# ---------------------------------------------------------------------------
# Candidate Calmar 0.5555 vs baseline 0.52 → +0.0355.
assert_eq "signed_delta calmar (improvement)" \
  "$(signed_delta 0.5555 0.52)" \
  "+0.0355"
# Candidate Sortino 1.1445 vs baseline 1.25 → -0.1055.
assert_eq "signed_delta sortino (regression)" \
  "$(signed_delta 1.1445 1.25)" \
  "-0.1055"

# ---------------------------------------------------------------------------
# regresses_by_more_than — the gate primitive used at the call site
# ---------------------------------------------------------------------------
# Direct regression check (positive threshold): baseline-actual > threshold.
# Calmar baseline 0.52, actual 0.40 → diff 0.12; threshold 0.05 → trips.
if regresses_by_more_than 0.40 0.52 0.05; then
  pass "regresses_by_more_than(0.40, 0.52, 0.05) → fires (regression 0.12 > 0.05)"
else
  fail "regresses_by_more_than(0.40, 0.52, 0.05) — expected fire"
fi
# Same baseline + actual, looser threshold 0.20 → does NOT trip.
if ! regresses_by_more_than 0.40 0.52 0.20; then
  pass "regresses_by_more_than(0.40, 0.52, 0.20) → does not fire (0.12 < 0.20)"
else
  fail "regresses_by_more_than(0.40, 0.52, 0.20) — expected no-fire"
fi
# Improvement case: actual > baseline → never fires regardless of threshold.
if ! regresses_by_more_than 0.60 0.52 0.05; then
  pass "regresses_by_more_than(0.60, 0.52, 0.05) → no-fire (improvement)"
else
  fail "regresses_by_more_than(0.60, 0.52, 0.05) — expected no-fire on improvement"
fi
# Negative threshold (env var convention: "require improvement"):
# threshold=-0.05 means gate trips unless actual >= baseline + 0.05.
# Calmar baseline 0.52, actual 0.55 → diff 0.52-0.55 = -0.03; -0.03 > -0.05 → trips.
if regresses_by_more_than 0.55 0.52 -0.05; then
  pass "regresses_by_more_than(0.55, 0.52, -0.05) → fires (require improvement +0.05, only got +0.03)"
else
  fail "regresses_by_more_than(0.55, 0.52, -0.05) — expected fire under require-improvement convention"
fi
# Calmar baseline 0.52, actual 0.60 → diff -0.08 ≤ -0.05 → does NOT trip.
if ! regresses_by_more_than 0.60 0.52 -0.05; then
  pass "regresses_by_more_than(0.60, 0.52, -0.05) → no-fire (improvement +0.08 ≥ require +0.05)"
else
  fail "regresses_by_more_than(0.60, 0.52, -0.05) — expected no-fire on sufficient improvement"
fi

# ---------------------------------------------------------------------------
# Dry-run gate scenario — 2026-05-29 laggard-OFF candidate vs cell-E baseline
# ---------------------------------------------------------------------------
# Mirrors the verification described in the PR body: against the real
# 2026-05-29 laggard-OFF actual.sexp output, the new gates should correctly
# REJECT the candidate. Baselines pinned from the panel scenario sexp headers.
LAGGARD_OFF="${TMP_BASE}/laggard_off_2010_2026.sexp"
cat > "${LAGGARD_OFF}" <<'EOF'
((total_return_pct 296.49190416254925) (total_trades 389)
 (win_rate 35.732647814910024) (sharpe_ratio 0.73551363113327972)
 (max_drawdown_pct 15.848585379540324) (avg_holding_days 83.151670951156817)
 (open_positions_value 3521015.0714) (unrealized_pnl 434533.86503149988)
 (sortino_ratio_annualized 1.1444644384357856)
 (calmar_ratio 0.55548519115359263) (ulcer_index 5.4973598250647333)
 (force_liquidations_count 0) (crashed false) (crash_message ""))
EOF

cand_calmar=$(extract_metric "${LAGGARD_OFF}" calmar_ratio)
cand_sortino=$(extract_metric "${LAGGARD_OFF}" sortino_ratio_annualized)
cand_return=$(extract_metric "${LAGGARD_OFF}" total_return_pct)

# Baseline pinned values from goldens-sp500-historical/sp500-2010-2026.sexp.
base_calmar="0.52"; base_sortino="1.25"; base_return="341.69"

# Defaults: CALMAR_DELTA_MIN=-0.05, SORTINO_DELTA_MIN=-0.05, CAGR_MAX_PP=2.0.
# Calmar: candidate 0.5555 > 0.52 → improvement → no trip on -0.05 threshold.
if ! regresses_by_more_than "$cand_calmar" "$base_calmar" 0.05; then
  pass "laggard-off dry-run: Calmar gate PASSES (delta +0.036 within -0.05 tolerance)"
else
  fail "laggard-off dry-run: Calmar gate should PASS but tripped"
fi
# Sortino: candidate 1.1445 vs 1.25 → delta -0.1055 → regression > 0.05 → TRIP.
if regresses_by_more_than "$cand_sortino" "$base_sortino" 0.05; then
  pass "laggard-off dry-run: Sortino gate FAILS (delta -0.106 exceeds -0.05 tolerance) — correct rejection"
else
  fail "laggard-off dry-run: Sortino gate should FAIL (regression -0.106) but passed"
fi
# CAGR: total_return 296.49 vs 341.69 → drop 45.2pp → TRIP on 2.0pp floor.
if regresses_by_more_than "$cand_return" "$base_return" 2.0; then
  pass "laggard-off dry-run: CAGR floor FAILS (drop 45.2pp exceeds 2.0pp floor) — correct rejection"
else
  fail "laggard-off dry-run: CAGR floor should FAIL but passed"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "test_extract_metrics: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
