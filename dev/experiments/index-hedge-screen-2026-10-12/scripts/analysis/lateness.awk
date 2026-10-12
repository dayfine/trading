# Gate lateness and post-trough exposure per bear, from a days.awk table. -v g=6|7|8 (G1|G2|G3)
# For each bear (peak, trough]: SPY's log decline; the first gate-on day and how much of the decline came before it;
# SPY's log move on on-days vs off-days inside the bear; then the on-days after the trough until the gate first goes
# off (the rebound held short). Bears: the three Phase B windows + COVID 2020.
BEGIN { FS = ","; nb = split("2000-03-24:2002-10-09 2007-10-09:2009-03-09 2020-02-19:2020-03-23 2022-01-03:2022-10-12", bw, " ")
  for (i = 1; i <= nb; i++) { split(bw[i], a, ":"); P[i] = a[1]; T[i] = a[2]; st[i] = "pre" } }
{ d = $1; lr = log(1 + $3); on = $(g)
  for (i = 1; i <= nb; i++) {
    if (d > P[i] && d <= T[i]) { tot[i] += lr; if (on) { onl[i] += lr; ond[i] += $5; if (fo[i] == "") { fo[i] = d; before[i] = tot[i] - lr } } else offl[i] += lr }
    if (d > T[i] && st[i] != "done") {
      if (on) { pr[i] += lr; pd[i] += $5; lastp[i] = d; st[i] = "in" }
      else if (st[i] == "in" || ++quiet[i] > 30) st[i] = "done" } } }
END { for (i = 1; i <= nb; i++) printf "G%d %s -> %s: SPY %+.4f | first on %s, SPY already %+.4f (%.0f%% of the decline) | in-bear on-days %d, SPY on-days %+.4f, off-days %+.4f | after trough on until %s: %d sessions, SPY %+.4f\n", \
  g - 5, P[i], T[i], tot[i], (fo[i] == "" ? "never" : fo[i]), before[i], (tot[i] != 0 ? 100 * before[i] / tot[i] : 0), ond[i], onl[i], offl[i], (lastp[i] == "" ? "-" : lastp[i]), pd[i], pr[i] }
