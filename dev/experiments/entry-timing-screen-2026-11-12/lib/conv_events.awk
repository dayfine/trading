# conv_events.awk -- k0 conversion events: the first No_structural_stop skip of each run of a symbol. A new run starts
# when more than 35 days have passed since that symbol's previous skip.
# usage: awk -F'\t' '$3 == "No_structural_stop" { print $2 "\t" $1 }' decisions.tsv | sort -k1,1 -k2,2 | awk -F'\t' -f conv_events.awk
# in: sym date (sorted by symbol, then date); out: seed date sym nav kind  (nav unused by conv.awk; kind "skip")
function dn(d,   y, m, dd) { y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd }
{ if ($1 != ps || dn($2) - dn(pd) > 35) print "0\t" $2 "\t" $1 "\t0\tskip"; ps = $1; pd = $2 }
