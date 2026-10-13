# P1 / P2 by SPY phase, with the absolute (not excess) O2 short return.
NR==1 { hdr(); next }
{ if (!isP()) next; ph = $(c["phase"]); add("P1 " ph " O2", $(c["e1_o2_exc"])); add("P1 " ph " O1+60", $(c["e1_o1_60"])); add("P1 " ph " O1+120", $(c["e1_o1_120"]))
  add("P1 " ph " absolute O2 short ret", $(c["e1_o2_ret"])); add("P2 " ph " O2", $(c["e2_o2_exc"])); add("P1 all absolute O2 short ret", $(c["e1_o2_ret"])) }
END { dump(34) }
