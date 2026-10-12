# Ledger aggregates for the pre-registered overlay (product form), computed the simulator's way so the base row
# reproduces actual.sexp: total return % vs initial cash, max DD %, Calmar = CAGR / max DD (years from the run's
# start_date), Sharpe = mean / population std x sqrt 252 of the per-row return in excess of the record's cash yield
# (DTB3 - 10 bp floored at 0, ACT/360 over the calendar days between rows), over EVERY equity-curve row, as
# Sharpe_computer does (it marks each step with market bars; the curve's 236 US-holiday rows are such steps).
# Inputs: DTB3 csv, days.awk table.  -v v0=<first curve value> -v init=<initial cash> -v start=<start_date> -v first=<first curve date>
BEGIN { FS = "," }
FILENAME == ARGV[1] { if (FNR > 1 && $2 != "." && $2 != "") { nr++; RD[nr] = $1; RV[nr] = $2 + 0 } next }
function jd(d,   y, m, dd, a, y2, m2) { y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return dd + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function rate_on(j,   x) { while (r < nr && jd(RD[r+1]) <= j) r++; x = (RV[r] - 0.10) / 100; return x < 0 ? 0 : x }
function hof(k) { return (((k - 1) % 3) == 0) ? 0.25 : ((((k - 1) % 3) == 1) ? 0.5 : 1.0) }
FNR == 1 { pd = first }
{ rf = 0; for (j = jd(pd) + 1; j <= jd($1); j++) rf += rate_on(j) / 360; pd = $1; n++; last = $1
  for (k = 0; k <= 9; k++) { if (k == 0) x = $2; else { g = int((k - 1) / 3) + 1; h = hof(k); on = $(5 + g); x = (1 + $2) * (1 - h * on * $3) * exp(-(($5 && on) ? h * 0.0025 / 252 : 0)) - 1 }
    L[k] += log(1 + x); nav = exp(L[k]); if (nav > pk[k]) { pk[k] = nav; pkd[k] = $1 } if (pk[k] < 1) pk[k] = 1; if (1 - nav / pk[k] > mx[k]) { mx[k] = 1 - nav / pk[k]; mxp[k] = pkd[k]; mxt[k] = $1 }
    e = x - rf; s[k] += e; s2[k] += e * e } }
END { yrs = (jd(last) - jd(start)) / 365.25; f0 = v0 / init
  for (k = 0; k <= 9; k++) { lab = (k == 0) ? "base" : sprintf("G%d h=%s", int((k - 1) / 3) + 1, hof(k))
    mu = s[k] / n; sd = sqrt(s2[k] / n - mu * mu); tot = f0 * exp(L[k]); cagr = exp(log(tot) / yrs) - 1
    printf "%-9s return %8.2f%%  maxdd %6.2f%% (%s -> %s)  calmar %.4f  sharpe %.4f\n", lab, 100 * (tot - 1), 100 * mx[k], (mxp[k] == "" ? first : mxp[k]), mxt[k], cagr / mx[k], mu / sd * sqrt(252) } }
