#!/bin/sh
# channels.sh -- every placed ticket of each arm, labelled by what the OTHER arm did with the same name on the same
# decision date (entries.tsv), joined to the ticket's realised outcome in its own arm.
#
# usage: sh channels.sh RESULTS_DIR LIST_BANDS_TSV POSITIONS_TSV > channels.tsv
#
# channel (other arm, same decision date):
#   both-placed      the other arm placed it too
#   other-cash       the other arm had it in its list and skipped it for Insufficient_cash  (README "cash displacement")
#   other-nostop     ... skipped it for No_structural_stop / Sized_to_zero / Share_class_held
#   other-cut        the other arm recorded a list that date and the name is not in it (top-20 cut, or held / cooldown
#                    in the other arm)
#   other-norecord   the other arm placed nothing that date, so its list was not recorded (channel unknown)
# outcome: filled ticket -> closed trade (trades.csv position_id) or open position (open_positions.csv: same symbol, the
# first entry_date >= decision date; open rows carry no position_id); else unfilled. contrib / nav_pct as positions.sh.
# Columns: seed arm position_id symbol decision_date band_at_decision channel status entry_date entry_price contrib nav_pct pnl_pct
R=${1:?}; LB=${2:?}; POS=${3:?}
printf 'seed\tarm\tposition_id\tsymbol\tdecision_date\tband\tchannel\tstatus\tentry_date\tentry_price\tcontrib\tnav_pct\tpnl_pct\n'
for k in 0 1 2 3 4; do
  for a in S P; do
    o=P; [ "$a" = P ] && o=S
    awk -F'\t' -v OFS='\t' -v k="k$k" -v a="$a" '
      FNR == 1 { f++ }
      f == 1 { band[$1 "|" $2] = $3; next }
      f == 2 { if ($1 == k && $3 == a && $7 == "open") { n = ++no[$4]; od[$4, n] = $5; orow[$4, n] = $7 OFS $5 OFS $8 OFS $11 OFS $13 OFS $14 }
               if ($1 == k && $3 == a && $7 == "closed") crow[$4 "|" $5] = $7 OFS $5 OFS $8 OFS $11 OFS $13 OFS $14
               next }
      f == 3 { if (FNR == 1) next; split($0, t, ","); tid[t[20]] = t[1] "|" t[3]; next }     # own trades.csv: id -> sym|entry
      f == 4 { if ($1 == "position_id") next; st[$2 "|" $3] = ($4 == "placed") ? "placed" : (st[$2 "|" $3] == "placed" ? "placed" : $6); rec[$3] = 1; next }
      f == 5 { if ($1 == "position_id" || $4 != "placed") next
        key = $2 "|" $3
        if (!($3 in rec)) ch = "other-norecord"
        else if (!(key in st)) ch = "other-cut"
        else if (st[key] == "placed") ch = "both-placed"
        else if (st[key] == "Insufficient_cash") ch = "other-cash"
        else ch = "other-nostop"
        nt++; tk_id[nt] = $1; tk_sym[nt] = $2; tk_d[nt] = $3; tk_band[nt] = band[key]; tk_ch[nt] = ch }
      END {   # an open position belongs to the latest placed ticket of its symbol decided on or before its entry date
        for (i = 1; i <= nt; i++) if (!(tk_id[i] in tid)) for (j = 1; j <= no[tk_sym[i]]; j++) {
          if (od[tk_sym[i], j] < tk_d[i]) continue
          if (!((tk_sym[i], j) in best) || tk_d[best[tk_sym[i], j]] < tk_d[i]) best[tk_sym[i], j] = i }
        for (x in best) { split(x, xx, SUBSEP); own[best[x]] = orow[xx[1], xx[2]] }
        for (i = 1; i <= nt; i++) {
          out = "unfilled" OFS "-" OFS "-" OFS 0 OFS 0 OFS "-"
          if (tk_id[i] in tid) out = crow[tid[tk_id[i]]]; else if (i in own) out = own[i]
          print k, a, tk_id[i], tk_sym[i], tk_d[i], tk_band[i], tk_ch[i], out } }
    ' "$LB" "$POS" "$R/k$k/pb-$a-k$k-s0-trades.csv" "$R/k$k/pb-$o-k$k-s0-entries.tsv" "$R/k$k/pb-$a-k$k-s0-entries.tsv"
  done
done
