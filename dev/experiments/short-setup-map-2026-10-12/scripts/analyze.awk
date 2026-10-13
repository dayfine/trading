# Short setup map: apply the pre-registered decision rule and print the descriptive splits.
# Usage: awk -F, -v floor=5 -f analyze.awk results/events-full.csv
# Pre-registration: dev/plans/short-setup-map-2026-10-12.md. Outcome of record: O2 (book stop) excess vs an SPY
# short; O1 +60 is the sign check. "Halves" = breakdown year 2000-2012 vs 2013-2025.

function qs(A, lo, hi,   i, last, t) {
  if (lo >= hi) return
  t = A[lo]; A[lo] = A[int((lo + hi) / 2)]; A[int((lo + hi) / 2)] = t
  last = lo
  for (i = lo + 1; i <= hi; i++) if (A[i] < A[lo]) { last++; t = A[last]; A[last] = A[i]; A[i] = t }
  t = A[lo]; A[lo] = A[last]; A[last] = t
  qs(A, lo, last - 1); qs(A, last + 1, hi)
}
function q(A, n, p,   k) { k = int(p * (n - 1)) + 1; return A[k] }
function add(key, x) { if (x == "") return; cnt[key]++; vals[key, cnt[key]] = x + 0; sum[key] += x; if (x > 0) pos[key]++ }
# One-line summary of a key: n, mean, median, p10/p25/p75/p90, beat rate.
function line(key,   n, k, A) {
  n = cnt[key] + 0
  if (n == 0) return sprintf("%-44s n=0", key)
  for (k = 1; k <= n; k++) A[k] = vals[key, k]
  qs(A, 1, n)
  return sprintf("%-44s n=%5d mean=%+6.2f%% med=%+6.2f%% p10=%+6.1f p25=%+6.1f p75=%+6.1f p90=%+6.1f beat=%5.1f%%", \
    key, n, 100 * sum[key] / n, 100 * q(A, n, 0.5), 100 * q(A, n, 0.1), 100 * q(A, n, 0.25), 100 * q(A, n, 0.75), \
    100 * q(A, n, 0.9), 100 * pos[key] / n)
}
function med(key,   n, k, A) { n = cnt[key] + 0; if (!n) return 0; for (k = 1; k <= n; k++) A[k] = vals[key, k]; qs(A, 1, n); return q(A, n, 0.5) }
function mean(key) { return cnt[key] ? sum[key] / cnt[key] : 0 }
function verdict(c, beatmin,   n, m, md, b, h1, h2, o1, ok) {
  n = cnt[c] + 0; m = mean(c); md = med(c); b = n ? pos[c] / n : 0
  h1 = mean(c "|h1"); h2 = mean(c "|h2"); o1 = mean(c "|o1_60")
  ok = (n >= 100) && (m >= 0.02) && (md > 0) && (b >= beatmin) && (h1 * h2 > 0) && (o1 * m > 0)
  printf "%s: n=%d (>=100 %s) mean=%+.2f%% (>=+2%% %s) median=%+.2f%% (>0 %s) beat=%.1f%% (>=%.0f%% %s) halves %+.2f/%+.2f%% (%s) O1+60 %+.2f%% (%s) => %s\n", \
    c, n, (n >= 100 ? "ok" : "FAIL"), 100 * m, (m >= 0.02 ? "ok" : "FAIL"), 100 * md, (md > 0 ? "ok" : "FAIL"), \
    100 * b, 100 * beatmin, (b >= beatmin ? "ok" : "FAIL"), 100 * h1, 100 * h2, (h1 * h2 > 0 ? "ok" : "FAIL"), \
    100 * o1, (o1 * m > 0 ? "ok" : "FAIL"), (ok ? "EDGE" : "no edge")
}
function lev_adv(x) { return (x == "") ? "na" : (x < 0.30 ? "<30%" : (x < 1.0 ? "30-100%" : ">=100%")) }
function lev_w(x) { return (x <= 8) ? "<=8" : (x <= 20 ? "9-20" : ">20") }
function lev_room(x) { return (x <= 0.15) ? "<=15%" : (x <= 0.30 ? "15-30%" : ">30%") }
function lev_yld(x) { return (x <= 0) ? "none" : (x < 0.02 ? "<2%" : (x <= 0.05 ? "2-5%" : ">5%")) }
function lev_grp(x) { return (x == "") ? "na" : (x < 0 ? "weak" : "not_weak") }

