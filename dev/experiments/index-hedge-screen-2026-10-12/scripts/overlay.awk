# Index-short overlay screen (dev/plans/index-hedge-screen-2026-10-11.md).
# Inputs, in order: weekly stage csv (week,date,close,ma,stage,...), weekly macro csv (date,trend),
# DTB3 csv (date,rate %), SPY daily csv (date,...,adjusted_close col 6), base equity curve (date,value).
# -v lag=<extra weeks of lag, 0 = reading of the last week-end strictly before the day>
# -v credit=<0|1: credit short proceeds at DTB3 - 10 bp>  -v borrow=<annual, 0.0025>  -v mode=<summary|episodes|years>
BEGIN { FS = ","; split("0.25 0.5 1.0", H, " "); ng = split("G1 G2 G3", G, " ")
  B[1] = "2000-03-24 2002-10-09"; B[2] = "2007-10-09 2009-03-09"; B[3] = "2022-01-03 2022-10-12" }
FILENAME == ARGV[1] && FNR > 1 { nw++; wd[nw] = $2; st[nw] = $5; cl[nw] = $3; ma[nw] = $4; next }
FILENAME == ARGV[2] { nm++; md[nm] = $1; mt[nm] = $2; next }
FILENAME == ARGV[3] && FNR > 1 { if ($2 != "" && $2 != ".") { nr++; rd[nr] = $1; rv[nr] = $2 + 0 } next }
FILENAME == ARGV[4] && FNR > 1 { px[$1] = $6 + 0; next }
FILENAME == ARGV[5] && FNR > 1 { n++; d[n] = $1; v[n] = $2 + 0 }
function bear_of(x,  i, a) { for (i = 1; i <= 3; i++) { split(B[i], a, " "); if (x >= a[1] && x <= a[2]) return i } return 0 }
END {
  # weekly gates, then the regime (pack rule: close vs 30w MA and the MA's 4-week slope)
  for (i = 1; i <= nw; i++) { k = 0; for (j = km; j <= nm; j++) if (md[j] <= wd[i]) k = j; else break; km = (k > 0 ? k : 1)
    mb[i] = (k > 0 && mt[k] == "Bearish"); s4[i] = (st[i] == "Stage4")
    gate["G1", i] = s4[i]; gate["G2", i] = s4[i] && mb[i]; gate["G3", i] = mb[i]
    reg[i] = (i > 4 && ma[i] > 0 && ma[i-4] > 0) ? (cl[i] > ma[i] && ma[i] > ma[i-4] ? "UP" : (cl[i] < ma[i] && ma[i] < ma[i-4] ? "DOWN" : "MIXED")) : "MIXED" }
  w = 0; r = 1; prevpx = ""
  for (t = 1; t <= n; t++) {
    while (w < nw && wd[w+1] < d[t]) w++
    wi = w - lag; while (r < nr && rd[r+1] <= d[t]) r++
    rs = (t > 1 && (d[t-1] in px) && (d[t] in px)) ? px[d[t]] / px[d[t-1]] - 1 : 0
    lb = (t > 1) ? log(v[t] / v[t-1]) : 0; base += lb
    cash = (rv[r] - 0.10) / 100 / 252; yr = substr(d[t], 1, 4); bi = bear_of(d[t])
    if (t > 1) { bpk = (v[t] > bpk ? v[t] : bpk); bdd = 1 - v[t] / bpk; if (bdd > bmax) bmax = bdd }
    else bpk = v[t]
    if (bi) bb[bi] += lb; by[yr] += lb
    for (gi = 1; gi <= ng; gi++) { g = G[gi]; on = (wi >= 1) ? gate[g, wi] : 0
      for (hi = 1; hi <= 3; hi++) { h = H[hi]; e = h * on
        lo = (t > 1) ? log(1 - e * rs) - e * borrow / 252 + (credit ? log(1 + e * cash) : 0) : 0
        k2 = g SUBSEP h; ov[k2] += lo; c = lb + lo; cum[k2] += c
        nav = exp(cum[k2]); if (nav > pk[k2] || t == 1) pk[k2] = nav; dd = 1 - nav / pk[k2]; if (dd > mx[k2]) mx[k2] = dd
        if (bi) cb[k2, bi] += c; cy[k2, yr] += c; if (on) { exd[k2]++; rg[k2, reg[wi]] += lo; rgd[k2, reg[wi]]++ } }
      if (mode == "episodes" && t > 1) { if (on && !inep[g]) { ne[g]++; es[g, ne[g]] = d[t]; ep0[g, ne[g]] = px[d[t-1]]; inep[g] = 1 }
        if (on) { el[g, ne[g]] += log(1 - rs); ee[g, ne[g]] = d[t]; if (d[t] in px) ep1[g, ne[g]] = px[d[t]] } else inep[g] = 0 } } }
  if (mode == "summary") {
    printf "base log %.4f maxdd %.2f%% bears %.4f %.4f %.4f\n", base, 100 * bmax, bb[1], bb[2], bb[3]
    for (gi = 1; gi <= ng; gi++) for (hi = 1; hi <= 3; hi++) { k2 = G[gi] SUBSEP H[hi]; nb = 0
      for (i = 1; i <= 3; i++) if (cb[k2, i] > bb[i]) nb++
      printf "%s h=%s days_on %d overlay %+.4f comb %.4f d_log %+.4f maxdd %.2f%% d_dd %+.2fpp bears %+.4f %+.4f %+.4f beats %d/3 c1 %d c2 %d c3 %d | UP %+.4f(%d) MIXED %+.4f(%d) DOWN %+.4f(%d)\n", \
        G[gi], H[hi], exd[k2], ov[k2], cum[k2], cum[k2] - base, 100 * mx[k2], 100 * (bmax - mx[k2]), cb[k2,1] - bb[1], cb[k2,2] - bb[2], cb[k2,3] - bb[3], nb, \
        (cum[k2] - base >= -0.05), (100 * (bmax - mx[k2]) >= 3), (nb >= 2), rg[k2,"UP"], rgd[k2,"UP"], rg[k2,"MIXED"], rgd[k2,"MIXED"], rg[k2,"DOWN"], rgd[k2,"DOWN"] } }
  if (mode == "episodes") for (gi = 1; gi <= ng; gi++) { g = G[gi]
    for (i = 1; i <= ne[g]; i++) printf "%s %d %s %s spy %+.2f%% short_log_h1 %+.4f\n", g, i, es[g,i], ee[g,i], (ep0[g,i] > 0 ? 100 * (ep1[g,i] / ep0[g,i] - 1) : 0), el[g,i] }
  if (mode == "years") for (y = 2000; y <= 2026; y++) { printf "%d base %+.4f", y, by[y]
    for (gi = 1; gi <= ng; gi++) printf " %s %+.4f", G[gi], cy[G[gi] SUBSEP "0.5", y] - by[y]; printf "\n" }
}
