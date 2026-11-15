# replicate gbc.awk path(): each would-be-funded name holds M of cash for HOLD days. fridays.tsv in date order.
function slots(free) { return (M > 0 && free >= M) ? int(free / M + 1e-9) : 0 }
function path(c, d, free, n,   t, held, i, k, x) {
  t = days(d); held = 0
  for (i = PH[c] + 1; i <= PQ[c]; i++) { if (t - QD[c, i] >= HOLD) { PH[c] = i; continue } held += QN[c, i] }
  k = slots(free - held * M); x = (n < k) ? n : k
  if (x > 0) { PQ[c]++; QD[c, PQ[c]] = t; QN[c, PQ[c]] = x }
  return x
}
NR>1 { d=$1; y=substr(d,1,4); fg=$15+0; fn=fg-$16; if (fn<0) fn=0; nb=$11+0
  pg=path("g", d, fg, nb); pn=path("n", d, fn, nb); PG+=pg; PN+=pn; YG[y]+=pg; YN[y]+=pn
  if (y=="2000"||y=="2001"||y=="2002"||y=="2008") BN+=pn }
END { printf "HOLD %d: path X gross %d, net %d, bear share of path net %.3f\n", HOLD, PG, PN, (PN>0)?BN/PN:0
  if (BY) for (y=2000;y<=2026;y++) printf "  %d gross %3d net %3d\n", y, YG[y], YN[y] }
