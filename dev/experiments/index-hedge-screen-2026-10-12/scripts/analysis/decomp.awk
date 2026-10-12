# Overlay cost decomposition at h = 0.25 from a days.awk table (sessions with the gate on):
#   ln(1 - h r) = -h ln(1 + r_px) - h (r - r_px) - (h/2 + h^2/2) r^2 + O(r^3), r = TR return
# i.e. SPY's compounded price move while short, the dividends the short pays, the variance terms of a short rebalanced
# to h x NAV every day, plus borrow (0.25 %/yr per session). The sum is checked against the exact overlay log.
BEGIN { FS = ","; h = 0.25 }
$5 { na++; sa += $3; sva += $3 * $3; for (g = 1; g <= 3; g++) if ($(5 + g)) { lp[g] += log(1 + $4); v[g] += $3 * $3; dv[g] += $3 - $4; n[g]++; ov[g] += log(1 - h * $3) - h * 0.0025 / 252; sr[g] += $3 } }
END { printf "all SPY sessions: %d, SPY TR mean %+.3f %%/yr arith, mean r^2 %.6f\n", na, 100 * 252 * sa / na, sva / na
  for (g = 1; g <= 3; g++) { a = -h * lp[g]; b = -(h / 2 + h * h / 2) * v[g]; c = -h * dv[g]; d = -h * 0.0025 * n[g] / 252
  printf "G%d: sessions %d, SPY TR mean %+.3f %%/yr arith | price log move %+.4f -> %+.4f | variance terms %+.4f | dividends %+.4f | borrow %+.4f | sum %+.4f | exact %+.4f\n", \
    g, n[g], 100 * 252 * sr[g] / n[g], lp[g], a, b, c, d, a + b + c + d, ov[g] } }
