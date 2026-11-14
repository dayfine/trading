#!/bin/sh
# decide.sh -- applies the README's §Decision rule to ONE cell, as written, from the collected artifacts. It prints
# every quantity the rule reads, per seed and pooled, and then the cell outcome:
#   validity      V6 (pbcC-P-kK-s0.v6diff-S.log ends exit=0) and n_symbols_absent=1 in both arms' cache lines
#   liveness      B = share of Friday-pairs (both arms recorded a post-cut list) whose lists differ
#                 G = share of S-not-P names priced >= $33 minus share of P-not-S names priced >= $33 (pp)
#   return        Dk = ln(1+R_P) - ln(1+R_S); median Dk; delta = max(0.20, m_S), m_S = median |ln S_i - ln S_j|
#   drawdown      median(maxDD_P) - median(maxDD_S), arm medians, in pp
#   concentration per seed, the one-arm net (sum of P-only nav_pct minus S-only) after dropping the three largest
#                 P-only and the three largest S-only positions (#3595 onearm_split trim 3)
# Bars and their reasons: README §Decision rule. This script only computes; it carries the bars as named constants.
#
# usage: sh decide.sh RESULTS_DIR TAG LIST_BANDS_TSV POSITIONS_TSV
#   TAG = pbc1 | pbc2; or pb with RESULTS_DIR = the #3595 results, which reproduces that read's figures
R=${1:?usage: sh decide.sh RESULTS_DIR TAG LIST_BANDS_TSV POSITIONS_TSV}; T=${2:?}; LB=${3:?}; POS=${4:?}
B_BAR=33; G_BAR=40; MIN_PAIRS=100; DELTA_FLOOR=0.20; DD_BAR=3.0; TRIM=3

# --- validity: which seeds enter the read
seeds=""
for k in 0 1 2 3 4; do
  s=$R/k$k/$T-S-k$k-s0-; p=$R/k$k/$T-P-k$k-s0-
  if [ ! -s "${s}actual.sexp" ] || [ ! -s "${p}actual.sexp" ]; then echo "k$k: EXCLUDED (a cell has no actual.sexp)"; continue; fi
  v6=$(tail -1 "$R/k$k/$T-P-k$k-s0.v6diff-S.log" 2>/dev/null)
  ab=$(cat "$R/k$k/$T-S-k$k-s0.log" "$R/k$k/$T-P-k$k-s0.log" 2>/dev/null | sed -n 's/.*Panel_runner: snapshot cache hits.*n_symbols_absent=\([0-9]*\).*/\1/p' | tr '\n' ' ')
  if [ "$v6" != "exit=0" ]; then echo "k$k: EXCLUDED (V6 diff: ${v6:-missing})"; continue; fi
  if [ "$ab" != "1 1 " ]; then echo "k$k: VOID (n_symbols_absent: ${ab:-missing}, expected 1 1)"; continue; fi
  seeds="$seeds $k"; echo "k$k: valid (V6 exit=0, n_symbols_absent=1 in both arms)"
done
n=$(echo $seeds | wc -w | tr -d ' ')
echo "seeds in the read: ${seeds:- none} (n=$n)"
[ "$n" -gt 0 ] || { echo "CELL $T OUTCOME INCONCLUSIVE (no valid seed)"; exit 0; }

# --- liveness (README B, G): recorded lists of both arms, bands from LIST_BANDS_TSV
for k in $seeds; do
  awk -F'\t' -v k="k$k" '
    FNR == 1 { f++ }
    f == 1 { band[$1 "|" $2] = $3; next }
    $1 == "position_id" { next }
    { arm = (f == 2) ? "S" : "P"; mem[arm, $3] = mem[arm, $3] " " $2; rec[arm, $3] = 1; alld[$3] = 1
      if ($4 == "placed") { pl[arm, $2 "|" $3] = 1; npl[arm]++ } }
    END { for (d in alld) { if (!((("S", d) in rec) && (("P", d) in rec))) continue; both++
        nS = split(mem["S", d], ms, " "); nP = split(mem["P", d], mp, " "); delete inS; delete inP
        for (j = 1; j <= nS; j++) inS[ms[j]] = 1; for (j = 1; j <= nP; j++) inP[mp[j]] = 1
        same = 1
        for (x in inS) if (!(x in inP)) { same = 0; b = band[x "|" d]; if (b == "NA" || b == "") sna++; else { sn++; if (b == 3) s3++ } }
        for (x in inP) if (!(x in inS)) { same = 0; b = band[x "|" d]; if (b == "NA" || b == "") pna++; else { pn++; if (b == 3) p3++ } }
        chg += 1 - same }
      redraw = 0; for (x in pl) { split(x, xx, SUBSEP); if (xx[1] == "P" && !(("S", xx[2]) in pl)) redraw++ }
      printf "LIVE %s pairs=%d changed=%d S-not-P=%d(>=33:%d,NA:%d) P-not-S=%d(>=33:%d,NA:%d) P-tickets=%d not-placed-by-S=%d\n",
        k, both, chg, sn, s3, sna, pn, p3, pna, npl["P"], redraw }' \
    "$LB" "$R/k$k/$T-S-k$k-s0-entries.tsv" "$R/k$k/$T-P-k$k-s0-entries.tsv"
