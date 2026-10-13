# Top width (weeks of Stage 3 before the break) as a response shape; the >20-week cell in detail.
function bw(w) { return (w <= 1) ? "w01" : (w <= 2 ? "w02" : (w <= 3 ? "w03" : (w <= 5 ? "w04-05" : (w <= 8 ? "w06-08" : (w <= 12 ? "w09-12" : (w <= 20 ? "w13-20" : "w21+")))))) }
NR==1 { hdr(); next }
{ w = $(c["top_width"]) + 0; b = bw(w); tw[b]++; ntot++; h = (substr($2,1,4) + 0 <= 2012 ? "h1" : "h2")
  add(b " e1 O1+120", $(c["e1_o1_120"])); add(b " e1 O2", $(c["e1_o2_exc"])); add(b " e2 O2", $(c["e2_o2_exc"]))
  if (w > 20) { add("w21+ e1 O2 " h, $(c["e1_o2_exc"])); add("w21+ e2 O2 " h, $(c["e2_o2_exc"])); add("w21+ e1 O1+60", $(c["e1_o1_60"])); add("w21+ e2 O1+60", $(c["e2_o1_60"]))
    nw++; x = $(c["e1_o2_exc"]) + 0; sw += x; if (x > t1) { t2 = t1; n2 = n1; t1 = x; n1 = $1 " " $2 } else if (x > t2) { t2 = x; n2 = $1 " " $2 } if ($(c["group_rel"]) == "") wna++ } }
END { for (b in tw) printf "share %-7s %5d (%.1f%%)\n", b, tw[b], 100*tw[b]/ntot; dump(30)
  printf "w21+ e1: n=%d, group=na %d; O2 mean %+.2f%%; without its two largest (%s %+.1f%%, %s %+.1f%%) %+.2f%%\n", nw, wna, 100*sw/nw, n1, 100*t1, n2, 100*t2, 100*(sw - t1 - t2)/(nw - 2) }
