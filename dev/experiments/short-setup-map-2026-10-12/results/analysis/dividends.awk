# Amendment 1: dividend payers vs non-payers, and a >= 3 % dividend inside the +120-bar window, on O2 and on O1+120
# (the no-stop hold spans the whole window, so it pays every dividend in it through adjusted closes).
function lev_yld(x) { return (x <= 0) ? "none" : (x < 0.02 ? "<2%" : (x <= 0.05 ? "2-5%" : ">5%")) }
NR==1 { hdr(); next }
{ y = lev_yld($(c["yield"])); bd = $(c["bigdiv"]); h = (substr($2,1,4) + 0 <= 2012 ? "h1" : "h2"); P = isP(); pay = ($(c["yield"]) + 0 > 0) ? "payer" : "non-payer"
  add(pay " O2", $(c["e1_o2_exc"])); add(pay " O1+120", $(c["e1_o1_120"])); add(pay " O1+120 " h, $(c["e1_o1_120"])); add(pay " E2 O2", $(c["e2_o2_exc"]))
  add("yield=" y " O2", $(c["e1_o2_exc"])); add("yield=" y " O1+120", $(c["e1_o1_120"])); add("yield=" y " O1+120 " h, $(c["e1_o1_120"]))
  add("bigdiv=" bd " O2", $(c["e1_o2_exc"])); add("bigdiv=" bd " O1+120", $(c["e1_o1_120"])); add("bigdiv=" bd " O1+120 " h, $(c["e1_o1_120"]))
  if (P) { add("P1 " pay " O2", $(c["e1_o2_exc"])); add("P1 " pay " O1+120", $(c["e1_o1_120"])); add("P1 bigdiv=" bd " O1+120", $(c["e1_o1_120"])) } }
END { dump(26) }
