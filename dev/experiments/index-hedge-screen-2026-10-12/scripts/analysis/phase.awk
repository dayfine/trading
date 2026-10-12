# Overlay log at h = 0.25 (pre-registered daily-rebalanced form, 0.25 %/yr borrow per session) split three ways, from a
# days.awk table:
#   phase  bear-leg = inside a bear (peak, trough]; post-trough = (trough, -v post end]; other = everything else.
#          Bears: the three Phase B windows + COVID (2020-02-19 -> 2020-03-23, not a rule window; it carries the V).
#   regime the pack regime of the day (lagged one ISO week, days.awk column 9)
#   period 2000-02 / 2003-07 / 2008-09 / 2010-19 / 2020-21 / 2022-23 / 2024-26
# -v post="<4 post-trough window ends, space-separated>" (default: 6 months after each trough)
BEGIN { FS = ","; nb = split("2000-03-24:2002-10-09 2007-10-09:2009-03-09 2020-02-19:2020-03-23 2022-01-03:2022-10-12", bw, " ")
  if (post == "") post = "2003-04-09 2009-09-09 2020-09-23 2023-04-12"; split(post, pe, " ")
  for (i = 1; i <= nb; i++) { split(bw[i], a, ":"); P[i] = a[1]; T[i] = a[2] } h = 0.25 }
function phase(d,  i) { for (i = 1; i <= nb; i++) { if (d > P[i] && d <= T[i]) return "bear-leg"; if (d > T[i] && d <= pe[i]) return "post-trough" } return "other" }
function per(d,  y) { y = substr(d, 1, 4) + 0
  return y <= 2002 ? "2000-02" : (y <= 2007 ? "2003-07" : (y <= 2009 ? "2008-09" : (y <= 2019 ? "2010-19" : (y <= 2021 ? "2020-21" : (y <= 2023 ? "2022-23" : "2024-26"))))) }
{ ph = phase($1); pr = per($1); r = $9
  for (g = 1; g <= 3; g++) { if (!$(5 + g)) continue
    o = log(1 - h * $3) - ($5 ? h * 0.0025 / 252 : 0)
    A[g, ph] += o; Ad[g, ph] += $5; B[g, ph, r] += o; Bd[g, ph, r] += $5; C[g, pr, r] += o; Cd[g, pr, r] += $5; Ct[g, pr] += o; Ctd[g, pr] += $5 } }
END { split("bear-leg post-trough other", PH, " "); split("UP MIXED DOWN", RR, " "); split("2000-02 2003-07 2008-09 2010-19 2020-21 2022-23 2024-26", PP, " ")
  printf "post-trough windows end %s\n", post
  for (g = 1; g <= 3; g++) {
    printf "\nG%d h=0.25 overlay log (SPY sessions) by phase:", g; for (i = 1; i <= 3; i++) printf "  %s %+.4f (%d)", PH[i], A[g, PH[i]], Ad[g, PH[i]]
    printf "\n  phase x regime:"; for (i = 1; i <= 3; i++) for (j = 1; j <= 3; j++) if (Bd[g, PH[i], RR[j]]) printf "  %s/%s %+.4f (%d)", PH[i], RR[j], B[g, PH[i], RR[j]], Bd[g, PH[i], RR[j]]
    printf "\n  period x regime:\n"
    for (k = 1; k <= 7; k++) { printf "    %s total %+.4f (%3d)", PP[k], Ct[g, PP[k]], Ctd[g, PP[k]]
      for (j = 1; j <= 3; j++) printf "   %s %+.4f (%3d)", RR[j], C[g, PP[k], RR[j]], Cd[g, PP[k], RR[j]]; print "" } } }
