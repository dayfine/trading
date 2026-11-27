#!/bin/sh
# make_specs.sh -- writes the 10 cells of universe-depth-rerun-2026-11-26 (arms S3 and U4 x seeds 0-4) from the record
# cells rk-k0..rk-k4 (../record-kseed-2026-10-27/specs/rk-kK.sexp), as PREREG.md "Arms" fixes them. It overwrites specs/.
# Derived from ../universe-depth-2026-11-23/make_specs.sh with the N3 and UN4 arms removed (user decision, PREREG.md);
# the S3 and U4 transforms are unchanged. chain.sh re-checks every relation below before it runs anything
# (sh chain.sh check K), against both rk-kK and NAV-scale's ns-P-100k-kK, so a hand edit that breaks one is caught.
#
#   every arm   rk-kK below the header (name and description changed), plus (initial_cash 100000.0) after the
#               universe_size line, plus the three override lines of dev/weekly-picks/live-size-overrides.sexp APPENDED
#               after the record's last override (tiebreak_seed; overlays fold left to right, a later line wins). Up to
#               here this is NAV-scale's P-100k arm (../nav-scale-participation-2026-11-23/make_specs.sh), byte for byte
#               below the header.
#   S3          + the universe schedule and universe_path moved from pit-v12/composition/ to pit-v13/composition/
#               (same 27 rebalance dates 1999-05-31 .. 2025-05-31 as the record, same top-3000 list names). The lists
#               are the repaired ones of #3727, re-nested by #3734 (chain.sh guards pit-v13/composition.md5).
#   U4          S3 with top-3000-YYYY -> top-4000-YYYY in every list path, and universe_size 3000 -> 4000
set -eu
cd "$(dirname "$0")/../../.."   # the repo root, wherever it is called from
EXP=dev/experiments/universe-depth-rerun-2026-11-26
REC=dev/experiments/record-kseed-2026-10-27/specs
LIVE=dev/weekly-picks/live-size-overrides.sexp
mkdir -p "$EXP/specs"
rm -f "$EXP/specs"/udr-*.sexp
P_OVR=$(grep -v '^;' "$LIVE" | grep -v '^[[:space:]]*$' | sed 's/^/   /')
[ "$(printf '%s\n' "$P_OVR" | wc -l | tr -d ' ')" = 3 ] || { echo "make_specs: expected 3 override lines in $LIVE" >&2; exit 1; }
for k in 0 1 2 3 4; do
  for arm in S3 U4; do
    case $arm in
      S3) depth=3000 ;;
      U4) depth=4000 ;;
    esac
    {
      echo ";; universe-depth-rerun-2026-11-26 udr-$arm-k$k: rk-k$k (../record-kseed-2026-10-27/specs/rk-k$k.sexp) below this header,"
      echo ";; plus initial_cash 100000.0 and dev/weekly-picks/live-size-overrides.sexp appended last (= NAV-scale ns-P-100k-k$k), on"
      echo ";; the repaired (#3727, #3734) pit-v13 top-$depth schedule (universe_size $depth), require_structural_stop true (the record's)."
      echo ";; Staging scenario, NOT a golden. Pre-registration: ../PREREG.md. Written by ../make_specs.sh."
      OVR=$P_OVR awk -v a="$arm" -v k="$k" -v d="$depth" '
        /^;;/ { next }
        /^\(\(name "/ { print "((name \"udr-" a "-k" k "\")"; next }
        /^ \(description "/ { print " (description \"universe-depth rerun arm " a ", record config at live size (100k, live-size liquidity), repaired pit-v13 top-" d ", require_structural_stop true, Seeded tie order seed " k ", 26y, interest + dividends\")"; next }
        /pit-v12\/composition\/top-3000-[0-9][0-9][0-9][0-9]\.sexp/ {
          sub(/pit-v12\/composition\/top-3000-/, "pit-v13/composition/top-" d "-") }
        /^ \(universe_size 3000\)$/ { print " (universe_size " d ")"; print " (initial_cash 100000.0)"; next }
        { print }
        /\(\(screening_config \(\(tiebreak_seed [0-9]+\)\)\)\)/ { print ENVIRON["OVR"] }' "$REC/rk-k$k.sexp"
    } > "$EXP/specs/udr-$arm-k$k.sexp"
  done
done
ls "$EXP/specs" | wc -l
