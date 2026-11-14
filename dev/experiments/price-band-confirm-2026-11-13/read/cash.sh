#!/bin/sh
# cash.sh -- two-sided cash displacement for ONE cell (README §Reported regardless). Every placed ticket of each arm is
# labelled by what the OTHER arm did with the same name on the same decision date (entries.tsv) and joined to its
# realised outcome in its own arm. Adapted from ../../price-band-tiebreak-2026-11-13/results/read/channels.sh (#3595),
# with the cell tag as a parameter and the summary printed directly.
#
# usage: sh cash.sh RESULTS_DIR TAG POSITIONS_TSV
# Per seed: "S lost to P's cash" = S tickets that P had in its list and skipped for Insufficient_cash (placed / filled,
# their S result as summed % of entry NAV), the mirror "P lost to S's cash", and the net (P side minus S side), plus
# every channel's ticket count. Outcome: a closed trade by position_id, or an open position (same symbol, first
# entry_date on or after the decision; open rows carry no position_id).
R=${1:?usage: sh cash.sh RESULTS_DIR TAG POSITIONS_TSV}; T=${2:?}; POS=${3:?}
for k in 0 1 2 3 4; do
  [ -s "$R/k$k/$T-S-k$k-s0-entries.tsv" ] && [ -s "$R/k$k/$T-P-k$k-s0-entries.tsv" ] || continue
  for a in S P; do
    o=P; [ "$a" = P ] && o=S
    awk -F'\t' -v OFS='\t' -v k="k$k" -v a="$a" '
      FNR == 1 { f++ }
      f == 1 { if ($1 == k && $3 == a && $7 == "open") { n = ++no[$4]; od[$4, n] = $5; onav[$4, n] = $13 }
               if ($1 == k && $3 == a && $7 == "closed") cnav[$4 "|" $5] = $13
               next }
      f == 2 { if (FNR == 1) next; split($0, t, ","); tid[t[20]] = t[1] "|" t[3]; next }     # own trades.csv: id -> sym|entry
      f == 3 { if ($1 == "position_id") next; st[$2 "|" $3] = ($4 == "placed") ? "placed" : (st[$2 "|" $3] == "placed" ? "placed" : $6); rec[$3] = 1; next }
      f == 4 { if ($1 == "position_id" || $4 != "placed") next
        key = $2 "|" $3
        if (!($3 in rec)) ch = "other-norecord"
        else if (!(key in st)) ch = "other-cut"
        else if (st[key] == "placed") ch = "both-placed"
        else if (st[key] == "Insufficient_cash") ch = "other-cash"
        else ch = "other-nostop"
        nt++; tk_id[nt] = $1; tk_sym[nt] = $2; tk_d[nt] = $3; tk_ch[nt] = ch }
      END {   # an open position belongs to the latest placed ticket of its symbol decided on or before its entry date
        for (i = 1; i <= nt; i++) if (!(tk_id[i] in tid)) for (j = 1; j <= no[tk_sym[i]]; j++) {
          if (od[tk_sym[i], j] < tk_d[i]) continue
          if (!((tk_sym[i], j) in best) || tk_d[best[tk_sym[i], j]] < tk_d[i]) best[tk_sym[i], j] = i }
        for (x in best) { split(x, xx, SUBSEP); own[best[x]] = onav[xx[1], xx[2]] }
        for (i = 1; i <= nt; i++) { filled = 1; v = 0
          if (tk_id[i] in tid) v = cnav[tid[tk_id[i]]]; else if (i in own) v = own[i]; else filled = 0
          print k, a, tk_ch[i], filled, v } }
    ' "$POS" "$R/k$k/$T-$a-k$k-s0-trades.csv" "$R/k$k/$T-$o-k$k-s0-entries.tsv" "$R/k$k/$T-$a-k$k-s0-entries.tsv"
  done
done | awk -F'\t' '{ n[$1, $2, $3]++; f[$1, $2, $3] += $4; v[$1, $2, $3] += $5; K[$1] = 1; C[$3] = 1 }
  END { for (k in K) {
      printf "%s  S lost to P cash: %d placed / %d filled, %+.1f %% of entry NAV | P lost to S cash: %d / %d, %+.1f %% | net %+.1f |",
        k, n[k, "S", "other-cash"], f[k, "S", "other-cash"], v[k, "S", "other-cash"],
        n[k, "P", "other-cash"], f[k, "P", "other-cash"], v[k, "P", "other-cash"], v[k, "P", "other-cash"] - v[k, "S", "other-cash"]
      for (c in C) printf " %s S %d P %d", c, n[k, "S", c], n[k, "P", c]; print "" } }' | sort
