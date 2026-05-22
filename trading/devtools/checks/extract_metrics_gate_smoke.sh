#!/bin/sh
# Smoke test: pin the runtime semantics of the gate helpers in
# dev/scripts/lib/extract_metrics.sh used by dev/scripts/promote_config.sh.
#
# Exercises three helpers without invoking scenario_runner (which costs
# 15-60 min per panel scenario). Mocked actual.sexp values cover:
#   - regresses_by_more_than for Sharpe (higher-is-better): pass + fail
#   - regresses_by_more_than swapped for MaxDD (lower-is-better): pass + fail
#   - trades_out_of_ratio: within bounds + above + below
#
# Required per memory feedback_promote_config_3_bugs_one_week.md — the
# script has had 3 fix-forward bugs in 24h that surfaced only at first
# real usage. Catches future gate-logic regressions before they ship.

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="extract_metrics_gate_smoke"

REPO="$(repo_root)"
LIB="$REPO/dev/scripts/lib/extract_metrics.sh"

if [ ! -f "$LIB" ]; then
  die "${LABEL} — missing $LIB"
fi

# shellcheck disable=SC1090
. "$LIB"

fail_count=0
check() {
  desc="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok: $desc"
  else
    echo "  FAIL: $desc (expected exit=$expected, got exit=$actual)" >&2
    fail_count=$((fail_count + 1))
  fi
}

# Run a predicate and capture its exit code without tripping set -e.
exit_of() {
  set +e
  "$@" >/dev/null 2>&1
  rc=$?
  set -e
  echo "$rc"
}

# --- regresses_by_more_than: Sharpe (higher-is-better) ---
# baseline 0.78, actual 0.65, threshold 0.10 → (0.78-0.65)=0.13 > 0.10 → fail (exit 0)
check "Sharpe regression > threshold flags fail" "0" \
  "$(exit_of regresses_by_more_than 0.65 0.78 0.10)"
# baseline 0.78, actual 0.75, threshold 0.10 → (0.78-0.75)=0.03 ≤ 0.10 → pass (exit 1)
check "Sharpe regression within threshold flags pass" "1" \
  "$(exit_of regresses_by_more_than 0.75 0.78 0.10)"
# baseline 0.78, actual 0.85 (better), threshold 0.10 → improvement → pass (exit 1)
check "Sharpe improvement flags pass" "1" \
  "$(exit_of regresses_by_more_than 0.85 0.78 0.10)"

# --- regresses_by_more_than: MaxDD (lower-is-better, args swapped) ---
# call form: regresses_by_more_than <cell_e_max_dd> <actual_max_dd> <threshold>
# cell_e=21.56, actual=30.58, threshold=5.0 → (30.58-21.56)=9.02 > 5.0 → fail (exit 0)
check "MaxDD increase > 5pp flags fail" "0" \
  "$(exit_of regresses_by_more_than 21.56 30.58 5.0)"
# cell_e=21.56, actual=25.0, threshold=5.0 → (25.0-21.56)=3.44 ≤ 5.0 → pass (exit 1)
check "MaxDD increase within 5pp flags pass" "1" \
  "$(exit_of regresses_by_more_than 21.56 25.0 5.0)"
# cell_e=21.56, actual=18.0 (lower MaxDD is improvement) → pass (exit 1)
check "MaxDD improvement flags pass" "1" \
  "$(exit_of regresses_by_more_than 21.56 18.0 5.0)"

# --- trades_out_of_ratio ---
# baseline 264, actual 259, ratio 2.0 → within → pass (exit 1)
check "trades within ratio flags pass" "1" \
  "$(exit_of trades_out_of_ratio 259 264 2.0)"
# baseline 264, actual 600, ratio 2.0 → 600 > 264*2=528 → fail (exit 0)
check "trades above 2x ratio flags fail" "0" \
  "$(exit_of trades_out_of_ratio 600 264 2.0)"
# baseline 264, actual 100, ratio 2.0 → 100*2=200 < 264 → fail (exit 0)
check "trades below 0.5x ratio flags fail" "0" \
  "$(exit_of trades_out_of_ratio 100 264 2.0)"
# boundary: baseline 264, actual exactly 528 → at ratio (not strictly above) → pass (exit 1)
check "trades at exactly 2x boundary flags pass" "1" \
  "$(exit_of trades_out_of_ratio 528 264 2.0)"

# --- extract_metric: sanity-check on a synthetic actual.sexp ---
tmp_actual="$(mktemp)"
trap 'rm -f "$tmp_actual"' EXIT
cat > "$tmp_actual" << 'SEXP'
((total_return_pct 50.66) (total_trades 264) (win_rate 37.5) (sharpe_ratio 0.56)
 (max_drawdown_pct 21.56) (avg_holding_days 40.78) (open_positions_value 1221041)
 (unrealized_pnl 0) (force_liquidations_count 0))
SEXP
check "extract_metric sharpe_ratio" "0.56" "$(extract_metric "$tmp_actual" sharpe_ratio)"
check "extract_metric total_trades" "264" "$(extract_metric "$tmp_actual" total_trades)"
check "extract_metric max_drawdown_pct" "21.56" "$(extract_metric "$tmp_actual" max_drawdown_pct)"

if [ "$fail_count" -gt 0 ]; then
  die "${LABEL} — $fail_count check(s) failed."
fi

echo "OK: ${LABEL} — all gate-helper smoke checks passed."
