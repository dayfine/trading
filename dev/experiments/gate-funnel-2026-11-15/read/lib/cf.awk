# cf.awk -- ex-post outcomes of each population (README §Descriptive reads 2-3, the rule's ride clause): the
# population screen's definitions, as ../../../price-band-binding-2026-11-13/read/lib/fwd.awk computes them from the
# screened Friday's close. POSIX awk.
#
# usage: awk -F'\t' -v CAPR=1.90 -v GATES=cfgates.txt -v TITLE=... -v ONLY=regex -f cf.awk fwd.tsv nall.tsv classes.tsv
#   fwd.tsv      symbol date raw_close band monster fwd_max ride cov    (fwd.awk; cov F/D/T/X)
#   nall.tsv     class rows_before_dedup                                 (classes.awk NALL)
#   classes.tsv  class date symbol                                       (classes.awk; kept rows)
# Primary convention FD: cov F (52 forward weeks) or D (delisted inside them, read over the weeks it traded); T (the
# store ends first) and X (no bar) are counted and left out. ride = return to the first weekly close below the 30-week
# WMA, at most 104 weeks, capped at CAPR (+190 %, PREREG Amendment 1). monster = a weekly close >= 2x the base within
# 52 weeks. Quantiles come from a 0.1 pp histogram of the capped ride. Halves: 2000-12 and 2013-26. ONLY limits the
# printed classes (a regex on the class name). Prints aggregates only: no name, price or per-name return.
FILENAME == ARGV[1] { M[$1, $2] = $5; R[$1, $2] = $7; C[$1, $2] = $8; next }
FILENAME == ARGV[2] { NALLC[$1] = $2; next }
{
  c = $1; k = $3 SUBSEP $2; cov = (k in C) ? C[k] : "X"
  nk[c]++; ncov[c, cov]++; seen[c] = 1
  if (cov != "F" && cov != "D") next
  r = R[k] + 0; if (r > CAPR) r = CAPR; m = M[k] + 0; h = ($2 <= "2012-12-31") ? 1 : 2
  add(c, r, m); add(c "|h" h, r, m)
  b = int((r + 1) * 1000 + 0.5); H[c, b]++
}
function add(g, r, m) { n[g]++; s[g] += r; mon[g] += m; win[g] += (r > 0) }
function mean(g) { return (n[g] > 0) ? s[g] / n[g] : 0 }
function mrate(g) { return (n[g] > 0) ? mon[g] / n[g] : 0 }
function q(c, p,   t, b, cum) {
  if (n[c] == 0) return "n/a"; t = p * n[c]; cum = 0
  for (b = 0; b <= 2900; b++) { cum += H[c, b]; if (cum >= t) return sprintf("%+.1f", 100 * (b / 1000 - 1)) }
  return "n/a"
}
function line(c,   f) {
  f = "walk:Funded"
  printf "%-34s %8d %7d  F %6d D %5d T %5d X %5d | %7d  mon %5.1f %%  win %5.1f %%  mean %+6.1f %%  p10 %6s p50 %6s p90 %6s", c, NALLC[c], nk[c], ncov[c, "F"], ncov[c, "D"], ncov[c, "T"], ncov[c, "X"], n[c], 100 * mrate(c), (n[c] ? 100 * win[c] / n[c] : 0), 100 * mean(c), q(c, .10), q(c, .50), q(c, .90)
  printf " | 2000-12 n %6d mon %5.1f %% mean %+6.1f %% | 2013-26 n %6d mon %5.1f %% mean %+6.1f %%", n[c "|h1"], 100 * mrate(c "|h1"), 100 * mean(c "|h1"), n[c "|h2"], 100 * mrate(c "|h2"), 100 * mean(c "|h2")
  printf " | vs funded: mean %+6.1f pp, monster x%s\n", 100 * (mean(c) - mean(f)), (mrate(f) > 0) ? sprintf("%.2f", mrate(c) / mrate(f)) : "n/a"
}
END {
  print "== " TITLE " =="
  print "columns: class | rows (before the 26-week dedup) | kept | coverage of kept rows | FD rows, monster rate, win rate, mean capped ride, p10/p50/p90 (pp) | by half | against walk:Funded"
  no = split("macro:proxy all brk:Price_floor brk:Stage_setup brk:Breakout_volume brk:Rs_declining brk:Failed_breakout brk:Volume_band sector grade cut:Buyable cut:No_structural_stop cut:Stop_too_wide cut:Already_held crowd:gross crowd:net walk:Not_reached walk:Skipped_No_structural_stop walk:Skipped_Stop_too_wide walk:Skipped_Insufficient_cash walk:Skipped_Already_held walk:Funded tier:A_plus tier:A tier:B tier:C tier:D tier:F tierw:A_plus tierw:A tierw:B tierw:C tierw:D tierw:F", O, " ")
  for (i = 1; i <= no; i++) listed[O[i]] = 1
  for (i = 1; i <= no; i++) if ((O[i] in seen) && O[i] ~ ONLY) line(O[i])
  # anything not in the fixed order (other walk skips, score values), sorted by name (scores numerically)
  m = 0; for (c in seen) if (!(c in listed) && c ~ ONLY) X[++m] = c
  for (i = 2; i <= m; i++) { t = X[i]; j = i - 1; while (j >= 1 && later(X[j], t)) { X[j + 1] = X[j]; j-- } X[j + 1] = t }
  for (i = 1; i <= m; i++) line(X[i])
  for (c in seen) for (hh = 0; hh <= 2; hh++) {
    g = (hh == 0) ? c : c "|h" hh
    printf "CF %s %d %.6f %.6f %d\n", g, n[g], mean(g), mrate(g), mon[g] > GATES
  }
}
function later(a, b,   pa, pb) {
  pa = substr(a, 1, index(a, ":")); pb = substr(b, 1, index(b, ":"))
  if (pa == "score:" && pb == "score:") return substr(a, 7) + 0 > substr(b, 7) + 0
  return a > b
}
