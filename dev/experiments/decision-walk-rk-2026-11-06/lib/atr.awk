# tr_full.tsv sorted by sym -> pid fill_date trig days mfe pnl stopdist atr20: the mean true range / prior close over the
# 20 raw daily bars before the fill date. Needs ./data.
function load(sym,  f, line, a) { delete H; delete Lo; delete C; delete Dt; nb = 0; f = "data/" substr(sym, 1, 1) "/" substr(sym, length(sym), 1) "/" sym "/data.csv"
  while ((getline line < f) > 0) { if (line ~ /^date/) continue; split(line, a, ","); if (a[5] + 0 <= 0) continue; nb++; Dt[nb] = a[1]; H[nb] = a[3]; Lo[nb] = a[4]; C[nb] = a[5] } close(f) }
{ if ($2 != cur) { cur = $2; load(cur) } i = 0; for (k = nb; k >= 1; k--) if (Dt[k] < $3) { i = k; break }
  if (i < 21) next; s = 0
  for (k = i - 19; k <= i; k++) { tr = H[k] - Lo[k]; if (H[k] - C[k - 1] > tr) tr = H[k] - C[k - 1]; if (C[k - 1] - Lo[k] > tr) tr = C[k - 1] - Lo[k]; s += tr / C[k - 1] }
  print $1 "\t" $3 "\t" $7 "\t" $10 "\t" $9 "\t" $6 "\t" $11 "\t" s / 20 }
