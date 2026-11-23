#!/bin/sh
# make_specs.sh -- writes the 30 cells of nav-scale-participation-2026-11-23 (6 arms x seeds 0-4) from the record cells
# rk-k0..rk-k4 (../record-kseed-2026-10-27/specs/rk-kK.sexp). It overwrites specs/. chain.sh
# re-checks every relation below before it runs anything (sh chain.sh check K), so a hand edit that breaks one is caught.
#
#   ns-F-<cash>-kK  rk-kK below the header (name and description changed), plus (initial_cash <cash>) after the
#                   universe_size line, except at 1M, where the line is omitted: the field's default is
#                   Backtest.Runner.default_initial_cash = 1,000,000.0 and the scenario sexp drops it at the default
#                   (#3697), so ns-F-1M-kK is rk-kK below the header, the record itself.
#   ns-P-<cash>-kK  ns-F-<cash>-kK plus the three override lines of dev/weekly-picks/live-size-overrides.sexp,
#                   APPENDED after the record's last override (tiebreak_seed): overlays fold left to right
#                   (Overlay_validator.apply_overrides), so a later line wins. Prepended, the record's own
#                   min_entry_dollar_adv 1e6 and min_hold_dollar_adv 5e5 lines would override the P values.
set -eu
cd "$(dirname "$0")/../../.."   # the repo root, wherever it is called from
EXP=dev/experiments/nav-scale-participation-2026-11-23
REC=dev/experiments/record-kseed-2026-10-27/specs
LIVE=dev/weekly-picks/live-size-overrides.sexp
mkdir -p "$EXP/specs"
rm -f "$EXP/specs"/ns-*.sexp
P_OVR=$(grep -v '^;' "$LIVE" | grep -v '^[[:space:]]*$' | sed 's/^/   /')
[ "$(printf '%s\n' "$P_OVR" | wc -l | tr -d ' ')" = 3 ] || { echo "make_specs: expected 3 override lines in $LIVE" >&2; exit 1; }
for k in 0 1 2 3 4; do
  for arm in F P; do
    for cash in 100k 1M 10M; do
      case $cash in 100k) cv=100000.0 ;; 1M) cv= ;; 10M) cv=10000000.0 ;; esac
      case $arm in
        F) what="arm F-$cash: the record liquidity (fixed min_entry_dollar_adv 1e6, min_hold_dollar_adv 5e5)"; ovr= ;;
        P) what="arm P-$cash: the record + the live-size liquidity profile (dev/weekly-picks/live-size-overrides.sexp: max_entry_adv_participation 0.10, min_entry_dollar_adv 1e5, min_hold_dollar_adv 5e4), appended last"
           ovr=$P_OVR ;;
      esac
      if [ -n "$cv" ]; then cl="initial_cash $cv"; else cl="initial_cash omitted = the 1,000,000.0 default"; fi
      {
        echo ";; nav-scale-participation-2026-11-23 ns-$arm-$cash-k$k: rk-k$k (../record-kseed-2026-10-27/specs/rk-k$k.sexp) below this header,"
        echo ";; plus $cl. $what."
        echo ";; Staging scenario, NOT a golden. Pre-registration: ../README.md. Written by ../make_specs.sh."
        OVR=$ovr awk -v a="$arm" -v c="$cash" -v k="$k" -v cv="$cv" '
          /^;;/ { next }
          /^\(\(name "/ { print "((name \"ns-" a "-" c "-k" k "\")"; next }
          /^ \(description "/ { print " (description \"nav-scale arm " a "-" c ", record config, Seeded tie order seed " k ", 26y, pit-v12, interest + dividends\")"; next }
          { print }
          /^ \(universe_size / && cv != "" { print " (initial_cash " cv ")" }
          /\(\(screening_config \(\(tiebreak_seed [0-9]+\)\)\)\)/ && ENVIRON["OVR"] != "" { print ENVIRON["OVR"] }' "$REC/rk-k$k.sexp"
      } > "$EXP/specs/ns-$arm-$cash-k$k.sexp"
    done
  done
done
ls "$EXP/specs" | wc -l
