# summary.awk -- the tables and the outcome of one arm pair (../../README.md §Decision rule, §Arm G), from split.sh's
# rows. The pair's base arm takes the role the README calls S and its test arm the role it calls C (keys.awk's roles):
#   V seed v6 tripwire absent                         validity per seed (ok/fail/missing; match/waived/mismatch/missing)
#   M seed role R maxdd sharpe ulcer closed open big  per arm, role S = base, C = test (R and maxdd in %, actual.sexp)
#   N seed R                                          arm S's own R (%), for delta's reshuffle null m_S
#   GC seeds pooled own premise cpooled               the G check (split.sh; README §Arm G), when arm G has tickets
#   K seed key cls cap capS lrtok sS sC cS cC price size exit lower rc wr fit oth faS faC unmarked near openleg   (keys.awk)
#   W seed arm message                                warnings from keys.awk
# Variables: base, test (the arms' letters), validity (check | skip), marked (1 when DATA_DIR was given).
# With base S the pair gets the full rule (§Decision rule; for test G, §Arm G "G vs S"); with another base (G:C) it
# gets the report of §Arm G "C vs G" and no outcome of its own. Every pair ends with one machine line, RULE, that
# combine.awk reads.
#
# Open-leg keys (README §What the read prints): a key whose ticket either arm still holds open at the window end has a
# contribution that depends on a mark from the bar store. No sum printed below includes such a key: every sum is over the
# other keys (closed legs: the simulator's own figures), and each table prints how many open-leg keys it left out. The
# outcome's bars (D, trim3, A without its 3 largest) are read on the marked values and only their pass or fail is printed.
# A key with an open leg that has no mark (no DATA_DIR, or no bar file) is in neither: it is counted, and the outcome is
# PROVISIONAL.
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
# ms: 0 = closed legs only (counted and summed), 1 = an open leg with a mark, 2 = an open leg without one. Only ms 0
# reaches tot (the printed sum); ms 1 reaches tmd (the full value the bars read); lo counts both, ms 2 included.
function add(name, s, v, ms) {
  if (ms == 0) { tot[name, s] += v; cnt[name, s]++ } else { lo[name, s]++; if (ms == 1) tmd[name, s] += v }
  if (name ~ /:/ && !(name in seen)) { seen[name] = 1; comp[++ncomp] = name }
  known[name, s] = 1
}
function fsum(name, s) { return tot[name, s] + tmd[name, s] }   # the full marked value, for the bars only
$1 == "W" { warn[++nw] = $2 " " $3 ": " $4; next }
$1 == "V" { s = sid($2); v6[s] = $3; trip[s] = $4; absent[s] = $5; next }
$1 == "M" { s = sid($2); a = $3; R[s, a] = $4; dd[s, a] = $5; sh[s, a] = $6; ui[s, a] = $7; ncl[s, a] = $8; nop[s, a] = $9; big[s, a] = $10; hasM[s, a] = 1; next }
$1 == "N" { s = sid($2); RS0[s] = $3; next }
$1 == "GC" { gseeds = $2; gpool = $3; gown = $4; gprem = $5; gcpool = $6
  gbad = (gprem == 0) ? gpool : gown; next }   # the pooled record unless the premise fails (README §Arm G)
