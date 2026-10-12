# Exit whipsaw check from a days.awk table: SPY's TR log move over the K sessions after each gate turns off (the cover),
# for K = 3 / 5 / 10 / 20, with the count of covers followed by a decline and the single largest contributor.
# -v g=6|7|8 (G1|G2|G3)
BEGIN { FS = "," }
$5 { n++; r[n] = $3; on[n] = $(g); d[n] = $1 }
END { split("3 5 10 20", KS, " ")
  for (q = 1; q <= 4; q++) { K = KS[q]; nx = 0; a = 0; dn = 0; m1 = 0; l1 = ""
    for (i = 2; i <= n; i++) if (!on[i] && on[i-1]) { nx++; s = 0; for (j = i; j < i + K && j <= n; j++) s += log(1 + r[j]); a += s; if (s < 0) dn++; if (s < m1) { m1 = s; l1 = d[i] } }
    printf "G%d K=%2d: SPY log after %d covers: sum %+.4f, down after %d; largest %s %+.4f; sum without it %+.4f\n", g - 5, K, nx, a, dn, l1, m1, a - m1 } }
