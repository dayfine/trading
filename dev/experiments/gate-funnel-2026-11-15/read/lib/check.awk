# check.awk -- the read's self-check (README §Self-check): does candidates.sexp's top-N view agree with the screener's
# order and with trade_audit.sexp's own record of the walk? POSIX awk; load with
#   -f ../../../price-band-binding-2026-11-13/read/lib/rank.awk -f check.awk   (rank.awk: seeded_key, the Seeded hash)
#
# usage: awk -F'\t' -v SEED=0 -v CAP=20 -v OPEN=open.tsv -f rank.awk -f check.awk weeks.tsv cs.tsv walk.tsv rows.tsv
#   weeks.tsv  date n_long tickets_placed long_cash_left_pct long_resting_reserved_pct          (cands.awk WEEKS)
#   cs.tsv     date cah lma lba lsa lga lta entered macro_trend                                 (summ.awk)
#   walk.tsv   date idx symbol outcome   (price-band-binding audit.awk: the walk's Long names; Placed or the reason)
#   rows.tsv   date symbol outcome gate score rank walk wdist shadow sdist grade  (cands.awk; only the pool rows,
#              Admitted and Dropped_at_top_n, are held in memory)
# Writes OPEN: date open(1/0) live_blocked(1/0), one row per screened date. Prints the self-check report. Exit 3 when
# a hard check fails (SK1-SK3), else 0. SK4 and SK5 are reported, never gating.
FILENAME == ARGV[1] { nwk++; WK[nwk] = $1; NL[$1] = $2; TP[$1] = $3; CL[$1] = $4; RR[$1] = $5; next }
FILENAME == ARGV[2] { CSE[$1] = $8; LMA[$1] = $3; CAH[$1] = $2; LBA[$1] = $4; LSA[$1] = $5; LGA[$1] = $6; LTA[$1] = $7; next }
FILENAME == ARGV[3] { WO[$1, $3] = $4; nwalk[$1]++; WD[$1, nwalk[$1]] = $3; next }
{
  d = $1; ph[d, $3]++
  if ($9 == "Buyable" && (mxb == "" || $10 + 0 > mxb)) mxb = $10 + 0
  if ($9 == "Stop_too_wide" && (mnw == "" || $10 + 0 < mnw)) mnw = $10 + 0
  if ($7 == "Funded" && $8 != "-" && (mxf == "" || $8 + 0 > mxf)) mxf = $8 + 0
  if ($7 == "Skipped_Stop_too_wide" && $8 != "-" && (mnws == "" || $8 + 0 < mnws)) mnws = $8 + 0
  if ($3 != "Admitted" && $3 != "Dropped_at_top_n") next
  if ($3 == "Dropped_at_top_n" && $6 != "-" && $6 + 0 <= CAP) LB[d] = 1
  n[d]++; c = n[d]; RT[d, c] = $2; RO[d, c] = $3; RSC[d, c] = $5 + 0; RK[d, c] = $6; RW[d, c] = $7; RH[d, c] = $9
}
function bad(tag, msg) { nbad[tag]++; if (++shown[tag] <= 15) print tag " " msg }
function map_walk(w) { if (w == "Funded") return "Placed"; if (substr(w, 1, 8) == "Skipped_") return substr(w, 9); return w }
END {
  for (w = 1; w <= nwk; w++) one(WK[w])
  print "SK1 (rank: the pool is ranked 1..n in the Seeded order, and Admitted is exactly rank <= " CAP " on open Fridays): " (nbad["SK1"] ? "FAIL on " nbad["SK1"] " rows" : "PASS on " nopen " open Fridays, " npool " pool rows")
  print "SK2 (walk: each Admitted row's walk equals trade_audit's weekly decision for that name): " (nbad["SK2"] ? "FAIL on " nbad["SK2"] " rows" : "PASS on " nwalked " walked rows (" nnr " Not_reached rows have no decision, as they must)")
  print "SK3 (fields: tickets_placed = cascade_summary.entered; walk on every Admitted row, shadow on every cut row; long_cash_left_pct on every open Friday): " (nbad["SK3"] ? "FAIL on " nbad["SK3"] " items" : "PASS")
  printf "SK4 (information): open Fridays %d, macro-blocked %d (no Long rows), live-blocked %d (a cut row ranked <= %d); trace phase counts equal cascade_summary counts on %d of %d open Fridays; Long rows exist exactly when long_macro_admitted > 0 on %d of %d screened Fridays\n", nopen, nblk, nlive, CAP, agree, nopen, magree, nwk
  printf "SK5 (information): stop distance, as a fraction of the trigger -- shadow Buyable max %s, shadow Stop_too_wide min %s; walk Funded max %s, walk Skipped_Stop_too_wide min %s\n", fmt(mxb), fmt(mnw), fmt(mxf), fmt(mnws)
  printf "long_resting_reserved_pct present on %d of %d open Fridays\n", nrr, nopen
  if (nbad["SK1"] + nbad["SK2"] + nbad["SK3"] > 0) exit 3
}
function fmt(x) { return (x == "") ? "none" : sprintf("%.4f", x) }
function one(d,   c, k, nn, r, i, j, op, cnt) {
  nn = n[d] + 0
  # open: the trace emitted Long rows (its diagnostics gate admitted longs) and no cut row sits inside the cap (the
  # live gate did not block the side). See README §Definitions.
  op = (NL[d] + 0 > 0 && !(d in LB)) ? 1 : 0
  if (NL[d] + 0 == 0) nblk++; else if (!op) nlive++
  print d "\t" op "\t" ((d in LB) ? 1 : 0) > OPEN
  if ((d in CSE) && TP[d] != "NA" && TP[d] + 0 != CSE[d] + 0) bad("SK3", d " tickets_placed " TP[d] " entered " CSE[d])
  if ((d in LMA) && ((LMA[d] + 0 > 0) == (NL[d] + 0 > 0))) magree++
  if (!op) return
  nopen++
  if (CL[d] == "NA") bad("SK3", d " long_cash_left_pct absent on an open Friday")
  if (RR[d] != "NA") nrr++
  # SK1: collect pool rows by rank.
  delete byr; cnt = 0
  for (c = 1; c <= nn; c++) {
    if (RO[d, c] != "Admitted" && RO[d, c] != "Dropped_at_top_n") continue
    cnt++; npool++
    if (RK[d, c] == "-") { bad("SK1", d " " RT[d, c] " " RO[d, c] " has no rank"); continue }
    r = RK[d, c] + 0
    if (r in byr) bad("SK1", d " rank " r " twice")
    byr[r] = c
    if ((RO[d, c] == "Admitted") != (r <= CAP)) bad("SK1", d " " RT[d, c] " " RO[d, c] " rank " r)
    if (RO[d, c] == "Admitted" && RW[d, c] == "-") bad("SK3", d " " RT[d, c] " Admitted without walk")
    if (RO[d, c] == "Dropped_at_top_n" && RH[d, c] == "-") bad("SK3", d " " RT[d, c] " cut without shadow")
  }
  for (r = 1; r <= cnt; r++) if (!(r in byr)) { bad("SK1", d " rank " r " missing of " cnt); break }
  for (r = 1; r < cnt; r++) if ((r in byr) && ((r + 1) in byr)) {
    i = byr[r]; j = byr[r + 1]
    if (RSC[d, i] < RSC[d, j]) bad("SK1", d " score order at rank " r)
    else if (RSC[d, i] == RSC[d, j]) {
      hi = seeded_key(SEED, d, RT[d, i]); hj = seeded_key(SEED, d, RT[d, j])
      if (hi > hj || (hi == hj && RT[d, i] > RT[d, j])) bad("SK1", d " Seeded tie order at rank " r " (" RT[d, i] " before " RT[d, j] ")")
    }
  }
  # SK2: the walk record against the candidates' walk field, both directions.
  for (c = 1; c <= nn; c++) {
    if (RO[d, c] != "Admitted") continue
    if (RW[d, c] == "Not_reached") { nnr++; if ((d, RT[d, c]) in WO) bad("SK2", d " " RT[d, c] " Not_reached but walked " WO[d, RT[d, c]]); continue }
    nwalked++
    if (!((d, RT[d, c]) in WO)) { bad("SK2", d " " RT[d, c] " walk " RW[d, c] " has no decision"); continue }
    if (map_walk(RW[d, c]) != WO[d, RT[d, c]]) bad("SK2", d " " RT[d, c] " walk " RW[d, c] " decision " WO[d, RT[d, c]])
  }
  for (k = 1; k <= nwalk[d]; k++) { found = 0; for (c = 1; c <= nn; c++) if (RT[d, c] == WD[d, k] && RO[d, c] == "Admitted") found = 1
    if (!found) bad("SK2", d " decision for " WD[d, k] " has no Admitted row") }
  # SK4: the trace's phase counts against the cascade_summary's (same diagnostics gate, README §Self-check).
  if ((d in LMA) && LMA[d] - LBA[d] == ph[d, "Dropped_at_breakout"] && LBA[d] - LSA[d] == ph[d, "Dropped_at_sector"] && \
      LSA[d] - LGA[d] == ph[d, "Dropped_at_grade"] && LGA[d] - LTA[d] == ph[d, "Dropped_at_top_n"] && LTA[d] == ph[d, "Admitted"]) agree++
}