$1 == "K" {
  s = sid($2); key = $3; cls = $4; cap = $5; capS = $6; sS = $8; sC = $9; cS = $10 + 0; cC = $11 + 0
  ms = ($22 == 1) ? 2 : (($24 == 1) ? 1 : 0)
  yr = substr(key, index(key, "|") + 1, 4); yrs[yr] = 1
  if (sC != "none") { placedC[s]++; stC[s, sC]++; if (cap == 1) { capped[s]++; capst[s, sC]++; twin[s, sS]++ } }
  if (sS != "none") { placedS[s]++; stS[s, sS]++; if (capS == 1) cappedS[s]++ }
  if ($7 == 0) lrtbad[s]++
  if ($20 != "-" && sS == "closed") { nfa["S", s]++; fa["S", s, nfa["S", s]] = $20 + 0 }
  if ($21 != "-" && sC == "closed") { nfa["C", s]++; fa["C", s, nfa["C", s]] = $21 + 0
    if (cap == 1) { nfc[s]++; fac[s, nfc[s]] = $21 + 0 } }
  # F and the weights read entry prices and share counts, never a mark: every capped both-filled key counts.
  if (cls == "MF" && cap == 1) { nM[s]++; lowc[s] += $15; nwr[s]++; wrs[s, nwr[s]] = $17 + 0; rcs[s, nwr[s]] = $16 + 0 }
  d = cC - cS
  if (ms) { nmd[s]++ }
  if (ms == 2) unmarked[s]++
  if (ms < 2) { nkf[s]++; kdf[s, nkf[s]] = d }          # the full list, for the bars
  if (ms == 0) { nkc[s]++; kdc[s, nkc[s]] = d; kkc[s, nkc[s]] = key " " cls; total[s] += d }
  isD = 0; isM0 = 0; isA = 0; dv = 0
  if (cls == "MF" && cap == 1) {
    add("M", s, d, ms); isD = 1; dv = d
    if (ms == 0) { pr[s] += $12; sz[s] += $13; ex[s] += $14 }
  } else if (cls == "MF") { add("M0", s, d, ms); isM0 = 1; if (ms == 0) abs0[s] += (d < 0 ? -d : d) }
  else if (cls == "RC") { add(cap == 1 ? "RCcap" : "RC0", s, cC, ms); add("RC:" (cap == 1 ? "capped" : "uncapped") ", " base " " sS, s, cC, ms)
    if (cap == 1) { isD = 1; dv = cC } }
  else if (cls == "RS") { add(cap == 1 ? "RScap" : "RS0", s, -cS, ms)
    add("RS:" (cap == 1 ? "capped" : "uncapped") ", " test " " (sC == "cash" ? ($18 == 1 ? "cash, " base "'s size fits" : "cash, short of " base "'s size") : sC), s, -cS, ms)
    if (cap == 1) { isD = 1; dv = -cS } }
  else if (cls == "RN") { add(cap == 1 ? "RNcap" : "RN0", s, 0, ms); add("RN:" (cap == 1 ? "capped" : "uncapped") ", " base " " sS ", " test " " sC, s, 0, ms) }
  else if (cls == "PC") { add("PC", s, cC, ms); add("PC:" (cap == 1 ? "capped, " : "") $19, s, cC, ms)
    if (cap == 1) { add($19 ~ /^skip:(No_structural_stop|Stop_too_wide)$/ || $19 == "gate-other-seed" ? "Arec" : ($19 == "nolist" ? "Anolist" : "Aother"), s, cC, ms)
      isA = 1; if (ms < 2) { navf[s]++; avf[s, navf[s]] = cC }
      if (ms == 0) { navc[s]++; avc[s, navc[s]] = cC } } }
  else if (cls == "PS") { add("PS", s, -cS, ms); add("PS:" $19, s, -cS, ms); if ($19 == "skip:Insufficient_cash") add("Xcash", s, -cS, ms) }
  if ((cls == "PC" || cls == "PS") && $23 == 1) add("shifted:" cls " (other arm placed the symbol within 28 days)", s, cls == "PC" ? cC : -cS, ms)
  if (ms == 0) { yn[s, yr]++; yT[s, yr] += d; if (isD) yD[s, yr] += dv; if (isM0) yM0[s, yr] += d; if (isA) { ynA[s, yr]++; yA[s, yr] += cC } }
  else ylo[s, yr]++
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
  nv = 0; unmk = 0
  for (s = 1; s <= ns; s++) {
    ok = hasM[s, "S"] && hasM[s, "C"] && (s in RS0)
    if (validity != "skip") ok = ok && v6[s] == "ok" && (trip[s] == "match" || trip[s] == "waived") && absent[s] == "ok"
    if (full && cappedS[s] > 0) ok = 0                # arm S is the control: it caps nothing
    if (gin && gbad != 0) ok = 0                      # a failed G check leaves G out of every read
    valid[s] = ok; if (ok) { nv++; vs[nv] = s; unmk += unmarked[s] }
    printf "%s  V6 %s  tripwire %s  absent-symbols %s  %s capped %d  -> %s\n", sname[s], (validity == "skip" ? "n/a" : v6[s]),
      (validity == "skip" ? "n/a" : trip[s]), (validity == "skip" ? "n/a" : absent[s]), base, cappedS[s], ok ? "VALID" : "LEFT OUT"
  }
  prov = (!marked || unmk > 0)
  if (validity == "skip") print "(validity not checked: VALIDITY=skip, the local smoke)"
  if (!full) printf "(%s is not the control: its capped tickets are expected and do not count against validity)\n", base
  for (i = 1; i <= nw; i++) print "warning: " warn[i]
  if (!marked) print "(no DATA_DIR: no open position carries a mark; every open-leg key is left out of the sums and of the bars, and the outcome is PROVISIONAL)"
  else if (unmk > 0) printf "(%d open-leg keys of the valid seeds have no bar file to mark them: they are left out of the sums and of the bars, and the outcome is PROVISIONAL)\n", unmk

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
    printf "%-4s %8d %8d %8s %10d %9d %9d %8s %8d\n", sname[s], placedC[s], capped[s], pct(capped[s], placedC[s]), cappedS[s], nM[s], lowc[s], pct(lowc[s], nM[s]), lrtbad[s]
    if (valid[s]) { Pc += placedC[s]; Cc += capped[s]; Mp += nM[s]; Lw += lowc[s] }
  }
  printf "%-4s %8d %8d %8s %10s %9d %9d %8s   (valid seeds)\n", "pool", Pc, Cc, pct(Cc, Pc), "", Mp, Lw, pct(Lw, Mp)
  print "(L, F and the weights below read tickets, entry prices and share counts, never a mark: open-leg keys count in them)"
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
  print ""; print "== 4. The price/size split, NAV-% of the arm's NAV at the decision (README §The price/size split), closed legs only"
  printf "%-4s %5s %8s %8s %8s %8s | %5s %8s | %5s %8s | %8s | %5s %8s %8s | %8s %8s %8s %8s\n", "seed", "n M", "price", "size", "exit", "M", "n RC", "RC cap", "n RS", "RS cap", "D", "n M0", "M0", "|d| M0", "PC", "PS", "total", "trim3"
  for (s = 1; s <= ns; s++) {
    D[s] = tot["M", s] + tot["RCcap", s] + tot["RScap", s]
    Df[s] = fsum("M", s) + fsum("RCcap", s) + fsum("RScap", s)
    trim[s] = trimmed(kdc, s, nkc[s]); trimf[s] = trimmed(kdf, s, nkf[s])
    printf "%-4s %5d %+8.2f %+8.2f %+8.2f %+8.2f | %5d %+8.2f | %5d %+8.2f | %+8.2f | %5d %+8.2f %8.3f | %+8.2f %+8.2f %+8.2f %+8.2f\n", sname[s],
      cnt["M", s], pr[s], sz[s], ex[s], tot["M", s], cnt["RCcap", s], tot["RCcap", s], cnt["RScap", s], tot["RScap", s], D[s],
      cnt["M0", s], tot["M0", s], (cnt["M0", s] ? abs0[s] / cnt["M0", s] : 0), tot["PC", s], tot["PS", s], total[s], trim[s]
  }
  printf "M = price + size + exit over capped keys both arms filled; RC cap = capped keys only %s filled (+c%s); RS cap = capped keys only %s filled (-c%s);\n", test, test, base, base
  printf "D = M + RC cap + RS cap (the same-ticket effect: keys both arms placed, %s capped); M0 = the same-ticket path null (uncapped, both filled);\n", test
  print "PC / PS = keys placed in one arm only (admissions and path); total = sum over the keys of c_test - c_base; trim3 = total without the 3 largest and 3 smallest keys."
  print "Every sum in this section is over closed legs only (the simulator's own pnl); the open-leg keys left out of it are counted in the next table."
  print ""; printf "Open-leg keys: a ticket either arm still holds open at the window end. Its c depends on a mark from the bar store, so no sum above includes it.\n"
  printf "%-4s %8s %7s %8s | left out of: %4s %6s %6s %4s %4s %4s %4s %4s\n", "seed", "open-leg", "marked", "unmarked", "M", "RCcap", "RScap", "M0", "RC0", "RS0", "PC", "PS"
  for (s = 1; s <= ns; s++)
    printf "%-4s %8d %7d %8d | %13s%4d %6d %6d %4d %4d %4d %4d %4d\n", sname[s], nmd[s], nmd[s] - unmarked[s], unmarked[s], "", lo["M", s], lo["RCcap", s], lo["RScap", s],
      lo["M0", s], lo["RC0", s], lo["RS0", s], lo["PC", s], lo["PS", s]
  print "(No sum over these keys is printed, pooled or not: the bars below read their marked values, and only the bars' pass or fail leaves the script.)"
  if (full) {
    print ""; print "Screen comparison (#3594 sizing.txt: screen price = this price + exit, as its exits were fixed; screen size = this size; closed legs only):"
    split("+3.9 +4.4 +2.7 +6.5 +6.1", scp, " "); split("+7.7 +3.0 +4.1 +5.5 +3.6", scz, " ")
    for (s = 1; s <= ns; s++) { j = substr(sname[s], 2) + 1
      printf "%s  price+exit %+7.2f (screen %s)  size %+7.2f (screen %s)  size share of M %s  %s/%s weight on capped pairs p50 %s p90 %s  %s/%s fill p50 %s\n",
        sname[s], pr[s] + ex[s], scp[j], sz[s], scz[j], (tot["M", s] != 0 ? sprintf("%.0f %%", 100 * sz[s] / tot["M", s]) : "n/a"),
        test, base, wq(s, 0.5), wq(s, 0.9), test, base, rq(s, 0.5) }
  }
  print ""; printf "Admission and displacement (README §The admission channel): capped tickets only %s placed, by what %s did that Friday,\n", test, base
  printf "and %s's tickets that %s skipped for cash (n tickets, NAV-%% summed over closed legs; an unfilled ticket counts 0):\n", base, test
  printf "%-4s %16s %16s %16s %16s %10s | %16s | %s\n", "seed", "A gate (rec.)", "A no " base " list", "A other", "A all", "A w/o top3", "displaced (cash)", "open-leg left out (A, displaced)"
  for (s = 1; s <= ns; s++) {
    na = cnt["Arec", s] + cnt["Anolist", s] + cnt["Aother", s]; ta = tot["Arec", s] + tot["Anolist", s] + tot["Aother", s]
    printf "%-4s %5d %+10.2f %5d %+10.2f %5d %+10.2f %5d %+10.2f %+10.2f | %5d %+10.2f | %d, %d\n", sname[s], cnt["Arec", s], tot["Arec", s],
      cnt["Anolist", s], tot["Anolist", s], cnt["Aother", s], tot["Aother", s], na, ta, atrim(avc, navc, s), cnt["Xcash", s], tot["Xcash", s],
      lo["Arec", s] + lo["Anolist", s] + lo["Aother", s], lo["Xcash", s] }
  print "(A w/o top3 = the A total without its 3 largest keys; README §Arm G, the ADMISSIONS row)"
  print ""; print "Components by outcome (n keys, NAV-% summed, both over closed legs; then the open-leg keys left out):"
  sortcomp()
  for (s = 1; s <= ns; s++) for (i = 1; i <= ncomp; i++) if ((comp[i], s) in known)
      printf "%s  %-48s %5d %+9.2f   left out %d\n", sname[s], comp[i], cnt[comp[i], s], tot[comp[i], s], lo[comp[i], s]
  if (ns > 0) { print ""; printf "Largest key-level differences per seed (c_%s - c_%s, NAV-%%; key class; closed legs only, the open-leg keys left out are counted at the end of the line):\n", test, base }
  for (s = 1; s <= ns; s++) top(s)

  # ------------------------------------------------------------------ by decision year
  years()

  # ------------------------------------------------------------------ decision
  if (full) decide(); else report()
}
function row(s, label, n, arr,   i, o) {
  printf "%-4s %-22s %7d", sname[s], label, n; o = n
  for (i = 1; i <= 7; i++) { printf " %8d", arr[s, ks[i]]; o -= arr[s, ks[i]] }
  printf " %8d\n", o
}
function trimmed(a, s, n,   i, j, t, b, sum) {   # the list a[s, 1..n] without its 3 largest and 3 smallest
  for (i = 1; i <= n; i++) b[i] = a[s, i]
  for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
  sum = 0; for (i = 4; i <= n - 3; i++) sum += b[i]; return sum
}
function atrim(a, na, s,   i, j, t, n, b, sum) {   # the admissions' total (A, all classes) a[s, 1..na[s]] without its 3 largest keys
  n = na[s]; for (i = 1; i <= n; i++) b[i] = a[s, i]
  for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
  sum = 0; for (i = 1; i <= n - 3; i++) sum += b[i]; return sum
}
function wq(s, p,   i, b) { for (i = 1; i <= nwr[s]; i++) b[i] = wrs[s, i]; return nwr[s] ? sprintf("%.3f", q(b, nwr[s], p)) : "n/a" }
function rq(s, p,   i, b) { for (i = 1; i <= nwr[s]; i++) b[i] = rcs[s, i]; return nwr[s] ? sprintf("%.4f", q(b, nwr[s], p)) : "n/a" }
function top(s,   i, j, n, used, best, bi, line) {   # the 3 largest positive and 3 largest negative closed-leg key differences
  line = sname[s] " +:"
  for (j = 1; j <= 3; j++) { best = 0; bi = 0; for (i = 1; i <= nkc[s]; i++) if (!(i in used) && kdc[s, i] > best) { best = kdc[s, i]; bi = i }
    if (bi) { used[bi] = 1; line = line sprintf("  %s %+.2f", kkc[s, bi], best) } }
  line = line "   -:"
  for (j = 1; j <= 3; j++) { best = 0; bi = 0; for (i = 1; i <= nkc[s]; i++) if (!(i in used) && kdc[s, i] < best) { best = kdc[s, i]; bi = i }
    if (bi) { used[bi] = 1; line = line sprintf("  %s %+.2f", kkc[s, bi], best) } }
  print line "   (" nmd[s] + 0 " open-leg keys left out)"
}
# The decision-year tables (README §Reported regardless): per seed, then pooled over the valid seeds, the NAV-% summed
# over the keys decided that year, closed legs only: D (capped keys both arms placed), M0, A (the admissions, all
# classes) and the total, with the open-leg keys left out of that year counted beside them. The "all" row is §4's.
function years(   s, y, ny, yl, i, j, t, n, nA, D0, M00, A0, T0, L0, k0) {
  ny = 0; for (y in yrs) yl[++ny] = y
  for (i = 2; i <= ny; i++) { t = yl[i]; for (j = i - 1; j >= 1 && yl[j] > t; j--) yl[j + 1] = yl[j]; yl[j + 1] = t }
  print ""; printf "== 4b. By decision year, NAV-%% summed over the keys decided that year, closed legs only (README §Reported regardless); c = c_%s - c_%s\n", test, base
  printf "%-4s %-5s %5s %9s %9s %5s %9s %9s | %s\n", "seed", "year", "keys", "D", "M0", "n A", "A", "total", "open-leg keys left out"
  for (s = 1; s <= ns; s++) {
    n = 0; D0 = 0; M00 = 0; nA = 0; A0 = 0; T0 = 0; L0 = 0
    for (i = 1; i <= ny; i++) { y = yl[i]
      if (!((s, y) in yn) && !((s, y) in ylo)) continue
      printf "%-4s %-5s %5d %+9.2f %+9.2f %5d %+9.2f %+9.2f | %d\n", sname[s], y, yn[s, y], yD[s, y], yM0[s, y], ynA[s, y], yA[s, y], yT[s, y], ylo[s, y]
      n += yn[s, y]; D0 += yD[s, y]; M00 += yM0[s, y]; nA += ynA[s, y]; A0 += yA[s, y]; T0 += yT[s, y]; L0 += ylo[s, y] }
    printf "%-4s %-5s %5d %+9.2f %+9.2f %5d %+9.2f %+9.2f | %d\n", sname[s], "all", n, D0, M00, nA, A0, T0, L0
  }
  printf "%-4s %-5s %5s %9s %9s %5s %9s %9s | %s\n", "pool", "year", "keys", "D", "M0", "n A", "A", "total", "(valid seeds, summed)"
  for (i = 1; i <= ny; i++) { y = yl[i]; n = 0; D0 = 0; M00 = 0; nA = 0; A0 = 0; T0 = 0; L0 = 0
    for (k0 = 1; k0 <= nv; k0++) { s = vs[k0]; n += yn[s, y]; D0 += yD[s, y]; M00 += yM0[s, y]; nA += ynA[s, y]; A0 += yA[s, y]; T0 += yT[s, y]; L0 += ylo[s, y] }
    if (n + L0 > 0) printf "%-4s %-5s %5d %+9.2f %+9.2f %5d %+9.2f %+9.2f | %d\n", "pool", y, n, D0, M00, nA, A0, T0, L0 }
  print "(D = M + RC cap + RS cap of §4 over the capped keys both arms placed; A = the capped keys only " test " placed; keys = every key of the year with closed legs only, RN included)"
}
# The common quantities over the valid seeds: delta median and signs, delta's bar from arm S's own returns, D and trim3
# signs (read on the full marked values), and the drawdown gap. Sets globals n, m, pos, neg, Dp, Tp, mS, bar, mdd, need.
function stats(   i, j, k2, s, a, b, ddS, ddC, lsS) {
  n = nv; pos = 0; neg = 0; Dp = 0; Tp = 0
  for (i = 1; i <= n; i++) { s = vs[i]; a[i] = dl[s]; if (dl[s] > 0) pos++; if (dl[s] < 0) neg++; if (Df[s] > 0) Dp++; if (trimf[s] > 0) Tp++
    ddS[i] = dd[s, "S"]; ddC[i] = dd[s, "C"]; lsS[i] = log(1 + RS0[s] / 100) }
  j = 0; for (i = 1; i <= n; i++) for (k2 = i + 1; k2 <= n; k2++) { j++; b[j] = lsS[i] - lsS[k2]; if (b[j] < 0) b[j] = -b[j] }
  mS = med(b, j); bar = (mS != "nan" && mS > 0.20) ? mS : 0.20
  need = n - 1; m = med(a, n)
  mdd = (n > 0) ? med(ddC, n) - med(ddS, n) : "nan"
}
function yn3(x) { return x ? "yes" : "no" }
function decide(   L, F, out, why, tag, Ale0) {
  print ""; printf "== 5. Outcome, %s vs %s (README §Decision rule, applied as written%s)\n", test, base, (test == "G" ? "; §Arm G \"G vs S\"" : "")
  stats()
  Ale0 = 0; for (i = 1; i <= n; i++) if (atrim(avf, navf, vs[i]) <= 0) Ale0++
  L = (Pc > 0) ? Cc / Pc : 0; F = (Mp > 0) ? Lw / Mp : 0
  printf "valid seeds %d; L %.4f (bar 0.10); F %.4f over %d capped pairs (bar 0.50, >= 30 pairs)\n", n, L, F, Mp
  if (n > 0) printf "median delta %+.4f; delta > 0 in %d, < 0 in %d of %d; delta bar %.4f (max(0.20, m_S = %s)); D > 0 in %d; trim3 > 0 in %d (D and trim3 read on the closed legs together with the open legs that have a mark); maxDD median %s - %s %+.2f pp\n",
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
  printf "OUTCOME %s vs %s: %s (%s)%s\n", test, base, out, why, (prov ? (marked ? "  PROVISIONAL: " unmk " open-leg keys have no mark" : "  PROVISIONAL: open positions not marked") : "")
  for (i = 1; i <= ns; i++) printf "SEED %s %s-%s delta %+.4f L %s F %s D %+.2f M %+.2f price %+.2f size %+.2f exit %+.2f total %+.2f (closed legs only; %d open-leg keys left out; bars read with the open legs that have a mark: D>0 %s, trim3>0 %s)\n", sname[i], test, base, dl[i],
    pct(capped[i], placedC[i]), pct(lowc[i], nM[i]), D[i], tot["M", i], pr[i], sz[i], ex[i], total[i], nmd[i], yn3(Df[i] > 0), yn3(trimf[i] > 0)
  tag = out; gsub(/ /, "_", tag)
  printf "RULE %s,%s %s n=%d median=%s pos=%d neg=%d delta=%.4f Dp=%d Tp=%d mdd=%s L=%.4f F=%.4f Mp=%d Ale0=%d gbad=%d marked=%d unmarked=%d\n", base, test, tag, n,
    (n ? sprintf("%.4f", m) : "nan"), pos, neg, bar, Dp, Tp, (n ? sprintf("%.2f", mdd) : "nan"), L, F, Mp, Ale0, (gin ? gbad : 0), marked, unmk
}
# C vs G (README §Arm G): the admissions effect, reported; it names a channel in the combined outcome and never decides
# a build on its own. Pooled A and displacement sums over the valid seeds, closed legs only.
function report(   i, s, nA, tA, a1, a2, a3, x, lA) {
  print ""; printf "== 5. Report, %s vs %s (README §Arm G \"C vs G\": attribution only, no outcome of its own)\n", test, base
  stats()
  for (i = 1; i <= n; i++) { s = vs[i]; a1 += tot["Arec", s]; a2 += tot["Anolist", s]; a3 += tot["Aother", s]; x += tot["Xcash", s]
    nA += cnt["Arec", s] + cnt["Anolist", s] + cnt["Aother", s]; lA += lo["Arec", s] + lo["Anolist", s] + lo["Aother", s] + lo["Xcash", s] }
  tA = a1 + a2 + a3
  printf "valid seeds %d; median delta_%s%s %s; delta > 0 in %d, < 0 in %d; the bar %.4f (max(0.20, m_S = %s))\n", n, test, base,
    (n ? sprintf("%+.4f", m) : "n/a"), pos, neg, bar, (mS == "nan" ? "n/a" : sprintf("%.4f", mS))
  printf "admissions pooled (capped %s tickets on keys %s did not place), closed legs only: %d tickets, NAV-%% A gate (rec.) %+.2f, A no %s list %+.2f, A other %+.2f, A all %+.2f; displaced (cash) %+.2f; %d open-leg keys left out\n",
    test, base, nA, a1, base, a2, a3, tA, x, lA
  for (i = 1; i <= ns; i++) printf "SEED %s %s-%s delta %+.4f A all %+.2f displaced %+.2f total %+.2f (closed legs only; %d open-leg keys left out)\n", sname[i], test, base, dl[i],
    tot["Arec", i] + tot["Anolist", i] + tot["Aother", i], tot["Xcash", i], total[i], nmd[i]
  printf "RULE %s,%s REPORT n=%d median=%s pos=%d neg=%d delta=%.4f arec=%.2f anolist=%.2f aother=%.2f aall=%.2f xcash=%.2f gbad=%d marked=%d unmarked=%d\n",
    base, test, n, (n ? sprintf("%.4f", m) : "nan"), pos, neg, bar, a1, a2, a3, tA, x, (gin ? gbad : 0), marked, unmk
}
function sortcomp(   i, j, t) {   # component names in a fixed order, whatever the input order
  for (i = 2; i <= ncomp; i++) { t = comp[i]; for (j = i - 1; j >= 1 && comp[j] > t; j--) comp[j + 1] = comp[j]; comp[j + 1] = t }
}
