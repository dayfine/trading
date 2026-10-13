# Candidate short return minus an SPY short over the same two dates. Files: 1 SPY data.csv, 2 fwd.csv.
# Out: score,horizon,excess
NR == FNR { if (FNR > 1) sp[$1] = $6 + 0; next }
{ e0 = $4; if (!(e0 in sp)) next
  for (h = 0; h < 3; h++) { dd = $(6 + 2 * h); r = $(5 + 2 * h)
    if (dd in sp) printf "%s,%d,%.5f\n", $3, (h == 0 ? 20 : (h == 1 ? 60 : 120)), r - (-(sp[dd] / sp[e0] - 1)) } }
