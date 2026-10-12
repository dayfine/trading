# Estimand sensitivities from a days.awk table, every gate x h, scored on the four rule numbers (d_log, combined max DD
# vs base, bears beaten). NOT the pre-registered formula -- that is overlay.awk.
#   sum    ln(1 + rb - e rs - borrow): the short sized at h x the COMBINED NAV at t-1 with the long book's per-NAV
#          return unchanged (the plan's sizing sentence; the pre-registered product form adds the cross term -e rb rs)
#   static the short is sized at h x NAV at the first gate-on close and held to the last on-day, not rebalanced; the
#          long book runs N0 x V_t / V_t0; short proceeds earn nothing; borrow 0.25 %/yr of the initial notional per
#          session (a held futures / short-sale position, Ch. 9's vehicle)
# -v form=sum|static
BEGIN { FS = ","; split("0.25 0.5 1.0", H, " "); split("2000-03-24 2007-10-09 2022-01-03", bs, " "); split("2002-10-09 2009-03-09 2022-10-12", be, " ")
  for (g = 1; g <= 3; g++) for (k = 1; k <= 3; k++) { N[g, k] = 1; pk[g, k] = 1 } bpk = 1 }
{ lb = log(1 + $2); bl += lb; B = exp(bl); if (B > bpk) bpk = B; if (1 - B / bpk > bmx) bmx = 1 - B / bpk
  for (q = 1; q <= 3; q++) inb[q] = ($1 >= bs[q] && $1 <= be[q]); for (q = 1; q <= 3; q++) if (inb[q]) bb[q] += lb
  for (g = 1; g <= 3; g++) { on = $(5 + g)
    for (k = 1; k <= 3; k++) { h = H[k]; pre = N[g, k]
      if (form == "sum") N[g, k] = pre * (1 + $2 - h * on * $3 - (($5 && on) ? h * 0.0025 / 252 : 0))
      else { if (on && !ep[g, k]) { ep[g, k] = 1; N0[g, k] = pre; L[g, k] = 1; Pr[g, k] = 1; bo[g, k] = 0 }
        if (on) { L[g, k] *= (1 + $2); Pr[g, k] *= (1 + $3); if ($5) bo[g, k] += h * 0.0025 / 252; N[g, k] = N0[g, k] * (L[g, k] - h * (Pr[g, k] - 1) - bo[g, k]) }
        else { ep[g, k] = 0; N[g, k] = pre * (1 + $2) } }
      for (q = 1; q <= 3; q++) if (inb[q]) cb[g, k, q] += log(N[g, k] / pre)
      if (N[g, k] > pk[g, k]) pk[g, k] = N[g, k]; if (1 - N[g, k] / pk[g, k] > mx[g, k]) mx[g, k] = 1 - N[g, k] / pk[g, k] } } }
END { printf "form %s: base log %.4f maxdd %.2f%%\n", form, bl, 100 * bmx
  for (g = 1; g <= 3; g++) for (k = 1; k <= 3; k++) { nb = 0; for (q = 1; q <= 3; q++) if (cb[g, k, q] > bb[q]) nb++; dl = log(N[g, k]) - bl; dd = 100 * (bmx - mx[g, k])
    printf "G%d h=%s d_log %+.4f maxdd %.2f%% d_dd %+.2fpp bears %+.4f %+.4f %+.4f beats %d/3 c1 %d c2 %d c3 %d\n", g, H[k], dl, 100 * mx[g, k], dd, \
      cb[g, k, 1] - bb[1], cb[g, k, 2] - bb[2], cb[g, k, 3] - bb[3], nb, (dl >= -0.05), (dd >= 3), (nb >= 2) } }
