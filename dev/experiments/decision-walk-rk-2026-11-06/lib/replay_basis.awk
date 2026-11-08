# First-order per-trade replay of `stop_ma_same_basis` (#2982) on one run, from its own stop decisions.
#
# With reset_anchor_on_stalled_cycle on (the record), a stalled cycle resets the anchor exactly as a raise does, so the
# dates of completed correction cycles do not depend on the stop level. Restating the MA on the raw basis therefore
# changes only the candidate of each completed cycle: c' = 0.99 * min(correction extreme, MA * close/adjusted_close).
# The hypothetical stop is max(actual stop, running max of c'), and the position is walked on daily raw bars until its
# low reaches that stop (fill at min(open, stop), the trigger-bar fill rule) or the actual exit comes first.
# Ignored: round-number nudge, portfolio feedback (freed cash is not redeployed, other positions unchanged), dividends.
# Excluded: positions whose stop was split-rescaled during the hold (raw basis breaks), open positions.
#
# Inputs (in order): trades.csv (FS ","), stopdec_bars.tsv sorted by sym, pid, date (FS "\t"). Needs ./data.
# Output: one line per closed position:
#  pid sym fill exit kind qty ep xp act_pct hyp_exit_date hyp_px hyp_pct delta_usd n_cycles_raised_by_fix max_gap
function load(sym,  f, line, a) { delete BD; delete BO; delete BL; nb = 0; f = "data/" substr(sym, 1, 1) "/" substr(sym, length(sym), 1) "/" sym "/data.csv"
  while ((getline line < f) > 0) { if (line ~ /^date/) continue; split(line, a, ","); if (a[5] + 0 <= 0) continue; nb++; BD[nb] = a[1]; BO[nb] = a[2]; BL[nb] = a[4] } close(f) }
function process(   i, k, H, act, hyp, ncr, first, d, j, he, hp, eff_h, eff_a, r, cand, ref, mx) {
  if (np == 0 || !(cur in XD)) return
  if (split_seen) { nsplit++; return }
  # stop path per row: actual stop_after and hypothetical stop after the row
  H = 0; ncr = 0; mx = 1
  for (i = 1; i <= np; i++) {
    if (RR[i] == "Raised" || RR[i] == "Cycle_stalled") {
      ref = RM[i] * RF[i]; if (RC[i] + 0 < ref) ref = RC[i] + 0; cand = 0.99 * ref
      if (cand > H) H = cand
      if (cand > RA[i] + 1e-9 && cand > RB[i] + 1e-9) ncr++
      if (RF[i] > mx) mx = RF[i]
    }
    HY[i] = (H > RA[i]) ? H : RA[i]
  }
  # daily walk from the day after the fill to the actual exit
  sym = RSY[1]; if (sym != loaded) { load(sym); loaded = sym }
  j = 0; he = ""; hp = ""
  for (k = 1; k <= nb; k++) {
    d = BD[k]; if (d <= FD[cur]) continue; if (d > XD[cur]) break
    while (j < np && RDt[j + 1] < d) j++
    if (j == 0) continue
    eff_h = HY[j]; eff_a = RA[j]
    if (eff_h > eff_a + 1e-9 && BL[k] + 0 <= eff_h) { he = d; hp = (BO[k] + 0 < eff_h) ? BO[k] + 0 : eff_h; break }
  }
  if (he == "") { he = XD[cur]; hp = XP[cur] }
  printf "%s\t%s\t%s\t%s\t%s\t%d\t%.4f\t%.4f\t%.4f\t%s\t%.4f\t%.4f\t%.2f\t%d\t%.3f\n", cur, sym, FD[cur], XD[cur], XK[cur], QT[cur], EP[cur], XP[cur], XP[cur] / EP[cur] - 1, he, hp, hp / EP[cur] - 1, QT[cur] * (hp - XP[cur]), ncr, mx
}
FNR == 1 && FILENAME ~ /trades.csv$/ { FS = ","; next }
FILENAME ~ /trades.csv$/ { split($0, t, ","); p = t[20]; FD[p] = t[3]; XD[p] = t[4]; XK[p] = t[13]; QT[p] = t[8]; EP[p] = t[6]; XP[p] = t[7]; next }
{ split($0, t, "\t")
  if (t[1] != cur) { process(); cur = t[1]; np = 0; split_seen = 0; prev_after = "" }
  if (prev_after != "" && (t[6] + 0 > prev_after * 1.0001 || t[6] + 0 < prev_after * 0.9999)) split_seen = 1
  np++; RSY[np] = t[2]; RDt[np] = t[3]; RB[np] = t[6] + 0; RA[np] = t[7] + 0; RC[np] = t[12]; RM[np] = t[13] + 0; RR[np] = t[14]; RF[np] = t[18] + 0
  prev_after = t[7] + 0 }
END { process(); print "# split-rescaled positions excluded: " nsplit > "/dev/stderr" }
