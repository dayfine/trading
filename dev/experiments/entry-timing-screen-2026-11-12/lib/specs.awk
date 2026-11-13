# Join one seed's equity curve, audit entries (decision-walk entries.awk output) and trades.csv into one
# spec row per closed trade. usage: awk -F'\t' -v k=SEED -f specs.awk equity.csv entries.tsv trades.csv
# out: seed pid sym screen fill_date exit_date fill exit qty pnl exit_trigger E stop nav_at_screen ma_audit
#      close_dec adjclose_dec vol_ratio rs macro weeks_adv exit_stage score dividends
FILENAME ~ /equity/ { split($0, a, ","); if (FNR > 1) { nd[++n] = a[1]; nv[n] = a[2] }; next }
FILENAME ~ /entries/ {
  if ($10 == 1) { E[$3] = $17; ST[$3] = $18; MA[$3] = $21; CD[$3] = $19; AD[$3] = $20; VR[$3] = $32; RSV[$3] = $33
    MAC[$3] = $4; WK[$3] = $23; SC[$3] = $24; XS[$3] = $37; SCO[$3] = $5 }
  next }
{ split($0, t, ","); if (FNR == 1) next; pid = t[20]; if (!(pid in E)) { miss++; next }
  sd = SC[pid]; while (j < n && nd[j + 1] <= sd) j++
  # trades.csv is in exit order, not screen order: reset the NAV cursor when the date goes backwards
  if (nd[j] > sd) { j = 1; while (j < n && nd[j + 1] <= sd) j++ }
  print k "\t" pid "\t" t[1] "\t" sd "\t" t[3] "\t" t[4] "\t" t[6] "\t" t[7] "\t" t[8] "\t" t[9] "\t" t[13] "\t" E[pid] "\t" ST[pid] "\t" nv[j] "\t" MA[pid] "\t" CD[pid] "\t" AD[pid] "\t" VR[pid] "\t" RSV[pid] "\t" MAC[pid] "\t" WK[pid] "\t" XS[pid] "\t" SCO[pid] "\t" t[25] }
END { if (miss) print "k" k " unmatched trades: " miss > "/dev/stderr" }
