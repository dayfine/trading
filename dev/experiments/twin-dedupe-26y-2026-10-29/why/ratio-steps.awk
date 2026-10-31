# Daily ln(NAV_dd / NAV_cur) from the two equity_curve.csv files, and every day it moves by more than STEP (default 0.002).
# Usage: awk -F, [-v STEP=0.002] -f ratio-steps.awk cur-equity_curve.csv dd-equity_curve.csv
BEGIN { if (STEP == "") STEP = 0.002 }
FNR == 1 { next }
NR == FNR { c[$1] = $2; next }
($1 in c) { r = log($2 / c[$1]); if (seen && (r - p > STEP || p - r > STEP)) printf "%s %+.4f (level %+.4f)\n", $1, r - p, r; p = r; seen = 1; last = $1 }
END { printf "END %s level %+.4f\n", last, p }
