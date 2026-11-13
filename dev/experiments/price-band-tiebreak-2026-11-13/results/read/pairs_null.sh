#!/bin/sh
# pairs_null.sh -- the reshuffle null at the position level. For every pair of cells (arm a seed i, arm b seed j):
# positions shared (symbol|entry_date), one-cell-only counts, and the one-only NAV-% net (a-only minus b-only), plus
# the ln(1+R) difference. Same-seed P vs S pairs (the experiment) are compared with cross-seed S vs S and P vs P pairs
# (pure tie re-draws, no band order change).
# usage: sh pairs_null.sh POSITIONS_TSV ARM_TABLE_TSV
POS=${1:?}; AT=${2:?}
awk -F'\t' '
  FNR == 1 { f++; next }
  f == 1 { ln[$2 $1] = $4; next }                       # arm_table: seed arm ... ln1R  -> ln["Sk0"]
  { c = $3 $1; key = $4 "|" $5; has[c, key] = 1; nav[c, key] = $13; cells[c] = 1; keys[key] = 1 }
  END {
    split("Sk0 Sk1 Sk2 Sk3 Sk4 Pk0 Pk1 Pk2 Pk3 Pk4", C, " ")
    for (i = 1; i <= 10; i++) for (j = i + 1; j <= 10; j++) { a = C[i]; b = C[j]
      ta = substr(a, 1, 1); tb = substr(b, 1, 1); sa = substr(a, 2); sb = substr(b, 2)
      if (ta == tb) type = ta ta "-cross"; else if (sa == sb) type = "PS-same"; else type = "PS-cross"
      sh = 0; ao = 0; bo = 0; net = 0
      for (k in keys) { x = ((a, k) in has); y = ((b, k) in has)
        if (x && y) sh++; else if (x) { ao++; net += nav[a, k] } else if (y) { bo++; net -= nav[b, k] } }
      # orient P-vs-S pairs as P minus S
      if (ta == "S" && tb == "P") { t = a; a = b; b = t; t = ao; ao = bo; bo = t; net = -net }
      printf "%-8s %s-%s shared=%d a_only=%d b_only=%d overlap=%.1f%% net_navpct=%+.1f dln=%+.4f\n", type, a, b, sh, ao, bo,
        100 * sh / (sh + (ao + bo) / 2), net, ln[a] - ln[b] } }' "$AT" "$POS" | sort
