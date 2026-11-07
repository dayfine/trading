# fwd.tsv (date sym r13 r26 r52) + decisions.tsv (date sym outcome dist) -> paired per-week comparison, and
# "outcome<TAB>value" / "outcome|era<TAB>value" rows on stdout for qstats.awk. H = fwd column (3 r13, 4 r26, 5 r52).
function era(y) { return (y < 2009 ? "2000-08" : (y < 2020 ? "2009-19" : "2020-26")) }
NR == FNR { r[$1 "|" $2] = $H; next }
{ k = $1 "|" $2; if (!(k in r) || r[k] == "NA") next; o = $3; if (o == "Share_class_held") next
  W[$1, o] += r[k]; WN[$1, o]++; WE[$1] = era(substr($1, 1, 4))
  print o "\t" r[k]; print o "|" WE[$1] "\t" r[k] }
END {
  split("Placed Insufficient_cash No_structural_stop Sized_to_zero", O, " "); split("2000-08 2009-19 2020-26", E, " ")
  for (i = 2; i <= 4; i++) { a = O[i]; delete pw; delete pb; delete dsum
    for (w in WE) if (WN[w, "Placed"] > 0 && WN[w, a] > 0) { d = W[w, "Placed"] / WN[w, "Placed"] - W[w, a] / WN[w, a]; pw[WE[w]]++; dsum[WE[w]] += d; if (d > 0) pb[WE[w]]++ }
    printf "PAIRED placed vs %s:", a > "/dev/stderr"
    for (j = 1; j <= 3; j++) printf " %s %d/%d weeks placed ahead (%.0f%%), mean diff %+.1f pp;", E[j], pb[E[j]], pw[E[j]], (pw[E[j]] ? 100 * pb[E[j]] / pw[E[j]] : 0), (pw[E[j]] ? 100 * dsum[E[j]] / pw[E[j]] : 0) > "/dev/stderr"
    print "" > "/dev/stderr" }
  delete pw; delete pb; delete dsum
  for (w in WE) { na = 0; sa = 0; for (i = 2; i <= 4; i++) { na += WN[w, O[i]]; sa += W[w, O[i]] }
    if (WN[w, "Placed"] > 0 && na > 0) { d = W[w, "Placed"] / WN[w, "Placed"] - sa / na; pw[WE[w]]++; dsum[WE[w]] += d; if (d > 0) pb[WE[w]]++ } }
  printf "PAIRED placed vs ALL top-N alternatives (09-26 method):" > "/dev/stderr"
  for (j = 1; j <= 3; j++) printf " %s %d/%d (%.0f%%), mean diff %+.1f pp;", E[j], pb[E[j]], pw[E[j]], (pw[E[j]] ? 100 * pb[E[j]] / pw[E[j]] : 0), (pw[E[j]] ? 100 * dsum[E[j]] / pw[E[j]] : 0) > "/dev/stderr"
  print "" > "/dev/stderr"
}
