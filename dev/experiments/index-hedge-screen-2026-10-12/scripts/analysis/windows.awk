# Overlay inside the base's four ~20 % drawdowns and the three rule bears, from a days.awk table, h = 0.25.
# Per window (start, end]: SPY TR log, base log, base max DD inside the window (peak starts at the window start), and per
# gate the SPY sessions on, the overlay log and the combined max DD inside the window.
BEGIN { FS = ","; nw = split("2007-07-12:2010-02-04 2018-09-14:2020-03-23 2021-06-01:2023-10-27 2024-11-26:2026-06-24 2000-03-24:2002-10-09 2007-10-09:2009-03-09 2022-01-03:2022-10-12", ww, " ")
  for (i = 1; i <= nw; i++) { split(ww[i], a, ":"); ws[i] = a[1]; we[i] = a[2]; bp[i] = 1; for (g = 1; g <= 3; g++) cp[i, g] = 1 } h = 0.25 }
{ for (i = 1; i <= nw; i++) if ($1 > ws[i] && $1 <= we[i]) {
    lb = log(1 + $2); bl[i] += lb; sp[i] += log(1 + $3); bn = exp(bl[i]); if (bn > bp[i]) bp[i] = bn; if (1 - bn / bp[i] > bx[i]) bx[i] = 1 - bn / bp[i]
    for (g = 1; g <= 3; g++) { on = $(5 + g); o = log(1 - h * on * $3) - (($5 && on) ? h * 0.0025 / 252 : 0)
      ov[i, g] += o; c[i, g] += lb + o; nv = exp(c[i, g]); if (nv > cp[i, g]) cp[i, g] = nv; if (1 - nv / cp[i, g] > cx[i, g]) cx[i, g] = 1 - nv / cp[i, g]; if (on) nd[i, g] += $5 } } }
END { printf "%-24s %8s %8s %7s | %-27s | %-27s | %s\n", "window", "SPY log", "base log", "base DD", "G1: sessions overlay DD", "G2: sessions overlay DD", "G3: sessions overlay DD"
  for (i = 1; i <= nw; i++) { printf "%-24s %+8.4f %+8.4f %6.2f%% |", ws[i] "->" we[i], sp[i], bl[i], 100 * bx[i]
    for (g = 1; g <= 3; g++) printf " %4d %+8.4f %6.2f%% |", nd[i, g], ov[i, g], 100 * cx[i, g]; print "" } }
