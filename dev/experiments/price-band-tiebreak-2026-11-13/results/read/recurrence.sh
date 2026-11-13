#!/bin/sh
# recurrence.sh -- is P's gain a re-draw (scattered across seeds) or systematic (the same names in most P seeds)?
# For every position key symbol|entry_date: nP = number of P seeds holding it, nS = number of S seeds. The pooled
# NAV-% difference sum(P) - sum(S) over all positions splits exactly into groups by d = nP - nS.
# usage: sh recurrence.sh POSITIONS_TSV
POS=${1:?usage: sh recurrence.sh POSITIONS_TSV}
awk -F'\t' 'NR > 1 { k = $4 "|" $5; if ($3 == "P") { nP[k]++; vP[k] += $13 } else { nS[k]++; vS[k] += $13 }
    band[k] = $9; pct[k] = $14; keys[k] = 1 }
  END {
    for (k in keys) { d = nP[k] - nS[k]; g = (d >= 3) ? "P>=S+3" : (d <= -3) ? "S>=P+3" : (d == 0 ? "equal" : "|d|<=2")
      net = vP[k] - vS[k]; G[g] += net; N[g]++; GB[g, band[k]] += net
      if (d >= 3 || d <= -3) list[g] = list[g] sprintf(" %s(b%d,%s%%,%+.1f)", k, band[k], pct[k], net) }
    printf "pooled sum(P nav%%) - sum(S nav%%) by recurrence group (5 seeds; divide by 5 for the per-seed mean)\n"
    for (g in N) printf "%-8s keys=%4d net=%+7.1f  [b0 %+6.1f b1 %+6.1f b2 %+6.1f b3 %+6.1f]\n", g, N[g], G[g], GB[g, 0], GB[g, 1], GB[g, 2], GB[g, 3]
    for (g in list) printf "\n%s:%s\n", g, list[g] }' "$POS"
