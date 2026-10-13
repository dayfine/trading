# P1 / P2 by breakdown year.
NR==1 { hdr(); next }
{ y = substr($2,1,4); n[y]++; if (isP()) { add("P1 " y, $(c["e1_o2_exc"])); add("P1o60 " y, $(c["e1_o1_60"])); add("P2 " y, $(c["e2_o2_exc"])) } }
END { for (y = 2000; y <= 2025; y++) printf "%d all=%4d | P1 O2 %s | P1 O1+60 %s | P2 O2 %s\n", y, n[y], brief("P1 " y), brief("P1o60 " y), brief("P2 " y) }
