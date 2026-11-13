# bind.awk -- self-check, then the offline Price_band_seeded re-rank of every screened date's long top-N pool.
# POSIX awk; load with -f rank.awk -f bind.awk. README.md §Measurements 1-2 define every quantity printed here.
#
# usage: awk -F'\t' -v SEED=0 -v CAP=20 -v N_ENTRIES=N -v R0=.. -v R1=.. -v R2=.. -v R3=.. \
#          -v FRIDAYS=f.tsv -v SWAPS=s.tsv -v SELF=selfcheck.txt -v GATES=gates.txt \
#          -f rank.awk -f bind.awk weeks.tsv walk.tsv pool.tsv
#   weeks.tsv  date n_long_rows                 (cands.awk WEEKS)
#   walk.tsv   date idx symbol outcome          (audit.awk: the entry walk's Long names in walk order)
#   pool.tsv   date symbol outcome score band   (Admitted + Dropped_at_top_n Long rows; band NA = no price)
# Writes SELF always. MODE=check stops there: exit 3 when the self-check fails (README §Self-check: the read stops),
# else 0; pass FRIDAYS=SWAPS=/dev/null. The full mode also writes FRIDAYS (one row per screened date, counts only),
# SWAPS (date dir symbol band score rank_S rank_P) and GATES, and prints the binding tables.
FILENAME == ARGV[1] { nwk++; WK[nwk] = $1; NL[$1] = $2; next }
FILENAME == ARGV[2] { nwalk[$1]++; WS[$1, $2] = $3; WO[$1, $2] = $4; next }
{ np[$1]++; k = np[$1]; PT[$1, k] = $2; PO[$1, k] = $3; PS[$1, k] = $4 + 0; PB[$1, k] = $5 }
END {
  for (w = 1; w <= nwk; w++) one_date(WK[w])
  self_report()
  if (sc1_bad + sc2_bad > 0) exit 3
  if (MODE == "check") exit 0
  for (b = 0; b <= 3; b++) Q[b] = (adm[b] > 0) ? fund[b] / adm[b] : 0
  for (w = 1; w <= nwk; w++) redraw(WK[w])
  report()
}

# Load one date's pool, rank it three ways, and map S's walk onto it. Returns the pool size.
function load(d,   n, i, r, k) {
  delete SC; delete BD; delete HK; delete TK; delete oS; delete oP; delete oA; delete rS; delete rP; delete inS; delete inP
  delete wout; delete wrank; delete walked
  n = np[d] + 0
  for (i = 1; i <= n; i++) {
    TK[i] = PT[d, i]; SC[i] = PS[d, i]; HK[i] = seeded_key(SEED, d, TK[i])
    if (PB[d, i] == "NA") { BD[i] = 3; if (!(d in na_seen)) band_na++ } else BD[i] = PB[d, i] + 0
  }
  na_seen[d] = 1
  rank_sort(n, "S", oS); rank_sort(n, "P", oP); rank_sort(n, "A", oA)
  for (r = 1; r <= n; r++) { rS[oS[r]] = r; rP[oP[r]] = r; inS[oS[r]] = (r <= CAP); inP[oP[r]] = (r <= CAP) }
  for (k = 1; k <= nwalk[d]; k++) for (i = 1; i <= n; i++) if (TK[i] == WS[d, k]) { wout[i] = WO[d, k]; walked[i] = 1; wrank[k] = i }
  return n
}

