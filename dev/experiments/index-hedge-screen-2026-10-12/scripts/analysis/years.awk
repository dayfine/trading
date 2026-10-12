# Year table from a days.awk table: SPY TR log, base log, and per gate the overlay log at h = 0.25 (sessions on) with the
# running ratio combined / base at each year-end, then the h = 0.5 overlay logs. In the pre-registered form the overlay
# does not depend on the base, so the overlay columns are the same for every salt; only the base column moves.
BEGIN { FS = ","; bw = 0.0025 / 252 }
{ y = substr($1, 1, 4); b[y] += log(1 + $2); sp[y] += log(1 + $3)
  for (g = 1; g <= 3; g++) { on = $(5 + g); for (k = 1; k <= 2; k++) { h = (k == 1 ? 0.25 : 0.5); ov[g, k, y] += log(1 - h * on * $3) - (($5 && on) ? h * bw : 0) }; if (on) dn[g, y] += $5 } }
END { printf "%-4s %8s %8s | %-26s | %-26s | %-26s | %s\n", "year", "SPY TR", "base", "G1 h.25 (sess) ratio", "G2 h.25 (sess) ratio", "G3 h.25 (sess) ratio", "h=0.5: G1 G2 G3"
  for (y = 2000; y <= 2026; y++) { printf "%4d %+8.4f %+8.4f |", y, sp[y], b[y]
    for (g = 1; g <= 3; g++) { c[g] += ov[g, 1, y]; printf " %+8.4f (%3d) %6.3f   |", ov[g, 1, y], dn[g, y], exp(c[g]) }
    printf " %+.4f %+.4f %+.4f\n", ov[1, 2, y], ov[2, 2, y], ov[3, 2, y] } }
