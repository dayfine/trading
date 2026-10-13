# Short wide-top screen: apply the pre-registered decision rule and print the descriptive splits.
# Usage: awk -F, -v floor=5 -f analyze.awk <events csv with one header>
# Pre-registration: dev/plans/short-wide-top-screen-2026-10-13.md. Step 1 reads O1 +60 (beat >= 55 % and median > 0
# or CLOSE); step 2 reads O2 (stop held to 120 bars) excess vs an SPY short. Halves: breakdown year 2000-12 vs 2013-25.

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
function line(key,   n, k, A) {
  n = cnt[key] + 0
  if (n == 0) return sprintf("%-34s n=0", key)
  for (k = 1; k <= n; k++) A[k] = vals[key, k]
  qs(A, 1, n)
  return sprintf("%-34s n=%5d mean=%+6.2f%% med=%+6.2f%% p10=%+6.1f p25=%+6.1f p75=%+6.1f p90=%+6.1f beat=%5.1f%%", \
    key, n, 100 * sum[key] / n, 100 * q(A, n, 0.5), 100 * q(A, n, 0.1), 100 * q(A, n, 0.25), 100 * q(A, n, 0.75), \
    100 * q(A, n, 0.9), 100 * pos[key] / n)
}
function med(key,   n, k, A) { n = cnt[key] + 0; if (!n) return 0; for (k = 1; k <= n; k++) A[k] = vals[key, k]; qs(A, 1, n); return q(A, n, 0.5) }
function mean(key) { return cnt[key] ? sum[key] / cnt[key] : 0 }
function beat(key) { return cnt[key] ? pos[key] / cnt[key] : 0 }
function lev_room(x) { return (x <= 0.15) ? "<=15%" : (x <= 0.30 ? "15-30%" : ">30%") }

NR == 1 { for (k = 1; k <= NF; k++) col[$k] = k; next }
{
  if ($(col["raw_close"]) + 0 < floor) next
  yr = substr($(col["date"]), 1, 4) + 0; half = (yr <= 2012) ? "h1" : "h2"
  x = $(col["e1_o2_exc"]); o60 = $(col["e1_o1_60"])
  N++; years[yr]++; if ($(col["e1_o2_stopped"]) == 1) stopped++
  add("O1+20", $(col["e1_o1_20"])); add("O1+60", o60); add("O1+120", $(col["e1_o1_120"]))
  add("O2", x); add("O2|" half, x); add("O1+60|" half, o60)
  if (x != "") add("O2 clipped+-100%", (x < -1) ? -1 : ((x > 1) ? 1 : x))
  add("O2 stock short ret (not excess)", $(col["e1_o2_ret"]))
  add("O2 room=" lev_room($(col["e1_room"])), x); add("O1+60 room=" lev_room($(col["e1_room"])), o60)
  add("O2 phase=" $(col["phase"]), x); add("O1+60 phase=" $(col["phase"]), o60)
  if (yr >= 2000 && yr <= 2002) { add("O2 bear 2000-02", x); add("O1+60 bear 2000-02", o60) }
  if (yr >= 2007 && yr <= 2009) { add("O2 bear 2007-09", x); add("O1+60 bear 2007-09", o60) }
  if (yr == 2022) { add("O2 bear 2022", x); add("O1+60 bear 2022", o60) }
}
END {
  printf "== Short wide-top screen, price floor $%s: %d events; O2 stopped %d (%.1f%%)\n\n", floor, N, stopped, 100 * stopped / N
  print "== Decision rule"
  b = beat("O1+60"); m = med("O1+60")
  s1 = (b >= 0.55 && m > 0)
  printf "Step 1 O1+60: n=%d beat=%.1f%% (>=55%% %s) median=%+.2f%% (>0 %s) => %s\n", cnt["O1+60"], 100 * b, \
    (b >= 0.55 ? "ok" : "FAIL"), 100 * m, (m > 0 ? "ok" : "FAIL"), (s1 ? "pass to step 2" : "CLOSE (no-build)")
  n = cnt["O2"] + 0; mo = mean("O2"); md = med("O2"); bo = beat("O2"); h1 = mean("O2|h1"); h2 = mean("O2|h2"); o1 = mean("O1+60")
  ok = (n >= 100) && (mo >= 0.02) && (md > 0) && (bo >= 0.55) && (h1 * h2 > 0) && (o1 * mo > 0)
  printf "Step 2 O2%s: n=%d (>=100 %s) mean=%+.2f%% (>=+2%% %s) median=%+.2f%% (>0 %s) beat=%.1f%% (>=55%% %s) halves %+.2f/%+.2f%% (%s) O1+60 mean %+.2f%% (%s) => %s\n", \
    (s1 ? "" : " (not reached; shown for the record)"), n, (n >= 100 ? "ok" : "FAIL"), 100 * mo, (mo >= 0.02 ? "ok" : "FAIL"), \
    100 * md, (md > 0 ? "ok" : "FAIL"), 100 * bo, (bo >= 0.55 ? "ok" : "FAIL"), 100 * h1, 100 * h2, (h1 * h2 > 0 ? "ok" : "FAIL"), \
    100 * o1, (o1 * mo > 0 ? "ok" : "FAIL"), (ok ? "EDGE" : "no edge")
  printf "VERDICT: %s\n\n", (s1 && ok) ? "EDGE" : "CLOSE (no-build)"
  print "== Outcomes"
  ns = split("O1+20 O1+60 O1+120 O2 O2|h1 O2|h2 O1+60|h1 O1+60|h2", S, " "); for (k = 1; k <= ns; k++) print line(S[k])
  print line("O2 clipped+-100%"); print line("O2 stock short ret (not excess)")
  print "\n== Room split"
  ns = split("<=15% 15-30% >30%", S, " "); for (k = 1; k <= ns; k++) { print line("O1+60 room=" S[k]); print line("O2 room=" S[k]) }
  print "\n== SPY phase split"
  ns = split("s4_early s4_late s3 s12 na", S, " "); for (k = 1; k <= ns; k++) { print line("O1+60 phase=" S[k]); print line("O2 phase=" S[k]) }
  print "\n== Bear years"
  ns = split("2000-02 2007-09 2022", S, " "); for (k = 1; k <= ns; k++) { print line("O1+60 bear " S[k]); print line("O2 bear " S[k]) }
  print "\n== Events by breakdown year"; for (y = 2000; y <= 2025; y++) printf "%d %d\n", y, years[y]
}