function one_date(d,   n, i, k, r, b, half, binding, ties, nb, changed, ordch, swaps, sc1, sc2, alpha, nadm, last, maxr, npl) {
  n = load(d); half = (d <= "2012-12-31") ? 1 : 2
  if (NL[d] == 0) { mblk++; print d "\t0\t0\t0\t0\t0\t0\t0\t0\t0\tna\tna\tna\t0\t0" > FRIDAYS; return }
  open_n++; open_h[half]++
  # SC1: the first CAP names of the Seeded order are exactly the Admitted rows.
  sc1 = "ok"; alpha = "same"; nadm = 0
  for (r = 1; r <= n; r++) {
    i = oS[r]; if (PO[d, i] == "Admitted") nadm++
    if ((PO[d, i] == "Admitted") != inS[i]) { sc1 = "FAIL"; if (++sc1_rows <= 20) print "SC1 " d " " TK[i] " " PO[d, i] " rank_S=" r > SELF }
  }
  for (r = 1; r <= n; r++) { i = oA[r]; if ((PO[d, i] == "Admitted") != (r <= CAP)) alpha = "diff" }
  if (sc1 == "FAIL") sc1_bad++
  if (alpha == "diff") alpha_diff++
  # SC2: the walk's Long names, in walk order, are top-N members whose Seeded ranks strictly increase.
  sc2 = (nwalk[d] > 0) ? "ok" : "na"; last = 0
  for (k = 1; k <= nwalk[d]; k++) {
    i = (k in wrank) ? wrank[k] : 0
    if (i == 0 || !inS[i] || rS[i] <= last) { sc2 = "FAIL"; if (++sc2_rows <= 20) print "SC2 " d " walk#" k " " WS[d, k] > SELF }
    else last = rS[i]
  }
  if (sc2 == "FAIL") sc2_bad++
  if (sc2 == "ok") sc2_ok++
  # Measurement 1: the cut and the re-rank.
  binding = (n > CAP); ties = 0; nb = 0; changed = 0; ordch = 0; swaps = 0
  if (binding) {
    bind_n++; bind_h[half]++
    if (SC[oS[CAP]] == SC[oS[CAP + 1]]) {
      ties = 1; tie_n++; delete seen
      for (i = 1; i <= n; i++) if (SC[i] == SC[oS[CAP]] && !(BD[i] in seen)) { seen[BD[i]] = 1; nb++ }
      if (nb > 1) multi_n++
    }
  }
  for (r = 1; r <= n && r <= CAP; r++) if (oS[r] != oP[r]) ordch = 1
  for (i = 1; i <= n; i++) {
    if (inS[i] && !inP[i]) { swaps++; print d "\tout\t" TK[i] "\t" BD[i] "\t" SC[i] "\t" rS[i] "\t" rP[i] > SWAPS; sw_out[BD[i]]++ }
    if (!inS[i] && inP[i]) { print d "\tin\t" TK[i] "\t" BD[i] "\t" SC[i] "\t" rS[i] "\t" rP[i] > SWAPS; sw_in[BD[i]]++ }
  }
  if (swaps > 0) { changed = 1; chg_n++; chg_h[half]++; swaps_tot += swaps; hist[(swaps >= 6) ? 6 : swaps]++ }
  if (ordch) ord_n++
  CHG[d] = changed
  # Funded prefix: the names S walked through up to its last placement (S ranks 1..maxr) against P's first maxr.
  maxr = 0; npl = 0
  for (i = 1; i <= n; i++) if (wout[i] == "Placed") { npl++; if (rS[i] > maxr) maxr = rS[i] }
  if (maxr > 0) {
    pfx_n++; delete pfx; for (r = 1; r <= maxr; r++) pfx[oS[r]] = 1
    for (r = 1; r <= maxr; r++) if (!(oP[r] in pfx)) { pfx_chg++; break }
  }
  # S's top-N by band: admitted, walked (post-cut gates passed), placed, fundable (placed or skipped for cash only).
  for (i = 1; i <= n; i++) if (inS[i]) {
    b = BD[i]; adm[b]++; if (i in walked) wlk[b]++
    if (wout[i] == "Placed") { plc[b]++; plc_all++ }
    if (wout[i] == "Placed" || wout[i] == "Insufficient_cash") fund[b]++
  }
  print d "\t" NL[d] "\t" n "\t" nadm "\t" binding "\t" ties "\t" (nb > 1) "\t" changed "\t" swaps "\t" ordch "\t" sc1 "\t" sc2 "\t" alpha "\t" nwalk[d] + 0 "\t" npl > FRIDAYS
}

# Measurement 2: the funded tickets P's order would re-draw on this date, on S's path (README §Measurement 2).
# A name's fundability: S's walk outcome when S walked it (Placed or Insufficient_cash = fundable, any other skip =
# not); 0 when it sat in S's top-N but a post-cut gate dropped it; Q[band] (S's per-band fundable share of its top-N)
# when S cut it. When S's walk ran out of cash (any Insufficient_cash), both orders fund only as many tickets as S
# placed, in their own order; otherwise every fundable top-N name is funded. Expected values, not draws.
function fundable(i) { if (inS[i]) return (wout[i] == "Placed" || wout[i] == "Insufficient_cash") ? 1 : 0; return Q[BD[i]] }
function walk_order(o, cash, m, e,   r, cum, x, p) {
  cum = 0
  for (r = 1; r <= CAP && (r in o); r++) {
    x = o[r]; p = fundable(x)
    if (cash && cum + p > m) p = (m - cum > 0) ? m - cum : 0
    cum += p; e[x] = p
  }
}
function redraw(d,   n, k, cash, m, i, eS, eP, sx, px, ch, b, mism) {
  if (NL[d] == 0) return
  n = load(d); if (n == 0) return
  cash = 0; m = 0
  for (k = 1; k <= nwalk[d]; k++) { if (WO[d, k] == "Insufficient_cash") cash = 1; if (WO[d, k] == "Placed") m++ }
  if (cash) cash_n++
  delete eS; delete eP
  walk_order(oS, cash, m, eS); walk_order(oP, cash, m, eP)
  mism = 0; for (i = 1; i <= n; i++) if (((i in eS) ? eS[i] : 0) != ((wout[i] == "Placed") ? 1 : 0)) mism = 1
  model_n++; if (!mism) model_ok++
  ch = CHG[d] ? "cut" : "order"
  for (i = 1; i <= n; i++) {
    sx = (wout[i] == "Placed") ? 1 : 0; px = (i in eP) ? eP[i] : 0; b = BD[i]
    if (px > sx) { rin[b] += px - sx; rin_ch[ch] += px - sx }
    if (sx > px) { rout[b] += sx - px; rout_ch[ch] += sx - px }
  }
}

