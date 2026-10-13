# Forward short return of each candidate. Files: 1 pool csv (symbol,date,score), 2 the symbol's data.csv
# (date,open,high,low,close,adjusted_close,...). -v S=<symbol>. Entry = the first bar after the decision date (its
# adjusted close); returns at +20 / +60 / +120 bars (or the last bar), side-signed (+ = the stock fell).
# Out: symbol,decision,score,entry_date,r20,d20,r60,d60,r120,d120
NR == FNR { if ($1 == S) { n++; d[n] = $2; sc[n] = $3 } next }
FNR > 1 { k++; bd[k] = $1; ba[k] = $6 + 0 }
END { for (i = 1; i <= n; i++) { j = 0; for (t = 1; t <= k; t++) if (bd[t] > d[i]) { j = t; break }
    if (!j || ba[j] <= 0) continue
    out = S "," d[i] "," sc[i] "," bd[j]
    for (h = 1; h <= 3; h++) { H = (h == 1 ? 20 : (h == 2 ? 60 : 120)); e = j + H; if (e > k) e = k
      out = out "," (-(ba[e] / ba[j] - 1)) "," bd[e] }
    print out } }