NR == 1 { for (k = 1; k <= NF; k++) col[$k] = k; next }
{
  if ($(col["raw_close"]) + 0 < floor) next
  yr = substr($(col["date"]), 1, 4) + 0; half = (yr <= 2012) ? "h1" : "h2"
  ph = $(col["phase"]); adv = $(col["advance"]); rsc = $(col["rs_class"]); grp = $(col["group_rel"])
  primary = (ph == "s4_early" || ph == "s3") && adv != "" && adv + 0 >= 0.30 && rsc != "rising" && rsc != "na" && grp != "" && grp + 0 < 0
  N++; years[yr]++
  r1 = $(col["e1_room"]); if (r1 != "" && r1 + 0 <= 0.15) room15++
  e2w = $(col["e2_weeks"]) + 0; if (e2w > 0) { ne2++; e2wk[e2w]++ }
  for (en = 1; en <= 2; en++) {
    e = "e" en; x = $(col[e "_o2_exc"]); if (x == "") continue
    o60 = $(col[e "_o1_60"])
    add("ALL " e, x)
    xc = (x < -1) ? -1 : ((x > 1) ? 1 : x)   # clipped at +-100 % (vendor splices, #3239) for a robustness line
    add("ALL " e " clipped+-100%", xc)
    if (primary) { c = "P" en; add(c, x); add(c "|" half, x); add(c "|o1_60", o60); add(c " clipped+-100%", xc) }
    add(e " phase=" ph, x); add(e " advance=" lev_adv(adv), x); add(e " top_width=" lev_w($(col["top_width"])), x)
    add(e " hs=" $(col["hs"]), x); add(e " rs=" rsc, x); add(e " group=" lev_grp(grp), x)
    add(e " room=" lev_room($(col[e "_room"])), x); add(e " yield=" lev_yld($(col["yield"])), x)
    add(e " bigdiv_in_hold=" $(col["bigdiv"]), x)
    if (yr >= 2000 && yr <= 2002) add(e " bear 2000-02", x)
    if (yr >= 2007 && yr <= 2009) add(e " bear 2007-09", x)
    if (yr == 2022) add(e " bear 2022", x)
    if (primary) { if (yr >= 2000 && yr <= 2002) add("P" en " bear 2000-02", x); if (yr >= 2007 && yr <= 2009) add("P" en " bear 2007-09", x); if (yr == 2022) add("P" en " bear 2022", x) }
    add(e " o1_20", $(col[e "_o1_20"])); add(e " o1_60", o60); add(e " o1_120", $(col[e "_o1_120"]))
    if (primary) { add("P" en " o1_20", $(col[e "_o1_20"])); add("P" en " o1_120", $(col[e "_o1_120"])); add("P" en " stock_short_ret(O2, not excess)", $(col[e "_o2_ret"])) }
    st = $(col[e "_o2_stopped"]); if (st == 1) stops[e]++
  }
}
END {
  printf "== Short setup map, price floor $%s: %d events; E1 room <= 15%%: %d (%.1f%%); E2 pullback share %.1f%%\n\n", \
    floor, N, room15, 100 * room15 / N, 100 * ne2 / N
  print "== Decision rule (O2 excess vs SPY short)"
  verdict("P1", 0.55); verdict("P2", 0.55); print ""
  print "== Primary cells"; print line("P1"); print line("P2"); print line("P1 clipped+-100%"); print line("P2 clipped+-100%")
  print line("ALL e1 clipped+-100%"); print line("ALL e2 clipped+-100%")
  for (en = 1; en <= 2; en++) { print line("P" en "|h1"); print line("P" en "|h2"); print line("P" en "|o1_60"); print line("P" en " o1_20"); print line("P" en " o1_120"); print line("P" en " stock_short_ret(O2, not excess)") }
  for (en = 1; en <= 2; en++) { print line("P" en " bear 2000-02"); print line("P" en " bear 2007-09"); print line("P" en " bear 2022") }
  print "\n== Whole population"
  for (en = 1; en <= 2; en++) { e = "e" en; print line("ALL " e); print line(e " o1_20"); print line(e " o1_60"); print line(e " o1_120"); printf "%-44s %d\n", e " O2 stopped", stops[e] }
  print "\n== Descriptive splits (O2 excess; candidates only at beat >= 58 % with every other criterion)"
  ns = split("phase=s4_early phase=s4_late phase=s3 phase=s12 advance=<30% advance=30-100% advance=>=100% advance=na top_width=<=8 top_width=9-20 top_width=>20 hs=1 hs=0 rs=neg_falling rs=pos_falling rs=rising rs=na group=weak group=not_weak group=na room=<=15% room=15-30% room=>30% yield=none yield=<2% yield=2-5% yield=>5% bigdiv_in_hold=1 bigdiv_in_hold=0", S, " ")
  for (en = 1; en <= 2; en++) for (k = 1; k <= ns; k++) print line("e" en " " S[k])
  for (en = 1; en <= 2; en++) { print line("e" en " bear 2000-02"); print line("e" en " bear 2007-09"); print line("e" en " bear 2022") }
  print "\n== Events by breakdown year"; for (y = 2000; y <= 2025; y++) printf "%d %d\n", y, years[y]
  print "\n== Weeks to E2 pullback"; for (w = 1; w <= 8; w++) printf "%d %d\n", w, e2wk[w]
}
