#!/bin/sh
# make_specs.sh -- writes the 20 cells of universe-depth-2026-11-23 (4 arms x seeds 0-4) from the record cells
# rk-k0..rk-k4 (../record-kseed-2026-10-27/specs/rk-kK.sexp), as PREREG.md "Arms" fixes them. It overwrites specs/.
# chain.sh re-checks every relation below before it runs anything (sh chain.sh check K), against both rk-kK and
# NAV-scale's ns-P-100k-kK, so a hand edit that breaks one is caught.
#
#   every arm   rk-kK below the header (name and description changed), plus (initial_cash 100000.0) after the
#               universe_size line, plus the three override lines of dev/weekly-picks/live-size-overrides.sexp APPENDED
#               after the record's last override (tiebreak_seed; overlays fold left to right, a later line wins). Up to
#               here this is NAV-scale's P-100k arm (../nav-scale-participation-2026-11-23/make_specs.sh), byte for byte
#               below the header.
#   S3          + the universe schedule and universe_path moved from pit-v12/composition/ to pit-v13/composition/
#               (same 27 rebalance dates 1999-05-31 .. 2025-05-31 as the record, same top-3000 list names)
#   U4          S3 with top-3000-YYYY -> top-4000-YYYY in every list path, and universe_size 3000 -> 4000
#   N3          S3 + ((require_structural_stop false)) appended as the last override (the record's own line says true;
#               the later line wins)
#   UN4         U4 + the same appended line
set -eu
cd "$(dirname "$0")/../../.."   # the repo root, wherever it is called from
EXP=dev/experiments/universe-depth-2026-11-23
REC=dev/experiments/record-kseed-2026-10-27/specs
LIVE=dev/weekly-picks/live-size-overrides.sexp
mkdir -p "$EXP/specs"
rm -f "$EXP/specs"/ud-*.sexp
P_OVR=$(grep -v '^;' "$LIVE" | grep -v '^[[:space:]]*$' | sed 's/^/   /')
[ "$(printf '%s\n' "$P_OVR" | wc -l | tr -d ' ')" = 3 ] || { echo "make_specs: expected 3 override lines in $LIVE" >&2; exit 1; }
for k in 0 1 2 3 4; do
  for arm in S3 U4 N3 UN4; do
    case $arm in
      S3) depth=3000; nss=true ;;
      U4) depth=4000; nss=true ;;
      N3) depth=3000; nss=false ;;
      UN4) depth=4000; nss=false ;;
    esac
    if [ "$nss" = false ]; then tail_ovr="   ((require_structural_stop false))"; else tail_ovr=; fi
    {
      echo ";; universe-depth-2026-11-23 ud-$arm-k$k: rk-k$k (../record-kseed-2026-10-27/specs/rk-k$k.sexp) below this header, plus"
      echo ";; initial_cash 100000.0 and dev/weekly-picks/live-size-overrides.sexp appended last (= NAV-scale ns-P-100k-k$k), on the"
      echo ";; pit-v13 top-$depth schedule (universe_size $depth), require_structural_stop $nss$([ "$nss" = false ] && echo ' (appended after the live-size lines)')."
      echo ";; Staging scenario, NOT a golden. Pre-registration: ../PREREG.md. Written by ../make_specs.sh."
      OVR=$P_OVR TAIL=$tail_ovr awk -v a="$arm" -v k="$k" -v d="$depth" -v nss="$nss" '
        /^;;/ { next }
        /^\(\(name "/ { print "((name \"ud-" a "-k" k "\")"; next }
        /^ \(description "/ { print " (description \"universe-depth arm " a ", record config at live size (100k, live-size liquidity), pit-v13 top-" d ", require_structural_stop " nss ", Seeded tie order seed " k ", 26y, interest + dividends\")"; next }
        /pit-v12\/composition\/top-3000-[0-9][0-9][0-9][0-9]\.sexp/ {
          sub(/pit-v12\/composition\/top-3000-/, "pit-v13/composition/top-" d "-") }
        /^ \(universe_size 3000\)$/ { print " (universe_size " d ")"; print " (initial_cash 100000.0)"; next }
        { print }
        /\(\(screening_config \(\(tiebreak_seed [0-9]+\)\)\)\)/ {
          print ENVIRON["OVR"]; if (ENVIRON["TAIL"] != "") print ENVIRON["TAIL"] }' "$REC/rk-k$k.sexp"
    } > "$EXP/specs/ud-$arm-k$k.sexp"
  done
done
ls "$EXP/specs" | wc -l
