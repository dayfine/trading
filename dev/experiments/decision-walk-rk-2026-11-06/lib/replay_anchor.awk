# First-order replay of a peak-following correction anchor (`correction_must_follow_peak`) inside each position's
# longest stale-anchor stretch (stale_anchor.tsv), where the run itself completed no cycle and the stop stayed flat.
# From the first stale row to the actual exit, on daily raw bars: track the peak close since the last cycle and the
# lowest low since that peak; a cycle completes when the pullback is >= 8 % and a close recovers to the peak; its
# candidate is 0.99 * min(pullback low, MA), MA = the run's own (adjusted) value from the last stop-decision row before
# that day, times F (F=1: the run's mixed basis; F=factor: also same-basis, as stop_ma_same_basis would).
# The hypothetical stop = max(actual stop, candidates); exit at min(open, stop) on the first bar whose low reaches it.
# Inputs: trades.csv, stale_anchor.tsv, stopdec_bars.tsv (sorted sym, pid, date). Var SAME=0|1. Needs ./data.
# Output: pid sym stale_start actual_exit actual_px hyp_exit hyp_px qty delta_usd n_cycles n_raises
function load(sym,  f, line, a) { delete BD; delete BO; delete BL; delete BC; delete BA; nb = 0; f = "data/" substr(sym, 1, 1) "/" substr(sym, length(sym), 1) "/" sym "/data.csv"
  while ((getline line < f) > 0) { if (line ~ /^date/) continue; split(line, a, ","); if (a[5] + 0 <= 0) continue; nb++; BD[nb] = a[1]; BO[nb] = a[2]; BL[nb] = a[4]; BC[nb] = a[5]; BA[nb] = a[6] } close(f) }
function run(p,   k, j, d, peak, low, stop, hyp, he, hp, nc, nr, cand, ma, f) {
  if (!(p in ST) || !(p in XD)) return
  load(SY[p]); stop = SA[p]; hyp = stop; peak = ""; low = ""; he = ""; nc = 0; nr = 0; j = 0
  for (k = 1; k <= nb; k++) {
    d = BD[k]; if (d < ST[p]) continue; if (d > XD[p]) break
    if (hyp > stop + 1e-9 && BL[k] + 0 <= hyp) { he = d; hp = (BO[k] + 0 < hyp) ? BO[k] + 0 : hyp; break }
    while (j < NRW[p] && RD[p, j + 1] <= d) j++
    if (peak == "") { peak = BC[k] + 0; low = BC[k] + 0; continue }
    if (BL[k] + 0 < low) low = BL[k] + 0
    if ((peak - low) / peak >= 0.08 && BC[k] + 0 >= peak) {
      nc++; ma = RMA[p, j]; f = (SAME == 1) ? BC[k] / BA[k] : 1
      cand = 0.99 * ((low < ma * f) ? low : ma * f)
      if (cand > hyp + 1e-9) { hyp = cand; nr++ }
      peak = BC[k] + 0; low = BC[k] + 0
    } else if (BC[k] + 0 > peak) { peak = BC[k] + 0; low = BC[k] + 0 }
  }
  if (he == "") { he = XD[p]; hp = XP[p] }
  printf "%s\t%s\t%s\t%s\t%.4f\t%s\t%.4f\t%d\t%.2f\t%d\t%d\n", p, SY[p], ST[p], XD[p], XP[p], he, hp, QT[p], QT[p] * (hp - XP[p]), nc, nr
}
FILENAME ~ /trades.csv$/ { if (FNR > 1) { split($0, t, ","); XD[t[20]] = t[4]; XP[t[20]] = t[7]; QT[t[20]] = t[8] } next }
FILENAME ~ /stale_anchor/ { split($0, t, "\t"); ST[t[1]] = t[3]; SY[t[1]] = t[2]; next }
{ split($0, t, "\t"); p = t[1]; NRW[p]++; RD[p, NRW[p]] = t[3]; RMA[p, NRW[p]] = t[13] + 0
  if ((p in ST) && t[3] == ST[p]) SA[p] = t[7] + 0 }
END { for (p in ST) run(p) }
