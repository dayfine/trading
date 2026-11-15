# pair.awk -- one seed's paired read of arm A against the base S (dev/plans/axis-observatory-2026-11-14.md §1).
# D(t) = ln(NAV_A(t) / NAV_S(t)) at the last equity-curve row of each Monday-aligned week, from an anchor of 0 on the
# first row (both arms start from the same cash: the summaries' initial_cash must be equal), so the weekly steps sum to
# D_end.
# Operands, each preceded by role=<R>: Y the SPY years file ("YYYY bull|bear" lines, # comments; /dev/null if none),
# M the base's macro_trend.sexp, SE AE equity_curve.csv, ST AT trades.csv, SO AO open_positions.csv, SS AS summary.sexp.
# Variables: seed (k0), out (the private out dir), have_years (1 when Y is a real file). Needs common.awk.
# Writes into out, all private (price-derived): D-<seed>.tsv, steps-<seed>.tsv (every step with its macro state and the
# three heaviest diff positions active in its week), years-<seed>.tsv, firstdiff-<seed>.tsv (the keyed trades diff of
# ../../../price-band-confirm-2026-11-13/chain.sh, open positions included). Prints one mark-free line for row.awk:
# M seed D_end years pos_years neg_years D_by_Bullish D_by_Neutral D_by_Bearish D_other D_bull_yrs D_bear_yrs max_share
# top5 dMaxDD dUlcer dHeld dEntries_per_yr s_out a_new first_differing_equity_date.
BEGIN { DZERO = 0.00005; EPS = 1e-9; FD = out "/firstdiff-" seed ".tsv"; printf "" > FD }
function die(m) { print "obs_read: " seed ": " m > "/dev/stderr"; failed = 1; exit 2 }
function blank20(s,   f, n, i, o) {   # the row with position_id (column 20) blanked: an id-shift is not a change
  n = split(s, f, ","); if (n >= 20) f[20] = ""
  o = f[1]; for (i = 2; i <= n; i++) o = o "," f[i]
  return o
}
function addpos(a, s, e, x, px, q, c, r,   k) {   # key symbol|entry_date, the firstdiff key
  k = s "|" e; while ((a, k) in has) k = k "+"
  if (!(k in seen)) { seen[k] = 1; nk++; kl[nk] = k; ksym[k] = s; kent[k] = e }
  has[a, k] = 1; ext[a, k] = x; sz[a, k] = px * q; con[a, k] = c; row[a, k] = r; np[a]++; ey[a, substr(e, 1, 4)]++
}
role == "Y" { if ($0 !~ /^#/ && NF >= 2) yreg[$1] = tolower($2); next }
role == "M" { mbuf = mbuf " " $0; next }
role ~ /E$/ { if (split($0, f, ",") < 2 || f[1] == "date") next
  a = substr(role, 1, 1); nc[a]++; cd[a, nc[a]] = f[1]; cv[a, nc[a]] = f[2] + 0; next }
role ~ /T$/ { if (split($0, f, ",") < 9 || f[1] == "symbol") next
  addpos(substr(role, 1, 1), f[1], f[3], f[4], f[6], f[8], f[9] + f[25], $0); next }
role ~ /O$/ { if (split($0, f, ",") < 5 || f[1] == "symbol") next
  addpos(substr(role, 1, 1), f[1], f[3], "", f[4], f[5], "", $0); next }
role ~ /S$/ { a = substr(role, 1, 1)
  if (match($0, /\(initial_cash -?[0-9.]+\)/)) ic[a] = substr($0, RSTART + 14, RLENGTH - 15)
  if (match($0, /maxdrawdown -?[0-9.]+/)) mdd[a] = substr($0, RSTART + 12, RLENGTH - 12) + 0
  if (match($0, /ulcerindex -?[0-9.]+/)) ulc[a] = substr($0, RSTART + 11, RLENGTH - 11) + 0
  next }
function pairing(   i) {   # same starting cash, and the two curves share every date: same window, same build
  if (!("S" in ic) || !("A" in ic)) die("a summary.sexp has no initial_cash, so equal starting cash cannot be checked")
  if (ic["S"] + 0 != ic["A"] + 0) die("the arms start from different cash: S " ic["S"] ", A " ic["A"])
  if (nc["S"] == 0 || nc["S"] != nc["A"]) die("equity curves differ in length: S " nc["S"] ", A " nc["A"] " rows")
  fdd = "-"
  for (i = 1; i <= nc["S"]; i++) {
    if (cd["S", i] != cd["A", i]) die("equity curves differ at row " i ": " cd["S", i] " vs " cd["A", i])
    if (i > 1 && cd["S", i] <= cd["S", i - 1]) die("equity curve not in date order at " cd["S", i])
    if (cv["S", i] <= 0 || cv["A", i] <= 0) die("non-positive NAV on " cd["S", i])
    if (fdd == "-" && cv["S", i] != cv["A", i]) fdd = cd["S", i] }
}
function samples(   i, n, f) {
  n = nc["S"]; ns = 0; sd[0] = cd["S", 1]; dv[0] = 0; f = out "/D-" seed ".tsv"; print "date\tD" > f
  for (i = 1; i <= n; i++) if (i == n || wk(cd["S", i + 1]) != wk(cd["S", i])) {
    ns++; sd[ns] = cd["S", i]; dv[ns] = log(cv["A", i] / cv["S", i]); sw[wk(sd[ns])] = ns; print sd[ns] "\t" fmt(dv[ns], 6) > f }
  dend = dv[ns]; span = (dn(sd[ns]) - dn(sd[0])) / 365.25
}
function wgt(a, k) {   # NAV-% of the arm at entry: the contribution of a closed position, the size of an open one
  return 100 * (ext[a, k] == "" ? sz[a, k] : con[a, k]) / navat(a, kent[k])
}
function fd(k, kind, r) { print kent[k] "\t" ksym[k] "\t" kind "\t" r > FD }
function adddiff(k, c, x, w) { ndf++; dfk[ndf] = k; dfc[ndf] = c; dfx[ndf] = x; dfw[ndf] = (w < 0) ? -w : w }
function diffs(   i, k, x) {   # classes as trades_keyed_diff: arm-only (A), base-only (S), changed (C), id-shift
  for (i = 1; i <= nk; i++) { k = kl[i]
    if (("S", k) in has && ("A", k) in has) {
      if (row["S", k] == row["A", k]) continue
      if (blank20(row["S", k]) == blank20(row["A", k])) { fd(k, "id-shift", row["S", k] " -> " row["A", k]); continue }
      fd(k, "changed-base", row["S", k]); fd(k, "changed-arm", row["A", k])
      x = (ext["S", k] == "" || ext["A", k] == "") ? "" : (ext["S", k] > ext["A", k]) ? ext["S", k] : ext["A", k]
      adddiff(k, "C", x, wgt("A", k) - wgt("S", k))
    } else if (("A", k) in has) { fd(k, "arm-only", row["A", k]); nnew++; adddiff(k, "A", ext["A", k], wgt("A", k)) }
    else { fd(k, "base-only", row["S", k]); nout++; adddiff(k, "S", ext["S", k], wgt("S", k)) } }
}
function sidx(d,   w) { w = wk(d); return (w in sw) ? sw[w] : (d < sd[1]) ? 1 : ns + 1 }
function held(   t, a, i, k, j, c) {   # positions held at each weekly sample, per arm and per year
  for (t = 1; t <= 2; t++) { a = (t == 1) ? "S" : "A"
    for (i = 1; i <= nk; i++) { k = kl[i]; if (!((a, k) in has)) continue
      hd[a, sidx(kent[k])]++; if (ext[a, k] != "") hd[a, sidx(ext[a, k])]-- }
    c = 0
    for (j = 1; j <= ns; j++) { c += hd[a, j]; hc[a] += c
      hy[a, substr(sd[j], 1, 4)] += c; if (t == 1) ny[substr(sd[j], 1, 4)]++ } }
}
function macro(   s, r, t, j, p) {   # a step's state is the latest record on or before its first day's eve
  s = mbuf
  while (match(s, /\(date [0-9-]+\)[ ]*\(trend [A-Za-z_]+\)/)) {
    r = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH); split(r, t, /[() ]+/); nm++; md[nm] = t[3]; ms[nm] = t[5] }
  p = 0
  for (j = 1; j <= ns; j++) { while (p < nm && md[p + 1] <= sd[j - 1]) p++
    mst[j] = (p > 0) ? ms[p] : "NA"; mac[mst[j]] += dv[j] - dv[j - 1] }
}
function better(i, b) { return dfw[i] > dfw[b] || (dfw[i] == dfw[b] && dfk[i] < dfk[b]) }
function names(j,   i, b1, b2, b3, o) {   # the three heaviest diff positions held at some point in (sd[j-1], sd[j]]
  b1 = b2 = b3 = 0
  for (i = 1; i <= ndf; i++) { if (kent[dfk[i]] > sd[j] || (dfx[i] != "" && dfx[i] <= sd[j - 1])) continue
    if (!b1 || better(i, b1)) { b3 = b2; b2 = b1; b1 = i }
    else if (!b2 || better(i, b2)) { b3 = b2; b2 = i }
    else if (!b3 || better(i, b3)) b3 = i }
  o = b1 ? ptag(b1) : "-"; if (b2) o = o "," ptag(b2); if (b3) o = o "," ptag(b3)
  return o
}
function ptag(i) { return ksym[dfk[i]] "@" kent[dfk[i]] "/" dfc[i] }
function share(j) { return (dend > DZERO || dend < -DZERO) ? (dv[j] - dv[j - 1]) / dend : "NA" }
function steps_out(   j, f, s) {
  f = out "/steps-" seed ".tsv"; print "date\tprev_date\tdD\tshare\tmacro\tdiff_positions" > f
  for (j = 1; j <= ns; j++) { nms[j] = names(j); s = share(j)
    print sd[j] "\t" sd[j - 1] "\t" sgn(dv[j] - dv[j - 1], 6) "\t" (s == "NA" ? s : sgn(s, 4)) "\t" mst[j] "\t" nms[j] > f }
}
function years_out(   j, y, i, r, f) {
  for (j = 1; j <= ns; j++) { y = substr(sd[j], 1, 4)
    if (!(y in inc)) { nyr++; yl[nyr] = y; inc[y] = 0 }
    inc[y] += dv[j] - dv[j - 1] }
  f = out "/years-" seed ".tsv"; print "year\tregime\tdD\tentries_S\tentries_A\tmean_held_S\tmean_held_A" > f
  for (i = 1; i <= nyr; i++) { y = yl[i]; r = (y in yreg) ? yreg[y] : "NA"
    if (inc[y] > EPS) npos++; else if (inc[y] < -EPS) nneg++
    if (r == "bull") bully += inc[y]; else if (r == "bear") beary += inc[y]
    print y "\t" r "\t" sgn(inc[y], 4) "\t" (ey["S", y] + 0) "\t" (ey["A", y] + 0) "\t" \
      fmt(hy["S", y] / ny[y], 2) "\t" fmt(hy["A", y] / ny[y], 2) > f }
}
function top5(   r, j, b, used) {   # the five steps carrying the largest shares of D_end, largest first
  mx = "NA"; t5 = "-"; if (share(1) == "NA") return
  for (r = 1; r <= 5 && r <= ns; r++) { b = 0
    for (j = 1; j <= ns; j++) if (!(j in used) && (!b || share(j) > share(b))) b = j
    used[b] = 1; if (r == 1) { mx = fmt(share(b), 3); t5 = "" } else t5 = t5 "; "
    t5 = t5 sd[b] " " sgn(share(b), 3) " [" nms[b] "]" }
}
function dm(x, a, b) { return ((a in x) && (b in x)) ? fmt(x[b] - x[a], 2) : "NA" }
END {
  if (failed) exit 2
  pairing(); samples(); diffs(); held(); macro(); steps_out(); years_out(); top5()
  printf "M\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\n", seed, fmt(dend, 4), nyr, npos,
    nneg, fmt(mac["Bullish"], 4), fmt(mac["Neutral"], 4), fmt(mac["Bearish"], 4),
    fmt(dend - mac["Bullish"] - mac["Neutral"] - mac["Bearish"], 4), have_years ? fmt(bully, 4) : "NA",
    have_years ? fmt(beary, 4) : "NA", mx, t5, dm(mdd, "S", "A"), dm(ulc, "S", "A"), fmt((hc["A"] - hc["S"]) / ns, 2),
    (span > 0 ? fmt((np["A"] - np["S"]) / span, 2) : "NA"), nout, nnew, fdd
}