function pct(a, b) { return (b > 0) ? sprintf("%.1f %%", 100 * a / b) : "n/a" }

function self_report() {
  print "SC1 (the Seeded re-rank reproduces the Admitted set): " (sc1_bad ? "FAIL on " sc1_bad " dates" : "PASS on all " open_n " longs-open dates") > SELF
  print "SC2 (the walk order is the Seeded order): " (sc2_bad ? "FAIL on " sc2_bad " dates" : "PASS on all " sc2_ok " dates with a walk record") > SELF
  print "SC power: the cut fell inside a score tie on " tie_n + 0 " dates; the Alphabetical control misses the Admitted set on " alpha_diff + 0 " dates" > SELF
  print "pool rows with no price (band NA, ranked in the top band): " band_na + 0 > SELF
}

function report(   b, L, fill, enet, rr, tin, tout, yrs) {
  split("<$8 $8-14 $14-33 >=$33", L, " ")
  print "== Measurement 1: how often the band order binds (README §Measurements) =="
  printf "screened dates %d | longs macro-blocked %d | longs open %d (2000-12 %d, 2013-26 %d)\n", nwk, mblk, open_n, open_h[1], open_h[2]
  printf "cap binds (pool > %d): %d = %s of open dates (2000-12 %s, 2013-26 %s)\n", CAP, bind_n, pct(bind_n, open_n), pct(bind_h[1], open_h[1]), pct(bind_h[2], open_h[2])
  printf "  of which the cut falls inside a score tie: %d (%s of binding); the tie spans >1 band: %d (%s)\n", tie_n, pct(tie_n, bind_n), multi_n, pct(multi_n, bind_n)
  printf "top-%d set changes: %d = %s of open dates, %s of binding dates (L1)\n", CAP, chg_n, pct(chg_n, open_n), pct(chg_n, bind_n)
  printf "  by half: 2000-12 %s of binding, 2013-26 %s of binding\n", pct(chg_h[1], bind_h[1]), pct(chg_h[2], bind_h[2])
  printf "top-%d order changes (set or sequence): %d = %s of open dates\n", CAP, ord_n, pct(ord_n, open_n)
  printf "funded prefix changes (S ranks 1..last placed vs P's first as many): %d of %d dates with a placement (%s)\n", pfx_chg, pfx_n, pct(pfx_chg, pfx_n)
  printf "names swapped at the cut: %d each way; per changed date mean %.2f | changed dates by swaps 1 %d, 2 %d, 3 %d, 4 %d, 5 %d, 6+ %d\n", swaps_tot, (chg_n ? swaps_tot / chg_n : 0), hist[1], hist[2], hist[3], hist[4], hist[5], hist[6]
  print "swaps at the cut by band: " L[1] "  " L[2] "  " L[3] "  " L[4]
  printf "  swapped out      %5d %5d %5d %5d\n", sw_out[0], sw_out[1], sw_out[2], sw_out[3]
  printf "  swapped in       %5d %5d %5d %5d\n", sw_in[0], sw_in[1], sw_in[2], sw_in[3]
  fill = (plc_all > 0) ? N_ENTRIES / plc_all : 0
  print "== Measurement 2: the funded tickets the order re-draws on this path, and what they are worth (README §Measurements) =="
  printf "S's top-%d names by band (open dates): admitted / walked (post-cut gates passed) / placed / fundable = Q\n", CAP
  for (b = 0; b <= 3; b++) printf "  %-7s %6d / %6d (%s) / %5d (%s) / %5d  Q = %.4f\n", L[b + 1], adm[b], wlk[b], pct(wlk[b], adm[b]), plc[b], pct(plc[b], adm[b]), fund[b], Q[b]
  printf "model check: the funding model run on S's own order reproduces S's placed set on %d of %d open dates with a pool (%s); S's walk ran out of cash on %d of them\n", model_ok, model_n, pct(model_ok, model_n), cash_n
  printf "fill ratio = entries %d / placed tickets %d = %.3f\n", N_ENTRIES, plc_all, fill
  rr[0] = R0; rr[1] = R1; rr[2] = R2; rr[3] = R3; enet = 0
  for (b = 0; b <= 3; b++) {
    printf "  %-7s expected tickets re-drawn in %7.2f out %7.2f   r = %.4f\n", L[b + 1], rin[b], rout[b], rr[b]
    enet += (rin[b] - rout[b]) * fill * rr[b]; tin += rin[b]; tout += rout[b]
  }
  yrs = (open_n + mblk) / 52.18
  printf "re-drawn tickets: in %.1f, out %.1f (%.2f a year over %.1f screened years); by channel: cut dates in %.1f / out %.1f, order-only dates in %.1f / out %.1f\n", tin, tout, (yrs > 0 ? tin / yrs : 0), yrs, rin_ch["cut"], rout_ch["cut"], rin_ch["order"], rout_ch["order"]
  printf "E_net = fill x sum over bands of (in - out) x r = %.3f expected net >= +100 %% trades over the window (L2)\n", enet
  printf "L1 %.4f L2 %.4f\n", (bind_n ? chg_n / bind_n : 0), enet > GATES
}
