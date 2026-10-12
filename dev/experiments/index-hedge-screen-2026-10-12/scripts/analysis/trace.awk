# Named windows traced end to end from a days.awk table: SPY TR log (and %), base log, and for G1 / G2 the SPY sessions
# on, the h = 1 short log and the h = 0.25 overlay log (with borrow) over each window [from, to].
BEGIN { FS = ","; nw = split("2020-03-23:2020-06-05 2008-06-30:2009-03-09 2009-03-10:2009-04-24 2025-03-31:2025-04-08 2025-04-09:2025-05-16 2025-04-14:2025-05-02 2026-03-30:2026-04-17 2024-11-27:2026-06-24 2022-01-03:2022-10-12", W, " ")
  for (i = 1; i <= nw; i++) { split(W[i], a, ":"); A[i] = a[1]; B[i] = a[2] } }
{ for (i = 1; i <= nw; i++) if ($1 >= A[i] && $1 <= B[i]) { bl[i] += log(1 + $2); sp[i] += log(1 + $3)
    for (g = 1; g <= 2; g++) if ($(5 + g)) { n[i, g] += $5; s1[i, g] += log(1 - $3); s25[i, g] += log(1 - 0.25 * $3) - ($5 ? 0.25 * 0.0025 / 252 : 0) } } }
END { for (i = 1; i <= nw; i++) printf "%s..%s: SPY %+.4f (%+.1f%%) base %+.4f | G1 %3d sess short_h1 %+.4f overlay_h025 %+.4f | G2 %3d sess short_h1 %+.4f overlay_h025 %+.4f\n", \
  A[i], B[i], sp[i], 100 * (exp(sp[i]) - 1), bl[i], n[i, 1], s1[i, 1], s25[i, 1], n[i, 2], s1[i, 2], s25[i, 2] }
