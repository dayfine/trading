# reclass.awk: re-implementation of our Stage.classify (default config) over the chart's weekly closes, plus
# perturbations, to decompose the reader-vs-ours disagreement. Not our code: a check of what each ingredient does.
# Usage: awk -F, -v sym=SYM -v start=1998-01-01 -f reclass.awk weekly/SYM.csv
# Variants (one output column each):
#   v0: WMA30, slope 4w, +-0.5%, confirm 6           (should reproduce stages/<SYM>.csv)
#   v1: SMA30 (the chart's MA), slope 4w, +-0.5%
#   v2: SMA30, slope 5w, +-1.0%                        (the rule card's MA reading, ambiguity 2)
#   v3: v2 + zone: entering Stage 2 needs a close above the prior 26-week closing high (base top proxy);
#       entering Stage 4 needs a close below the prior 26-week closing low (support proxy)
#   v4: v0 (WMA, ours) + the same zone requirement
# Output: week,v0,v1,v2,v3,v4
FNR == 1 { next }
$1 >= start { n++; wk[n] = $1; c[n] = $5 + 0; hh[n] = $3 + 0; ll[n] = $4 + 0 }
function wmaf(i,   s, w, j) { s = 0; w = 0; for (j = 1; j <= 30; j++) { s += j * c[i - 30 + j]; w += j }; return s / w }
function smaf(i,   s, j) { s = 0; for (j = 0; j < 30; j++) s += c[i - j]; return s / 30 }
# one classification step; returns new stage number given prior stage p (1-4)
function step(i, p, ma, lb, thr, zone,   cur, back, k, dir, slope, above, ex, below, hi, lo, j, s) {
  if (i < 30) return 1
  cur = ma[i]
  k = lb; while (i - k < 30) k--          # walk back to the largest defined offset
  back = ma[i - k]
  slope = (back == 0) ? 0 : (cur - back) / (back < 0 ? -back : back)
  dir = (slope > thr) ? 1 : (slope < -thr) ? -1 : 0
  above = 0; ex = 0
  for (j = 0; j < 6 && i - j >= 30; j++) { ex++; if (c[i - j] > ma[i - j]) above++ }
  below = ex - above
  if (zone) { hi = 0; lo = 1e18; for (j = 1; j <= zn && i - j >= 1; j++) { xh = (zmode == "hl") ? hh[i - j] : c[i - j]; xl = (zmode == "hl") ? ll[i - j] : c[i - j]; if (xh > hi) hi = xh; if (xl < lo) lo = xl } }
  if (dir == 1 && above > below) {
    if (zone && p != 2 && p != 3 && c[i] <= hi) return p    # no breakout above the base top yet: stay
    return 2
  }
  if (dir == -1 && below > above) {
    if (zone && p == 3 && c[i] >= lo) return 3             # top not broken yet: stay Stage 3
    if (zone && p == 2 && c[i] >= lo) return 3
    return 4
  }
  if (dir == 0) return (p == 1 || p == 4) ? 1 : 3
  if (dir == 1 && p == 1) return 1
  if (dir == -1 && p == 3) return 3
  return p
}
END {
  for (i = 30; i <= n; i++) { W[i] = wmaf(i); S[i] = smaf(i) }
  p0 = p1 = p2 = p3 = p4 = 1
  print "week,v0,v1,v2,v3,v4"
  for (i = 1; i <= n; i++) {
    p0 = step(i, p0, W, 4, 0.005, 0)
    p1 = step(i, p1, S, 4, 0.005, 0)
    p2 = step(i, p2, S, 5, 0.010, 0)
    p3 = step(i, p3, S, 5, 0.010, 1)
    p4 = step(i, p4, W, 4, 0.005, 1)
    print wk[i] "," p0 "," p1 "," p2 "," p3 "," p4
  }
}
