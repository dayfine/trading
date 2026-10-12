# Base drawdowns deeper than 8 % from an equity curve (date,value): peak date, trough date, depth, recovery date.
BEGIN { FS = "," }
FNR > 1 { d = $1; v = $2 + 0
  if (v > pk) { if (inn && mdd > 0.08) printf "DD %.2f%% peak %s trough %s recovered %s\n", 100 * mdd, pkd, trd, d; pk = v; pkd = d; mdd = 0; inn = 0 }
  else { dd = 1 - v / pk; if (dd > mdd) { mdd = dd; trd = d } inn = 1 } }
END { if (mdd > 0.08) printf "DD %.2f%% peak %s trough %s (open at the end, %s)\n", 100 * mdd, pkd, trd, d }
