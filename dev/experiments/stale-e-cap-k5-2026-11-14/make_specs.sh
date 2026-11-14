#!/bin/sh
# make_specs.sh -- writes the 15 cells of stale-e-cap-k5-2026-11-14 from the record cells rk-k0..rk-k4
# (../record-kseed-2026-10-27/specs/rk-kK.sexp). Run from the repo root; it overwrites specs/. chain.sh re-checks every
# relation below before it runs anything, so a hand edit that breaks one is caught there.
#
#   sec-S-kK  arm S: rk-kK byte-for-byte below the header (name and description changed). The same body as
#             ../price-band-tiebreak-2026-11-13/specs/pb-S-kK.sexp, #3595's arm S.
#   sec-C-kK  arm C: sec-S-kK plus the one override ((entry_cap_local_range_weeks 4)) (#3604), placed after the
#             tiebreak_seed line.
#   sec-G-kK  arm G: sec-C-kK plus the one override ((entry_cap_stop_gate_on_uncapped true)) (#3609), placed after the
#             cap line: the cap, with every stop-gate decision read at the uncapped trigger.
set -eu
EXP=dev/experiments/stale-e-cap-k5-2026-11-14
REC=dev/experiments/record-kseed-2026-10-27/specs
CAP='   ((entry_cap_local_range_weeks 4))'
GATE='   ((entry_cap_stop_gate_on_uncapped true))'
mkdir -p "$EXP/specs"
for k in 0 1 2 3 4; do
  for a in S C G; do
    case $a in
      S) arm="arm S (control) = the record config, Seeded tie order"; o=""; g=""; d="record config" ;;
      C) arm="arm C = arm S + entry_cap_local_range_weeks 4 (#3604): a long ticket's anchor capped at the 4-week high"
         o=$CAP; g=""; d="record config + stale-E cap 4 weeks" ;;
      G) arm="arm G = arm C + entry_cap_stop_gate_on_uncapped true (#3609): the cap, stop gate read at the uncapped E"
         o=$CAP; g=$GATE; d="record config + stale-E cap 4 weeks + stop gate on the uncapped E" ;;
    esac
    {
      echo ";; stale-e-cap-k5-2026-11-14 sec-$a-k$k: rk-k$k (../record-kseed-2026-10-27/specs/rk-k$k.sexp) below this header."
      echo ";; $arm. Staging scenario, NOT a golden. Pre-registration: ../README.md."
      awk -v a="$a" -v k="$k" -v d="$d" -v ovr="$o" -v gate="$g" '
        /^;;/ { next }
        /^\(\(name "/ { print "((name \"sec-" a "-k" k "\")"; next }
        /^ \(description "/ { print " (description \"stale-E cap arm " a " = " d ", Seeded tie order seed " k ", 26y, pit-v12, interest + dividends\")"; next }
        { print }
        /\(\(screening_config \(\(tiebreak_seed [0-9]+\)\)\)\)/ && ovr != "" { print ovr; if (gate != "") print gate }' "$REC/rk-k$k.sexp"
    } > "$EXP/specs/sec-$a-k$k.sexp"
  done
done
ls "$EXP/specs" | wc -l
