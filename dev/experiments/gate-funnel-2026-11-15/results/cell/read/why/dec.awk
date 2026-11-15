# group fj.tsv rows by a key expression chosen by K; report open Fridays, free-net Fridays, X gross, X net, X ref and shares
function key(   h, f, a) {
  if (K=="trend") return $3
  if (K=="regime") return $5
  if (K=="held") { h=$7; return (h>=6) ? "6+" : h }
  if (K=="free") { f=$24; return (f>=0.99) ? "a:>=0.99 (all cash)" : (f>=0.5) ? "b:0.50-0.99" : (f>=0.3) ? "c:0.30-0.50" : (f>=0.0857) ? "d:m-0.30" : "e:<m" }
  if (K=="age") { a=$6; return (a<=4) ? "a:1-4" : (a<=13) ? "b:5-13" : (a<=26) ? "c:14-26" : "d:27+" }
  if (K=="bear") return ($2=="2000"||$2=="2001"||$2=="2002"||$2=="2008") ? "bear" : "other"
  if (K=="half") return ($2<=2012) ? "2000-12" : "2013-26"
  if (K=="trendreg") return $3 "/" $5
  return "all"
}
{ k=key(); N[k]++; if ($24>=0.0857) FN[k]++; XG[k]+=$27; XN[k]+=$28; XR[k]+=$31; tn++; txg+=$27; txn+=$28; txr+=$31 }
END { printf "%-22s %5s %6s %6s %6s %7s %7s %7s\n", K, "open", "share", "freeN", "XG", "XN", "XN%", "XNper"
  for (k in N) printf "%-22s %5d %5.1f%% %6d %6d %7d %6.1f%% %7.2f\n", k, N[k], 100*N[k]/tn, FN[k], XG[k], XN[k], 100*XN[k]/txn, XN[k]/N[k] }
