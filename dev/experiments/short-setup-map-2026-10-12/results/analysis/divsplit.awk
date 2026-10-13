# Decision-time large-dividend split (qc-results rework of README §10, defect 8).
# An event is "large dividend in hold" when some ex-date d with E1 entry < d <= the +120th bar after entry carries
# unadjusted_amount >= 3 % of the BREAKDOWN-WEEK raw close (decision time; no in-hold price).
# Usage: awk -F, -v ev="<sym's events: date,raw_close,e1_date,e1_o2_exc;...>" -f divsplit.awk <data.csv> <dividends.csv>
# Prints: sym,date,flag,e1_o2_exc
FNR == 1 { fi++; next }
fi == 1 { if ($5 + 0 > 0) { nd++; dd[nd] = $1 } next }
fi == 2 { nv++; vdt[nv] = $1; vam[nv] = $2 + 0; next }
END {
  n = split(ev, E, ";")
  for (k = 1; k <= n; k++) {
    split(E[k], f, "|"); date = f[1]; raw = f[2]; e1 = f[3]; x = f[4]
    for (j = 1; j <= nd && dd[j] < e1; j++) ;
    if (j > nd) continue
    end = (j + 120 <= nd) ? j + 120 : nd
    flag = 0
    for (t = 1; t <= nv; t++) if (vdt[t] > dd[j] && vdt[t] <= dd[end] && vam[t] >= 0.03 * raw) flag = 1
    print sym "," date "," flag "," x
  }
}
