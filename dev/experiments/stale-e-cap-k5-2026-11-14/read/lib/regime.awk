# regime.awk -- per period x SPY regime: strategy and SPY cumulative return and mean invested %, per arm.
# Regime as the review pack defines it (dev/lib/review_pack/index.html spyRegimeByDay): weekly close vs its 30-week
# MA and the MA's 4-week slope, known at the week's last close and applied to the FOLLOWING week's days.
# Inputs (flattened by the caller to "date value [invested]" lines):
#   FILE 1: spy  -- warm-up then in-window SPY (adjusted) closes
#   FILE 2..: one arm each, "ARM date nav invested"
function dn(d,   y, m) { y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + substr(d, 9, 2) }
function per(d,   y) { y = substr(d, 1, 4) + 0
  return y <= 2002 ? "2000-02" : y <= 2006 ? "2003-06" : y <= 2009 ? "2007-09" : y <= 2014 ? "2010-14" : y <= 2019 ? "2015-19" : y <= 2022 ? "2020-22" : "2023-26" }
BEGIN { base = dn("2000-01-03") }
FNR == 1 { fi++ }
fi == 1 {   # SPY series
  d = $1; v = $2 + 0; wk = int((dn(d) - base + 7000) / 7)
  if (wk != cw && last != "") {
    nclose++; cl[nclose] = last
    if (nclose >= 34) { m = 0; m4 = 0; for (i = nclose - 29; i <= nclose; i++) m += cl[i]; for (i = nclose - 33; i <= nclose - 4; i++) m4 += cl[i]
      m /= 30; m4 /= 30; c = cl[nclose]; cur = (c > m && m > m4) ? "UP" : (c < m && m < m4) ? "DOWN" : "MIXED" }
  }
  cw = wk; last = v; reg[d] = cur; spy[d] = v; next
}
{   # arm rows: ARM date nav invested
  a = $1; d = $2; v = $3 + 0; e = $4 + 0
  if ((a in pv) && (d in spy) && (pd[a] in spy)) {
    r = reg[d]; if (r == "") r = "NA"; p = per(d)
    k = a SUBSEP p SUBSEP r; g[k] = (k in g ? g[k] : 1) * v / pv[a]; s[k] = (k in s ? s[k] : 1) * spy[d] / spy[pd[a]]
    n[k]++; ex[k] += e
    k2 = a SUBSEP "all" SUBSEP r; g[k2] = (k2 in g ? g[k2] : 1) * v / pv[a]; s[k2] = (k2 in s ? s[k2] : 1) * spy[d] / spy[pd[a]]
    n[k2]++; ex[k2] += e
    kp = a SUBSEP p; np[kp]++; ep[kp] += e; kp2 = a SUBSEP "all"; np[kp2]++; ep[kp2] += e
    gp[kp] = (kp in gp ? gp[kp] : 1) * v / pv[a]; sp[kp] = (kp in sp ? sp[kp] : 1) * spy[d] / spy[pd[a]]
    gp[kp2] = (kp2 in gp ? gp[kp2] : 1) * v / pv[a]; sp[kp2] = (kp2 in sp ? sp[kp2] : 1) * spy[d] / spy[pd[a]]
    arms[a] = 1
  }
  pv[a] = v; pd[a] = d
}
END {
  split("2000-02 2003-06 2007-09 2010-14 2015-19 2020-22 2023-26 all", P, " ")
  split("UP MIXED DOWN", R, " ")
  for (i = 1; i <= 8; i++) {
    for (a in arms) {
      kp = a SUBSEP P[i]
      line = sprintf("%-8s %s all: strat %+7.1f%% spy %+7.1f%% inv %4.1f%% |", P[i], a, 100 * (gp[kp] - 1), 100 * (sp[kp] - 1), ep[kp] / np[kp])
      for (j = 1; j <= 3; j++) { k = a SUBSEP P[i] SUBSEP R[j]
        if (n[k] > 0) line = line sprintf(" %s(%dd) %+6.1f/%+6.1f inv %4.1f |", R[j], n[k], 100 * (g[k] - 1), 100 * (s[k] - 1), ex[k] / n[k])
        else line = line sprintf(" %s(0d) |", R[j]) }
      print line
    }
  }
}
