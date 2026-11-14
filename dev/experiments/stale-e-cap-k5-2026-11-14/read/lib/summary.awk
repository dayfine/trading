# summary.awk -- the tables and the outcome of ../../README.md §Decision rule, from split.sh's rows:
#   V seed v6 tripwire absent                      validity per seed (ok/fail/missing; match/waived/mismatch/missing)
#   M seed arm R maxdd sharpe ulcer closed open big  per arm (R and maxdd in %, from actual.sexp)
#   K seed key cls cap capS lrtok sS sC cS cC price size exit lower rc wr fit oth faS faC unmarked near   (keys.awk)
#   W seed arm message                              warnings from keys.awk
# Variables: validity (check | skip), marked (1 when open positions carry marks).
BEGIN { FS = OFS = "\t"; ns = 0 }
function sid(s) { if (!(s in si)) { si[s] = ++ns; sname[ns] = s } return si[s] }
function med(a, n,   i, j, t, b) {   # median of a[1..n] (copied, insertion sort)
  if (n == 0) return "nan"
  for (i = 1; i <= n; i++) b[i] = a[i]
  for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
  return (n % 2) ? b[(n + 1) / 2] : (b[n / 2] + b[n / 2 + 1]) / 2
}
function q(a, n, p,   i, j, t, b, r) {   # nearest-rank quantile p of a[1..n]
  if (n == 0) return "nan"
  for (i = 1; i <= n; i++) b[i] = a[i]
  for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
  r = int(p * n + 0.999999); if (r < 1) r = 1; if (r > n) r = n; return b[r]
}
function pct(x, n) { return n > 0 ? sprintf("%.1f %%", 100 * x / n) : "n/a" }
function add(name, s, v) { tot[name, s] += v; cnt[name, s]++; if (name ~ /:/ && !(name in seen)) { seen[name] = 1; comp[++ncomp] = name } }
$1 == "W" { warn[++nw] = $2 " " $3 ": " $4; next }
$1 == "V" { s = sid($2); v6[s] = $3; trip[s] = $4; absent[s] = $5; next }
$1 == "M" { s = sid($2); a = $3; R[s, a] = $4; dd[s, a] = $5; sh[s, a] = $6; ui[s, a] = $7; ncl[s, a] = $8; nop[s, a] = $9; big[s, a] = $10; hasM[s, a] = 1; next }
$1 == "K" {
  s = sid($2); cls = $4; cap = $5; capS = $6; sS = $8; sC = $9; cS = $10 + 0; cC = $11 + 0; um = $22
  if (sC != "none") { placedC[s]++; stC[s, sC]++; if (cap == 1) { capped[s]++; capst[s, sC]++; twin[s, sS]++ } }
  if (sS != "none") { placedS[s]++; stS[s, sS]++; if (capS == 1) cappedS[s]++ }
  if ($7 == 0) lrtbad[s]++
  if ($20 != "-" && sS == "closed") { nfa["S", s]++; fa["S", s, nfa["S", s]] = $20 + 0 }
  if ($21 != "-" && sC == "closed") { nfa["C", s]++; fa["C", s, nfa["C", s]] = $21 + 0
    if (cap == 1) { nfc[s]++; fac[s, nfc[s]] = $21 + 0 } }
  if (um == 1) { unmarked[s]++; next }
  d = cC - cS; nk[s]++; kd[s, nk[s]] = d; kk[s, nk[s]] = $3 " " cls; total[s] += d
  if (cls == "MF" && cap == 1) {
    add("M", s, d); pr[s] += $12; sz[s] += $13; ex[s] += $14; lowc[s] += $15
    nwr[s]++; wrs[s, nwr[s]] = $17 + 0; rcs[s, nwr[s]] = $16 + 0
  } else if (cls == "MF") { add("M0", s, d); abs0[s] += (d < 0 ? -d : d) }
  else if (cls == "RC") { add(cap == 1 ? "RCcap" : "RC0", s, cC); add("RC:" (cap == 1 ? "capped" : "uncapped") ", S " sS, s, cC) }
  else if (cls == "RS") { add(cap == 1 ? "RScap" : "RS0", s, -cS)
    add("RS:" (cap == 1 ? "capped" : "uncapped") ", C " (sC == "cash" ? ($18 == 1 ? "cash, S's size fits" : "cash, short of S's size") : sC), s, -cS) }
  else if (cls == "RN") { add(cap == 1 ? "RNcap" : "RN0", s, 0); add("RN:" (cap == 1 ? "capped" : "uncapped") ", S " sS ", C " sC, s, 0) }
  else if (cls == "PC") { add("PC", s, cC); add("PC:" (cap == 1 ? "capped, " : "") $19, s, cC)
    if (cap == 1) add($19 ~ /^skip:(No_structural_stop|Stop_too_wide)$/ || $19 == "gate-other-seed" ? "Arec" : ($19 == "nolist" ? "Anolist" : "Aother"), s, cC) }
  else if (cls == "PS") { add("PS", s, -cS); add("PS:" $19, s, -cS); if ($19 == "skip:Insufficient_cash") add("Xcash", s, -cS) }
  if ((cls == "PC" || cls == "PS") && $23 == 1) add("shifted:" cls " (other arm placed the symbol within 28 days)", s, cls == "PC" ? cC : -cS)
  next
}
END {
  # ------------------------------------------------------------------ validity
  print "== 0. Validity (README §Decision rule 0)"
  nv = 0
  for (s = 1; s <= ns; s++) {
    ok = hasM[s, "S"] && hasM[s, "C"]
    if (validity != "skip") ok = ok && v6[s] == "ok" && (trip[s] == "match" || trip[s] == "waived") && absent[s] == "ok"
    if (cappedS[s] > 0) ok = 0
    valid[s] = ok; if (ok) { nv++; vs[nv] = s }
    printf "%s  V6 %s  tripwire %s  absent-symbols %s  S capped %d  -> %s\n", sname[s], (validity == "skip" ? "n/a" : v6[s]),
      (validity == "skip" ? "n/a" : trip[s]), (validity == "skip" ? "n/a" : absent[s]), cappedS[s], ok ? "VALID" : "LEFT OUT"
  }
  if (validity == "skip") print "(validity not checked: VALIDITY=skip, the local smoke)"
  for (i = 1; i <= nw; i++) print "warning: " warn[i]
  if (!marked) print "(no DATA_DIR: open positions are left out of every NAV-% sum below; the outcome is PROVISIONAL)"

  # ------------------------------------------------------------------ returns
  print ""; print "== 1. Per seed and arm (actual.sexp; closed trades, open positions, trades at >= +100 %)"
  printf "%-4s %-3s %12s %9s %9s %8s %8s %7s %6s %5s %5s\n", "seed", "arm", "R %", "ln(1+R)", "delta", "maxDD %", "Sharpe", "Ulcer", "closed", "open", ">=100"
  for (s = 1; s <= ns; s++) {
    lS = log(1 + R[s, "S"] / 100); lC = log(1 + R[s, "C"] / 100); dl[s] = lC - lS
    printf "%-4s %-3s %12.1f %9.4f %9s %8.2f %8.3f %7.2f %6d %5d %5d\n", sname[s], "S", R[s, "S"], lS, "", dd[s, "S"], sh[s, "S"], ui[s, "S"], ncl[s, "S"], nop[s, "S"], big[s, "S"]
    printf "%-4s %-3s %12.1f %9.4f %+9.4f %8.2f %8.3f %7.2f %6d %5d %5d\n", sname[s], "C", R[s, "C"], lC, dl[s], dd[s, "C"], sh[s, "C"], ui[s, "C"], ncl[s, "C"], nop[s, "C"], big[s, "C"]
  }

  # ------------------------------------------------------------------ liveness
  print ""; print "== 2. Liveness (README §Decision rule 1): L = C's placed long tickets anchored at local_range_top; F = capped pairs C filled lower"
  printf "%-4s %8s %8s %8s %10s %9s %9s %8s %8s\n", "seed", "C placed", "capped", "L", "S capped", "cap pairs", "C lower", "F", "lrt!=anc"
  for (s = 1; s <= ns; s++) {
    printf "%-4s %8d %8d %8s %10d %9d %9d %8s %8d\n", sname[s], placedC[s], capped[s], pct(capped[s], placedC[s]), cappedS[s], cnt["M", s], lowc[s], pct(lowc[s], cnt["M", s]), lrtbad[s]
    if (valid[s]) { Pc += placedC[s]; Cc += capped[s]; Mp += cnt["M", s]; Lw += lowc[s] }
  }
  printf "%-4s %8d %8d %8s %10s %9d %9d %8s   (valid seeds)\n", "pool", Pc, Cc, pct(Cc, Pc), "", Mp, Lw, pct(Lw, Mp)

  # ------------------------------------------------------------------ ticket outcomes
  print ""; print "== 3. Ticket outcomes per arm: placed long tickets by resolution (closed / open / refused for cash at the fill / TTL / requalification / delisted / resting at the end)"
  split("closed open cash ttl requal delisted resting", ks, " ")
  printf "%-4s %-22s %7s", "seed", "set", "placed"; for (i = 1; i <= 7; i++) printf " %8s", ks[i]; printf " %8s\n", "other"
  for (s = 1; s <= ns; s++) {
    row(s, "S, all", placedS[s], stS); row(s, "C, all", placedC[s], stC)
    row(s, "C, capped tickets", capped[s], capst); row(s, "S twins of capped", capped[s], twin)
  }
  print "(\"S twins of capped\": what S did with the same symbol on the same Friday; \"none\" = S placed no ticket, counted under other)"
  print ""; print "Fill age in weeks from placement, closed trades (p50 / p90 / share filled within 1 week):"
  for (s = 1; s <= ns; s++) {
    for (a = 1; a <= 2; a++) { arm = (a == 1) ? "S" : "C"; n = nfa[arm, s]; delete tmp; c1 = 0
      for (i = 1; i <= n; i++) { tmp[i] = fa[arm, s, i]; if (tmp[i] <= 1) c1++ }
      printf "%s %s all: %s / %s / %s   ", sname[s], arm, q(tmp, n, 0.5), q(tmp, n, 0.9), pct(c1, n) }
    n = nfc[s]; delete tmp; c1 = 0; for (i = 1; i <= n; i++) { tmp[i] = fac[s, i]; if (tmp[i] <= 1) c1++ }
    printf "C capped: %s / %s / %s\n", q(tmp, n, 0.5), q(tmp, n, 0.9), pct(c1, n)
  }

  # ------------------------------------------------------------------ the split
  print ""; print "== 4. The price/size split, NAV-% of the arm's NAV at the decision (README §The price/size split)"
  printf "%-4s %5s %8s %8s %8s %8s | %5s %8s | %5s %8s | %8s | %5s %8s %8s | %8s %8s %8s %8s\n", "seed", "n M", "price", "size", "exit", "M", "n RC", "RC cap", "n RS", "RS cap", "D", "n M0", "M0", "|d| M0", "PC", "PS", "total", "trim3"
  for (s = 1; s <= ns; s++) {
    D[s] = tot["M", s] + tot["RCcap", s] + tot["RScap", s]
    trim[s] = trimmed(s)
    printf "%-4s %5d %+8.2f %+8.2f %+8.2f %+8.2f | %5d %+8.2f | %5d %+8.2f | %+8.2f | %5d %+8.2f %8.3f | %+8.2f %+8.2f %+8.2f %+8.2f\n", sname[s],
      cnt["M", s], pr[s], sz[s], ex[s], tot["M", s], cnt["RCcap", s], tot["RCcap", s], cnt["RScap", s], tot["RScap", s], D[s],
      cnt["M0", s], tot["M0", s], (cnt["M0", s] ? abs0[s] / cnt["M0", s] : 0), tot["PC", s], tot["PS", s], total[s], trim[s]
  }
  print "M = price + size + exit over capped keys both arms filled; RC cap = capped keys only C filled (+cC); RS cap = capped keys only S filled (-cS);"
  print "D = M + RC cap + RS cap (the same-ticket effect: keys both arms placed, C capped); M0 = the same-ticket path null (uncapped, both filled);"
  print "PC / PS = keys placed in one arm only (admissions and path); total = sum over all keys of cC - cS; trim3 = total without the 3 largest and 3 smallest keys."
  print ""; print "Screen comparison (#3594 sizing.txt: screen price = this price + exit, as its exits were fixed; screen size = this size):"
  split("+3.9 +4.4 +2.7 +6.5 +6.1", scp, " "); split("+7.7 +3.0 +4.1 +5.5 +3.6", scz, " ")
  for (s = 1; s <= ns; s++) { j = substr(sname[s], 2) + 1
    printf "%s  price+exit %+7.2f (screen %s)  size %+7.2f (screen %s)  size share of M %s  C/S weight on capped pairs p50 %s p90 %s  C/S fill p50 %s\n",
      sname[s], pr[s] + ex[s], scp[j], sz[s], scz[j], (tot["M", s] != 0 ? sprintf("%.0f %%", 100 * sz[s] / tot["M", s]) : "n/a"),
      wq(s, 0.5), wq(s, 0.9), rq(s, 0.5) }
  print ""; print "Admission and displacement (README §The admission channel): capped tickets only C placed, by what S did that Friday,"
  print "and S's tickets that C skipped for cash (n tickets, NAV-% summed; an unfilled ticket counts 0):"
  printf "%-4s %16s %16s %16s %16s | %16s\n", "seed", "A gate (rec.)", "A no S list", "A other", "A all", "displaced (cash)"
  for (s = 1; s <= ns; s++) {
    na = cnt["Arec", s] + cnt["Anolist", s] + cnt["Aother", s]; ta = tot["Arec", s] + tot["Anolist", s] + tot["Aother", s]
    printf "%-4s %5d %+10.2f %5d %+10.2f %5d %+10.2f %5d %+10.2f | %5d %+10.2f\n", sname[s], cnt["Arec", s], tot["Arec", s],
      cnt["Anolist", s], tot["Anolist", s], cnt["Aother", s], tot["Aother", s], na, ta, cnt["Xcash", s], tot["Xcash", s] }
  print ""; print "Components by outcome (n, NAV-% summed):"
  sortcomp()
  for (s = 1; s <= ns; s++) for (i = 1; i <= ncomp; i++) if ((comp[i], s) in cnt)
      printf "%s  %-48s %5d %+9.2f\n", sname[s], comp[i], cnt[comp[i], s], tot[comp[i], s]
  if (ns > 0) { print ""; print "Largest key-level differences per seed (cC - cS, NAV-%; key class):" }
  for (s = 1; s <= ns; s++) top(s)

  # ------------------------------------------------------------------ decision
  decide()
}
function row(s, label, n, arr,   i, o) {
  printf "%-4s %-22s %7d", sname[s], label, n; o = n
  for (i = 1; i <= 7; i++) { printf " %8d", arr[s, ks[i]]; o -= arr[s, ks[i]] }
  printf " %8d\n", o
}
function trimmed(s,   i, j, t, n, b, sum) {   # total without the 3 largest and 3 smallest key differences
  n = nk[s]; for (i = 1; i <= n; i++) b[i] = kd[s, i]
  for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
  sum = 0; for (i = 4; i <= n - 3; i++) sum += b[i]; return sum
}
function wq(s, p,   i, b) { for (i = 1; i <= nwr[s]; i++) b[i] = wrs[s, i]; return nwr[s] ? sprintf("%.3f", q(b, nwr[s], p)) : "n/a" }
function rq(s, p,   i, b) { for (i = 1; i <= nwr[s]; i++) b[i] = rcs[s, i]; return nwr[s] ? sprintf("%.4f", q(b, nwr[s], p)) : "n/a" }
function top(s,   i, j, n, used, best, bi, line) {   # the 3 largest positive and 3 largest negative key differences
  line = sname[s] " +:"
  for (j = 1; j <= 3; j++) { best = 0; bi = 0; for (i = 1; i <= nk[s]; i++) if (!(i in used) && kd[s, i] > best) { best = kd[s, i]; bi = i }
    if (bi) { used[bi] = 1; line = line sprintf("  %s %+.2f", kk[s, bi], best) } }
  line = line "   -:"
  for (j = 1; j <= 3; j++) { best = 0; bi = 0; for (i = 1; i <= nk[s]; i++) if (!(i in used) && kd[s, i] < best) { best = kd[s, i]; bi = i }
    if (bi) { used[bi] = 1; line = line sprintf("  %s %+.2f", kk[s, bi], best) } }
  print line
}
function decide(   i, j, s, n, a, b, mS, delta, need, pos, neg, Dp, Tp, mdd, L, F, out, why, lc, lsS) {
  print ""; print "== 5. Outcome (README §Decision rule, applied as written)"
  n = nv
  for (i = 1; i <= n; i++) { s = vs[i]; a[i] = dl[s]; if (dl[s] > 0) pos++; if (dl[s] < 0) neg++; if (D[s] > 0) Dp++; if (trim[s] > 0) Tp++
    ddS[i] = dd[s, "S"]; ddC[i] = dd[s, "C"]; lsS[i] = log(1 + R[s, "S"] / 100) }
  j = 0; for (i = 1; i <= n; i++) for (k2 = i + 1; k2 <= n; k2++) { j++; b[j] = lsS[i] - lsS[k2]; if (b[j] < 0) b[j] = -b[j] }
  mS = med(b, j); delta = (mS != "nan" && mS > 0.20) ? mS : 0.20
  need = n - 1
  mdd = (n > 0) ? med(ddC, n) - med(ddS, n) : "nan"
  L = (Pc > 0) ? Cc / Pc : 0; F = (Mp > 0) ? Lw / Mp : 0
  printf "valid seeds %d; L %.4f (bar 0.10); F %.4f over %d capped pairs (bar 0.50, >= 30 pairs)\n", n, L, F, Mp
  if (n > 0) printf "median delta %+.4f; delta > 0 in %d, < 0 in %d of %d; delta bar %.4f (max(0.20, m_S = %s)); D > 0 in %d; trim3 > 0 in %d; maxDD median C - S %+.2f pp\n",
    med(a, n), pos, neg, n, delta, (mS == "nan" ? "n/a" : sprintf("%.4f", mS)), Dp, Tp, mdd
  if (n < 4) { out = "INCONCLUSIVE"; why = "fewer than 4 valid seeds" }
  else if (L < 0.10) { out = "NOT LIVE"; why = "L below 0.10" }
  else if (Mp < 30) { out = "INCONCLUSIVE"; why = "F unreadable: fewer than 30 capped pairs both arms filled" }
  else if (F < 0.50) { out = "NOT LIVE"; why = "F below 0.50" }
  else {
    m = med(a, n)
    if ((Dp <= 1 && m < delta) || (m <= -delta && neg >= need)) { out = "NO-BUILD"; why = (Dp <= 1 && m < delta) ? "D > 0 in at most one seed" : "median delta <= -bar with delta < 0 in all but one seed" }
    else if (m >= delta && pos >= need && mdd <= 3.0 && Tp >= need) { out = "ESCALATE"; why = "the pass, drawdown and concentration bars hold" }
    else if (Dp >= need && m > -delta && m < delta) { out = "KEEP-AXIS"; why = "D > 0 in all but at most one seed, median delta inside the band" }
    else { out = "INCONCLUSIVE"; why = "no clause set holds in full" }
  }
  printf "OUTCOME: %s (%s)%s\n", out, why, (marked ? "" : "  PROVISIONAL: open positions not marked")
  for (i = 1; i <= ns; i++) printf "SEED %s delta %+.4f L %s F %s D %+.2f M %+.2f price %+.2f size %+.2f exit %+.2f total %+.2f\n", sname[i], dl[i],
    pct(capped[i], placedC[i]), pct(lowc[i], cnt["M", i]), D[i], tot["M", i], pr[i], sz[i], ex[i], total[i]
}
function sortcomp(   i, j, t) {   # component names in a fixed order, whatever the input order
  for (i = 2; i <= ncomp; i++) { t = comp[i]; for (j = i - 1; j >= 1 && comp[j] > t; j--) comp[j + 1] = comp[j]; comp[j + 1] = t }
}
