#!/bin/sh
# make_specs.sh -- writes the 20 cells of price-band-confirm-2026-11-13 from the record cells rk-k0..rk-k4
# (../record-kseed-2026-10-27/specs/rk-kK.sexp). Run from the repo root; it overwrites specs/. chain.sh re-checks every
# relation below before it runs anything, so a hand edit that breaks one is caught there.
#
#   pbc1-S-kK  C1, period:  rk-kK with start_date 2000-01-01 -> 2013-01-01 (same top-3000 PIT v12 schedule)
#   pbc2-S-kK  C2, breadth: rk-kK with every top-3000-YYYY list -> top-1000-YYYY and universe_size 3000 -> 1000
#   pbc?-P-kK  the S spec plus the one override ((screening_config ((candidate_ranking Price_band_seeded)))), placed
#              after the tiebreak_seed line exactly as in ../price-band-tiebreak-2026-11-13/specs/pb-P-kK.sexp
set -eu
EXP=dev/experiments/price-band-confirm-2026-11-13
REC=dev/experiments/record-kseed-2026-10-27/specs
OVR='   ((screening_config ((candidate_ranking Price_band_seeded))))'
for k in 0 1 2 3 4; do
  src=$REC/rk-k$k.sexp
  for c in 1 2; do
    for a in S P; do
      case $c in
        1) what="C1 period cell: rk-k$k with start_date 2013-01-01; the full 1999-2025 top-3000 PIT v12 schedule is kept"
           desc="2013-01 to 2026-06, top-3000 pit-v12 schedule" ;;
        2) what="C2 breadth cell: rk-k$k with the yearly top-1000 PIT v12 lists in place of top-3000, universe_size 1000"
           desc="2000-01 to 2026-06, top-1000 pit-v12 schedule" ;;
      esac
      case $a in
        S) arm="arm S (control) = the record config"; o="" ;;
        P) arm="arm P = arm S + candidate_ranking Price_band_seeded (#3587), edges at the field default [8; 14; 33]"; o=$OVR ;;
      esac
      {
        echo ";; price-band-confirm-2026-11-13 pbc$c-$a-k$k: $what."
        echo ";; $arm. Staging scenario, NOT a golden. Pre-registration: ../README.md."
        awk -v c="$c" -v a="$a" -v k="$k" -v d="$desc" -v ovr="$o" '
          /^;;/ { next }
          /^\(\(name "/ { print "((name \"pbc" c "-" a "-k" k "\")"; next }
          /^ \(description "/ { print " (description \"price-band confirm C" c " arm " a ", Seeded tie order seed " k ", " d ", interest + dividends\")"; next }
          c == 1 { sub(/\(start_date 2000-01-01\)/, "(start_date 2013-01-01)") }
          c == 2 { gsub(/top-3000-/, "top-1000-"); sub(/\(universe_size 3000\)/, "(universe_size 1000)") }
          { print }
          /\(\(screening_config \(\(tiebreak_seed [0-9]+\)\)\)\)/ && ovr != "" { print ovr }' "$src"
      } > "$EXP/specs/pbc$c-$a-k$k.sexp"
    done
  done
done
ls "$EXP/specs" | wc -l
