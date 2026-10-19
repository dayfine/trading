# pool_pick.awk: the step-B pool from pool_scan.awk's numbers (see pool.sh for the rules).
# Usage: awk -F, -v g="A|B" -v nh=0.25 -v floor=1e6 -v unk=1 -v max=120 -v seed=N -v side=long|short -f pool_pick.awk \
#          <ours.txt> <sectors.csv> <scan.csv>
# Prints pool.csv: pseudo,symbol,src,sector, in a random order.
BEGIN { srand(seed); ng = split(g, gs, "|"); for (i = 1; i <= ng; i++) want[gs[i]] = 1 }
{ fi = (FILENAME == ARGV[ARGC - 3]) ? 1 : (FILENAME == ARGV[ARGC - 2]) ? 2 : 3 }   # by name: an empty ours.txt has no FNR == 1
fi == 1 { ours[$1] = 1; next }
fi == 2 { if (FNR > 1) sec[$1] = $2; next }
{
  s = $1; sc = (s in sec) ? sec[s] : ""
  if (s in ours) { no++; po[no] = s; next }
  if ($5 + 0 < floor) next
  if (s ~ /-(W|WS|WT|U|UN|R|RT)$/) next                              # warrants, units, rights: not common stock
  if (side == "short") { if ($3 + 0 > (1 + nh) * $6) next }   # shorts: within nh of the 52-week low
  else if ($3 + 0 < (1 - nh) * $4) next                          # longs: within nh of the 52-week high
  if (sc == "") { if (unk != 1) next }
  else if (g != "all" && !(sc in want)) next
  nf++; pf[nf] = s
}
END {
  k = 0
  for (i = 1; i <= no && k < max; i++) { k++; sym[k] = po[i]; src[k] = "ours" }
  # Random fill: a partial Fisher-Yates over the filter passers.
  for (i = 1; i <= nf && k < max; i++) {
    j = i + int(rand() * (nf - i + 1)); t = pf[i]; pf[i] = pf[j]; pf[j] = t
    k++; sym[k] = pf[i]; src[k] = "filter"
  }
  for (i = 1; i <= k; i++) { j = i + int(rand() * (k - i + 1)); t = sym[i]; sym[i] = sym[j]; sym[j] = t; t = src[i]; src[i] = src[j]; src[j] = t }
  for (i = 1; i <= k; i++) used[sym[i]] = 1
  used["SPY"] = 1
  print "pseudo,symbol,src,sector"
  for (i = 1; i <= k; i++) {
    do { p = ""; for (c = 1; c <= 4; c++) p = p substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", 1 + int(rand() * 26), 1) } while (p in used)
    used[p] = 1
    print p "," sym[i] "," src[i] "," ((sym[i] in sec) ? sec[sym[i]] : "")
  }
}
