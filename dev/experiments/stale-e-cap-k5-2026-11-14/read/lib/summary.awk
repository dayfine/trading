# summary.awk -- the tables and the outcome of one arm pair (../../README.md §Decision rule, §Arm G), from split.sh's
# rows. The pair's base arm takes the role the README calls S and its test arm the role it calls C (keys.awk's roles):
#   V seed v6 tripwire absent                         validity per seed (ok/fail/missing; match/waived/mismatch/missing)
#   M seed role R maxdd sharpe ulcer closed open big  per arm, role S = base, C = test (R and maxdd in %, actual.sexp)
#   N seed R                                          arm S's own R (%), for delta's reshuffle null m_S
#   GC seeds pooled own premise cpooled               the G check (split.sh; README §Arm G), when arm G has tickets
#   K seed key cls cap capS lrtok sS sC cS cC price size exit lower rc wr fit oth faS faC unmarked near   (keys.awk)
#   W seed arm message                                warnings from keys.awk
# Variables: base, test (the arms' letters), validity (check | skip), marked (1 when open positions carry marks).
# With base S the pair gets the full rule (§Decision rule; for test G, §Arm G "G vs S"); with another base (G:C) it
# gets the report of §Arm G "C vs G" and no outcome of its own. Every pair ends with one machine line, RULE, that
# combine.awk reads.
BEGIN { FS = OFS = "\t"; ns = 0; full = (base == "S"); gin = (base == "G" || test == "G"); gbad = -1 }
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
$1 == "N" { s = sid($2); RS0[s] = $3; next }
$1 == "GC" { gseeds = $2; gpool = $3; gown = $4; gprem = $5; gcpool = $6
  gbad = (gprem == 0) ? gpool : gown; next }   # the pooled record unless the premise fails (README §Arm G)
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
  else if (cls == "RC") { add(cap == 1 ? "RCcap" : "RC0", s, cC); add("RC:" (cap == 1 ? "capped" : "uncapped") ", " base " " sS, s, cC) }
  else if (cls == "RS") { add(cap == 1 ? "RScap" : "RS0", s, -cS)
    add("RS:" (cap == 1 ? "capped" : "uncapped") ", " test " " (sC == "cash" ? ($18 == 1 ? "cash, " base "'s size fits" : "cash, short of " base "'s size") : sC), s, -cS) }
  else if (cls == "RN") { add(cap == 1 ? "RNcap" : "RN0", s, 0); add("RN:" (cap == 1 ? "capped" : "uncapped") ", " base " " sS ", " test " " sC, s, 0) }
  else if (cls == "PC") { add("PC", s, cC); add("PC:" (cap == 1 ? "capped, " : "") $19, s, cC)
    if (cap == 1) { add($19 ~ /^skip:(No_structural_stop|Stop_too_wide)$/ || $19 == "gate-other-seed" ? "Arec" : ($19 == "nolist" ? "Anolist" : "Aother"), s, cC)
      nav[s]++; av[s, nav[s]] = cC } }
  else if (cls == "PS") { add("PS", s, -cS); add("PS:" $19, s, -cS); if ($19 == "skip:Insufficient_cash") add("Xcash", s, -cS) }
  if ((cls == "PC" || cls == "PS") && $23 == 1) add("shifted:" cls " (other arm placed the symbol within 28 days)", s, cls == "PC" ? cC : -cS)
  next
}
END {
  # ------------------------------------------------------------------ validity
  print "== 0. Validity (README §Decision rule 0" (gin ? "; §Arm G, the G check" : "") ")"
  if (gin) {
    if (gbad < 0) print "G check: no arm-G tickets found -> G INVALID"
    else printf "G check (README §Arm G): G's capped tickets on a key S skipped at the stop gate: pooled S record %d, own seed's S record %d, over %d seeds (bar 0); premise, S's own tickets on a pooled gate key: %d (0 expected); C's capped tickets on a pooled gate key: %d -> %s\n",
      gpool, gown, gseeds, gprem, gcpool, (gbad == 0 ? "PASS" : "FAIL: G INVALID") (gprem == 0 ? "" : " (premise failed: the own-seed count is used)")
  }
  nv = 0
  for (s = 1; s <= ns; s++) {
    ok = hasM[s, "S"] && hasM[s, "C"] && (s in RS0)
    if (validity != "skip") ok = ok && v6[s] == "ok" && (trip[s] == "match" || trip[s] == "waived") && absent[s] == "ok"
    if (full && cappedS[s] > 0) ok = 0                # arm S is the control: it caps nothing
    if (gin && gbad != 0) ok = 0                      # a failed G check leaves G out of every read
    valid[s] = ok; if (ok) { nv++; vs[nv] = s }
    printf "%s  V6 %s  tripwire %s  absent-symbols %s  %s capped %d  -> %s\n", sname[s], (validity == "skip" ? "n/a" : v6[s]),
      (validity == "skip" ? "n/a" : trip[s]), (validity == "skip" ? "n/a" : absent[s]), base, cappedS[s], ok ? "VALID" : "LEFT OUT"
  }
  if (validity == "skip") print "(validity not checked: VALIDITY=skip, the local smoke)"
  if (!full) printf "(%s is not the control: its capped tickets are expected and do not count against validity)\n", base
  for (i = 1; i <= nw; i++) print "warning: " warn[i]
  if (!marked) print "(no DATA_DIR: open positions are left out of every NAV-% sum below; the outcome is PROVISIONAL)"

  # ------------------------------------------------------------------ returns
  print ""; printf "== 1. Per seed and arm (actual.sexp; closed trades, open positions, trades at >= +100 %%); delta = %s - %s\n", test, base
  printf "%-4s %-3s %12s %9s %9s %8s %8s %7s %6s %5s %5s\n", "seed", "arm", "R %", "ln(1+R)", "delta", "maxDD %", "Sharpe", "Ulcer", "closed", "open", ">=100"
  for (s = 1; s <= ns; s++) {
    lS = log(1 + R[s, "S"] / 100); lC = log(1 + R[s, "C"] / 100); dl[s] = lC - lS
    printf "%-4s %-3s %12.1f %9.4f %9s %8.2f %8.3f %7.2f %6d %5d %5d\n", sname[s], base, R[s, "S"], lS, "", dd[s, "S"], sh[s, "S"], ui[s, "S"], ncl[s, "S"], nop[s, "S"], big[s, "S"]
    printf "%-4s %-3s %12.1f %9.4f %+9.4f %8.2f %8.3f %7.2f %6d %5d %5d\n", sname[s], test, R[s, "C"], lC, dl[s], dd[s, "C"], sh[s, "C"], ui[s, "C"], ncl[s, "C"], nop[s, "C"], big[s, "C"]
  }

  # ------------------------------------------------------------------ liveness
  print ""; printf "== 2. Liveness (README §Decision rule 1): L = %s's placed long tickets anchored at local_range_top; F = capped pairs %s filled lower\n", test, test
  printf "%-4s %8s %8s %8s %10s %9s %9s %8s %8s\n", "seed", test " placed", "capped", "L", base " capped", "cap pairs", test " lower", "F", "lrt!=anc"
  for (s = 1; s <= ns; s++) {
    printf "%-4s %8d %8d %8s %10d %9d %9d %8s %8d\n", sname[s], placedC[s], capped[s], pct(capped[s], placedC[s]), cappedS[s], cnt["M", s], lowc[s], pct(lowc[s], cnt["M", s]), lrtbad[s]
    if (valid[s]) { Pc += placedC[s]; Cc += capped[s]; Mp += cnt["M", s]; Lw += lowc[s] }
  }
  printf "%-4s %8d %8d %8s %10s %9d %9d %8s   (valid seeds)\n", "pool", Pc, Cc, pct(Cc, Pc), "", Mp, Lw, pct(Lw, Mp)
  if (!full) printf "(both arms cap: \"cap pairs\" are keys both filled where %s's ticket is capped, mostly the same ticket in both arms)\n", test

  # ------------------------------------------------------------------ ticket outcomes
  print ""; print "== 3. Ticket outcomes per arm: placed long tickets by resolution (closed / open / refused for cash at the fill / TTL / requalification / delisted / resting at the end)"
  split("closed open cash ttl requal delisted resting", ks, " ")
  printf "%-4s %-22s %7s", "seed", "set", "placed"; for (i = 1; i <= 7; i++) printf " %8s", ks[i]; printf " %8s\n", "other"
  for (s = 1; s <= ns; s++) {
    row(s, base ", all", placedS[s], stS); row(s, test ", all", placedC[s], stC)
    row(s, test ", capped tickets", capped[s], capst); row(s, base " twins of capped", capped[s], twin)
  }
  printf "(\"%s twins of capped\": what %s did with the same symbol on the same Friday; \"none\" = %s placed no ticket, counted under other)\n", base, base, base
  print ""; print "Fill age in weeks from placement, closed trades (p50 / p90 / share filled within 1 week):"
  for (s = 1; s <= ns; s++) {
    for (a = 1; a <= 2; a++) { arm = (a == 1) ? "S" : "C"; n = nfa[arm, s]; delete tmp; c1 = 0
      for (i = 1; i <= n; i++) { tmp[i] = fa[arm, s, i]; if (tmp[i] <= 1) c1++ }
      printf "%s %s all: %s / %s / %s   ", sname[s], (a == 1 ? base : test), q(tmp, n, 0.5), q(tmp, n, 0.9), pct(c1, n) }
    n = nfc[s]; delete tmp; c1 = 0; for (i = 1; i <= n; i++) { tmp[i] = fac[s, i]; if (tmp[i] <= 1) c1++ }
    printf "%s capped: %s / %s / %s\n", test, q(tmp, n, 0.5), q(tmp, n, 0.9), pct(c1, n)
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
  printf "M = price + size + exit over capped keys both arms filled; RC cap = capped keys only %s filled (+c%s); RS cap = capped keys only %s filled (-c%s);\n", test, test, base, base
  printf "D = M + RC cap + RS cap (the same-ticket effect: keys both arms placed, %s capped); M0 = the same-ticket path null (uncapped, both filled);\n", test
  print "PC / PS = keys placed in one arm only (admissions and path); total = sum over all keys of c_test - c_base; trim3 = total without the 3 largest and 3 smallest keys."
  if (full) {
    print ""; print "Screen comparison (#3594 sizing.txt: screen price = this price + exit, as its exits were fixed; screen size = this size):"
    split("+3.9 +4.4 +2.7 +6.5 +6.1", scp, " "); split("+7.7 +3.0 +4.1 +5.5 +3.6", scz, " ")
    for (s = 1; s <= ns; s++) { j = substr(sname[s], 2) + 1
      printf "%s  price+exit %+7.2f (screen %s)  size %+7.2f (screen %s)  size share of M %s  %s/%s weight on capped pairs p50 %s p90 %s  %s/%s fill p50 %s\n",
        sname[s], pr[s] + ex[s], scp[j], sz[s], scz[j], (tot["M", s] != 0 ? sprintf("%.0f %%", 100 * sz[s] / tot["M", s]) : "n/a"),
        test, base, wq(s, 0.5), wq(s, 0.9), test, base, rq(s, 0.5) }
  }
  print ""; printf "Admission and displacement (README §The admission channel): capped tickets only %s placed, by what %s did that Friday,\n", test, base
  printf "and %s's tickets that %s skipped for cash (n tickets, NAV-%% summed; an unfilled ticket counts 0):\n", base, test
  printf "%-4s %16s %16s %16s %16s %10s | %16s\n", "seed", "A gate (rec.)", "A no " base " list", "A other", "A all", "A w/o top3", "displaced (cash)"
  for (s = 1; s <= ns; s++) {
    na = cnt["Arec", s] + cnt["Anolist", s] + cnt["Aother", s]; ta = tot["Arec", s] + tot["Anolist", s] + tot["Aother", s]
    printf "%-4s %5d %+10.2f %5d %+10.2f %5d %+10.2f %5d %+10.2f %+10.2f | %5d %+10.2f\n", sname[s], cnt["Arec", s], tot["Arec", s],
      cnt["Anolist", s], tot["Anolist", s], cnt["Aother", s], tot["Aother", s], na, ta, atrim(s), cnt["Xcash", s], tot["Xcash", s] }
  print "(A w/o top3 = the A total without its 3 largest keys; README §Arm G, the ADMISSIONS row)"
  print ""; print "Components by outcome (n, NAV-% summed):"
  sortcomp()
  for (s = 1; s <= ns; s++) for (i = 1; i <= ncomp; i++) if ((comp[i], s) in cnt)
      printf "%s  %-48s %5d %+9.2f\n", sname[s], comp[i], cnt[comp[i], s], tot[comp[i], s]
  if (ns > 0) { print ""; printf "Largest key-level differences per seed (c_%s - c_%s, NAV-%%; key class):\n", test, base }
  for (s = 1; s <= ns; s++) top(s)

  # ------------------------------------------------------------------ decision
  if (full) decide(); else report()
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
function atrim(s,   i, j, t, n, b, sum) {   # the admissions' total (A, all classes) without its 3 largest keys
  n = nav[s]; for (i = 1; i <= n; i++) b[i] = av[s, i]
  for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
  sum = 0; for (i = 1; i <= n - 3; i++) sum += b[i]; return sum
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
# The common quantities over the valid seeds: delta median and signs, delta's bar from arm S's own returns, D and trim3
# signs, and the drawdown gap. Sets globals n, m, pos, neg, Dp, Tp, mS, bar, mdd, need.
function stats(   i, j, k2, s, a, b, ddS, ddC, lsS) {
  n = nv; pos = 0; neg = 0; Dp = 0; Tp = 0
  for (i = 1; i <= n; i++) { s = vs[i]; a[i] = dl[s]; if (dl[s] > 0) pos++; if (dl[s] < 0) neg++; if (D[s] > 0) Dp++; if (trim[s] > 0) Tp++
    ddS[i] = dd[s, "S"]; ddC[i] = dd[s, "C"]; lsS[i] = log(1 + RS0[s] / 100) }
  j = 0; for (i = 1; i <= n; i++) for (k2 = i + 1; k2 <= n; k2++) { j++; b[j] = lsS[i] - lsS[k2]; if (b[j] < 0) b[j] = -b[j] }
  mS = med(b, j); bar = (mS != "nan" && mS > 0.20) ? mS : 0.20
  need = n - 1; m = med(a, n)
  mdd = (n > 0) ? med(ddC, n) - med(ddS, n) : "nan"
}
function decide(   L, F, out, why, tag, Ale0) {
  print ""; printf "== 5. Outcome, %s vs %s (README §Decision rule, applied as written%s)\n", test, base, (test == "G" ? "; §Arm G \"G vs S\"" : "")
  stats()
  Ale0 = 0; for (i = 1; i <= n; i++) if (atrim(vs[i]) <= 0) Ale0++
  L = (Pc > 0) ? Cc / Pc : 0; F = (Mp > 0) ? Lw / Mp : 0
  printf "valid seeds %d; L %.4f (bar 0.10); F %.4f over %d capped pairs (bar 0.50, >= 30 pairs)\n", n, L, F, Mp
  if (n > 0) printf "median delta %+.4f; delta > 0 in %d, < 0 in %d of %d; delta bar %.4f (max(0.20, m_S = %s)); D > 0 in %d; trim3 > 0 in %d; maxDD median %s - %s %+.2f pp\n",
    m, pos, neg, n, bar, (mS == "nan" ? "n/a" : sprintf("%.4f", mS)), Dp, Tp, test, base, mdd
  if (gin && gbad != 0) { out = "INCONCLUSIVE"; why = "G INVALID: the G check failed or found no G tickets" }
  else if (n < 4) { out = "INCONCLUSIVE"; why = "fewer than 4 valid seeds" }
  else if (L < 0.10) { out = "NOT LIVE"; why = "L below 0.10" }
  else if (Mp < 30) { out = "INCONCLUSIVE"; why = "F unreadable: fewer than 30 capped pairs both arms filled" }
  else if (F < 0.50) { out = "NOT LIVE"; why = "F below 0.50" }
  else {
    if ((Dp <= 1 && m < bar) || (m <= -bar && neg >= need)) { out = "NO-BUILD"; why = (Dp <= 1 && m < bar) ? "D > 0 in at most one seed" : "median delta <= -bar with delta < 0 in all but one seed" }
    else if (m >= bar && pos >= need && mdd <= 3.0 && Tp >= need) { out = "ESCALATE"; why = "the pass, drawdown and concentration bars hold" }
    else if (Dp >= need && m > -bar && m < bar) { out = "KEEP-AXIS"; why = "D > 0 in all but at most one seed, median delta inside the band" }
    else { out = "INCONCLUSIVE"; why = "no clause set holds in full" }
  }
  printf "OUTCOME %s vs %s: %s (%s)%s\n", test, base, out, why, (marked ? "" : "  PROVISIONAL: open positions not marked")
  for (i = 1; i <= ns; i++) printf "SEED %s %s-%s delta %+.4f L %s F %s D %+.2f M %+.2f price %+.2f size %+.2f exit %+.2f total %+.2f\n", sname[i], test, base, dl[i],
    pct(capped[i], placedC[i]), pct(lowc[i], cnt["M", i]), D[i], tot["M", i], pr[i], sz[i], ex[i], total[i]
  tag = out; gsub(/ /, "_", tag)
  printf "RULE %s,%s %s n=%d median=%s pos=%d neg=%d delta=%.4f Dp=%d Tp=%d mdd=%s L=%.4f F=%.4f Mp=%d Ale0=%d gbad=%d marked=%d\n", base, test, tag, n,
    (n ? sprintf("%.4f", m) : "nan"), pos, neg, bar, Dp, Tp, (n ? sprintf("%.2f", mdd) : "nan"), L, F, Mp, Ale0, (gin ? gbad : 0), marked
}
# C vs G (README §Arm G): the admissions effect, reported; it names a channel in the combined outcome and never decides
# a build on its own. Pooled A and displacement sums over the valid seeds.
function report(   i, s, nA, tA, a1, a2, a3, x) {
  print ""; printf "== 5. Report, %s vs %s (README §Arm G \"C vs G\": attribution only, no outcome of its own)\n", test, base
  stats()
  for (i = 1; i <= n; i++) { s = vs[i]; a1 += tot["Arec", s]; a2 += tot["Anolist", s]; a3 += tot["Aother", s]; x += tot["Xcash", s]
    nA += cnt["Arec", s] + cnt["Anolist", s] + cnt["Aother", s] }
  tA = a1 + a2 + a3
  printf "valid seeds %d; median delta_%s%s %s; delta > 0 in %d, < 0 in %d; the bar %.4f (max(0.20, m_S = %s))\n", n, test, base,
    (n ? sprintf("%+.4f", m) : "n/a"), pos, neg, bar, (mS == "nan" ? "n/a" : sprintf("%.4f", mS))
  printf "admissions pooled (capped %s tickets on keys %s did not place): %d tickets, NAV-%% A gate (rec.) %+.2f, A no %s list %+.2f, A other %+.2f, A all %+.2f; displaced (cash) %+.2f\n",
    test, base, nA, a1, base, a2, a3, tA, x
  for (i = 1; i <= ns; i++) printf "SEED %s %s-%s delta %+.4f A all %+.2f displaced %+.2f total %+.2f\n", sname[i], test, base, dl[i],
    tot["Arec", i] + tot["Anolist", i] + tot["Aother", i], tot["Xcash", i], total[i]
  printf "RULE %s,%s REPORT n=%d median=%s pos=%d neg=%d delta=%.4f arec=%.2f anolist=%.2f aother=%.2f aall=%.2f xcash=%.2f gbad=%d marked=%d\n",
    base, test, n, (n ? sprintf("%.4f", m) : "nan"), pos, neg, bar, a1, a2, a3, tA, x, (gin ? gbad : 0), marked
}
function sortcomp(   i, j, t) {   # component names in a fixed order, whatever the input order
  for (i = 2; i <= ncomp; i++) { t = comp[i]; for (j = i - 1; j >= 1 && comp[j] > t; j--) comp[j + 1] = comp[j]; comp[j + 1] = t }
}
