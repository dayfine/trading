# Prior decline at the breakdown (dd52 buckets) and real support breaks, with halves as the perturbation.
function b52(x) { return (x > -0.10) ? "a >-10%" : (x > -0.20 ? "b -10..-20%" : (x > -0.30 ? "c -20..-30%" : "d <-30%")) }
NR==1 { hdr(); next }
{ x = $(c["dd52"]); if (x == "") next; bk = b52(x + 0); h = (substr($2,1,4) + 0 <= 2012 ? "h1" : "h2"); P = isP(); bs = $(c["below_sup"])
  add("ALL dd52 " bk " O1+60", $(c["e1_o1_60"])); add("ALL dd52 " bk " O1+60 " h, $(c["e1_o1_60"])); add("ALL dd52 " bk " O1+120", $(c["e1_o1_120"])); add("ALL dd52 " bk " O2", $(c["e1_o2_exc"]))
  add("ALL below_sup=" bs " O1+60", $(c["e1_o1_60"])); add("ALL below_sup=" bs " O2", $(c["e1_o2_exc"]))
  if (P) { add("P1 dd52 " bk " O1+60", $(c["e1_o1_60"])); add("P1 dd52 " bk " O2", $(c["e1_o2_exc"])); add("P1 below_sup=" bs " O1+60", $(c["e1_o1_60"])); add("P1 below_sup=" bs " O2", $(c["e1_o2_exc"])) } }
END { dump(34) }