done > "${TMPDIR:-/tmp}/decide-live.$$"
awk -v BB="$B_BAR" -v GB="$G_BAR" -v MP="$MIN_PAIRS" '
  function v(s, key,   r) { r = s; sub(".*" key "=", "", r); sub("[^0-9].*", "", r); return r + 0 }
  { split($0, f, " "); k = f[2]
    pr = v($0, "pairs"); ch = v($0, "changed")
    s = $0; sub(/.*S-not-P=/, "", s); sn = s + 0; sub(/^[0-9]+\(>=33:/, "", s); s3 = s + 0
    p = $0; sub(/.*P-not-S=/, "", p); pn = p + 0; sub(/^[0-9]+\(>=33:/, "", p); p3 = p + 0
    t = $0; sub(/.*P-tickets=/, "", t); pt = t + 0; sub(/^[0-9]+ not-placed-by-S=/, "", t); rd = t + 0
    PR += pr; CH += ch; SN += sn; S3 += s3; PN += pn; P3 += p3; PT += pt; RD += rd
    printf "liveness %s: Friday-pairs %d, lists changed %.1f %%; >=$33 share S-not-P %.1f %% (n %d), P-not-S %.1f %% (n %d), gap %.1f pp; P tickets not placed by S that Friday %.1f %%\n",
      k, pr, 100 * ch / pr, 100 * s3 / sn, sn, 100 * p3 / pn, pn, 100 * s3 / sn - 100 * p3 / pn, 100 * rd / pt }
  END { l1 = 100 * CH / PR; l2 = 100 * S3 / SN - 100 * P3 / PN
    printf "liveness pooled: Friday-pairs %d; B lists changed %.1f %% (bar %d %%); G >=$33 gap %.1f pp (S-not-P %.1f %%, P-not-S %.1f %%; bar %d pp); P tickets re-drawn %.1f %%\n",
      PR, l1, BB, l2, 100 * S3 / SN, 100 * P3 / PN, GB, 100 * RD / PT
    st = (PR < MP) ? "THIN" : ((l1 >= BB && l2 >= GB) ? "LIVE" : "NOT_LIVE")
    print "LIVENESS " st }' "${TMPDIR:-/tmp}/decide-live.$$" | tee "${TMPDIR:-/tmp}/decide-live2.$$"
live=$(sed -n 's/^LIVENESS //p' "${TMPDIR:-/tmp}/decide-live2.$$"); rm -f "${TMPDIR:-/tmp}"/decide-live*.$$

# --- return, drawdown, concentration
for k in $seeds; do
  for a in S P; do
    tr '\n' ' ' < "$R/k$k/$T-$a-k$k-s0-actual.sexp" | awk -v k="$k" -v a="$a" '
      function grab(key,   re) { re = "\\(" key " [-0-9.e+]+\\)"
        if (match($0, re)) return substr($0, RSTART + length(key) + 2, RLENGTH - length(key) - 3); return "NA" }
      { printf "RET %s %s %s %s\n", k, a, grab("total_return_pct"), grab("max_drawdown_pct") }'
  done
done > "${TMPDIR:-/tmp}/decide-ret.$$"
awk -F'\t' -v N="$TRIM" 'NR > 1 && $2 != "shared" { k = substr($1, 2); c = $2; m = ++n[k, c]; v[k, c, m] = $13; s[k, c] += $13; K[k] = 1 }
  END { for (k in K) { for (ci = 1; ci <= 2; ci++) { c = (ci == 1) ? "P-only" : "S-only"; m = n[k, c]
          for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) if (v[k, c, j] > v[k, c, i]) { t = v[k, c, i]; v[k, c, i] = v[k, c, j]; v[k, c, j] = t }
          top[c] = 0; for (i = 1; i <= N && i <= m; i++) top[c] += v[k, c, i] }
        net = s[k, "P-only"] - s[k, "S-only"]; printf "CON %s %.1f %.1f\n", k, net, net - top["P-only"] + top["S-only"] } }' "$POS" \
  >> "${TMPDIR:-/tmp}/decide-ret.$$"
awk -v live="$live" -v T="$T" -v n="$n" -v D0="$DELTA_FLOOR" -v DDB="$DD_BAR" -v TR="$TRIM" -v seeds="$seeds" '
  function med(a, m,   i, j, t, b) { for (i = 1; i <= m; i++) b[i] = a[i]
    for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) if (b[j] < b[i]) { t = b[i]; b[i] = b[j]; b[j] = t }
    return (m % 2) ? b[(m + 1) / 2] : (b[m / 2] + b[m / 2 + 1]) / 2 }
  $1 == "RET" { L[$2, $3] = log(1 + $4 / 100); R[$2, $3] = $4; DD[$2, $3] = $5 }
  $1 == "CON" { NET[$2] = $3; TRM[$2] = $4 }
  END { m = split(seeds, ks, " ")
    for (i = 1; i <= m; i++) { k = ks[i]; d[i] = L[k, "P"] - L[k, "S"]; ls[i] = L[k, "S"]; ddp[i] = DD[k, "P"]; dds[i] = DD[k, "S"]
      pdd[i] = DD[k, "P"] - DD[k, "S"]; if (d[i] > 0) pos++; if (TRM[k] > 0) tpos++
      printf "seed k%s: R_S %.2f %% R_P %.2f %% | ln S %.4f P %.4f | Dk %+.4f | maxDD S %.2f P %.2f (P-S %+.2f) | one-arm net %+.1f, trim %d %+.1f\n",
        k, R[k, "S"], R[k, "P"], L[k, "S"], L[k, "P"], d[i], DD[k, "S"], DD[k, "P"], DD[k, "P"] - DD[k, "S"], NET[k], TR, TRM[k] }
    np = 0; for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) { x = ls[i] - ls[j]; pr[++np] = (x < 0) ? -x : x }
    mS = (np > 0) ? med(pr, np) : 0; delta = (mS > D0) ? mS : D0; md = med(d, m)
    ddiff = med(ddp, m) - med(dds, m)
    need = m - 1
    printf "return: median Dk %+.4f; m_S %.4f over %d S pairs; delta = max(%.2f, m_S) = %.4f; Dk > 0 in %d of %d (pass needs %d)\n", md, mS, np, D0, delta, pos + 0, m, need
    printf "drawdown (arm medians): median maxDD P %.2f - S %.2f = %+.2f pp (limit %.1f); paired median %+.2f pp (reported, not read)\n", med(ddp, m), med(dds, m), ddiff, DDB, med(pdd, m)
    printf "concentration: trim-%d one-arm net > 0 in %d of %d (pass needs %d)\n", TR, tpos + 0, m, need
    rpass = (md >= delta && pos >= need); rfail = (md <= 0 || pos <= 2); dpass = (ddiff <= DDB); cpass = (tpos >= need)
    printf "bars: return %s, drawdown %s, concentration %s\n", rpass ? "PASS" : (rfail ? "FAIL" : "short"), dpass ? "PASS" : "FAIL", cpass ? "PASS" : "FAIL"
    if (m < 4) out = "INCONCLUSIVE (fewer than 4 valid seeds)"
    else if (live == "THIN") out = "INCONCLUSIVE (fewer than 100 Friday-pairs: liveness unreadable)"
    else if (live != "LIVE") out = "NOT LIVE"
    else if (rfail) out = "FAIL"
    else if (rpass && dpass && cpass) out = "PASS"
    else out = "INCONCLUSIVE"
    print "CELL " T " OUTCOME " out }' "${TMPDIR:-/tmp}/decide-ret.$$"
rm -f "${TMPDIR:-/tmp}/decide-ret.$$"
