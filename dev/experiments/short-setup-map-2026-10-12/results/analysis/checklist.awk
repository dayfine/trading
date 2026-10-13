# Each checklist component alone, combined, and the SPY phase, on O1 (no stop) and O2.
NR==1 { hdr(); next }
{ ph=$(c["phase"]); adv=$(c["advance"]); rs=$(c["rs_class"]); g=$(c["group_rel"])
  A = (ph=="s4_early"||ph=="s3"); B = (adv!="" && adv+0>=0.30); C = (rs!="rising" && rs!="na"); D = (g!="" && g+0<0)
  o60=$(c["e1_o1_60"]); o120=$(c["e1_o1_120"]); o2=$(c["e1_o2_exc"])
  add("O1+60 all events", o60); add("O1+60 market s3|s4_early", (A ? o60 : "")); add("O1+60 advance >= 30%", (B ? o60 : ""))
  add("O1+60 RS not rising", (C ? o60 : "")); add("O1+60 group weak", (D ? o60 : "")); add("O1+60 all four = P1", (A&&B&&C&&D ? o60 : ""))
  add("O1+60 advance+RS+group, other phases", (!A&&B&&C&&D ? o60 : ""))
  add("O1+60 phase=" ph, o60); add("O1+120 phase=" ph, o120); add("O2 phase=" ph, o2)
  add("O2 checklist without group (na kept)", (A&&B&&C ? o2 : "")); add("O2 checklist, group=na only", (A&&B&&C&&g=="" ? o2 : ""))
  add("O1+60 checklist without group (na kept)", (A&&B&&C ? o60 : "")); add("O1+60 checklist, group=na only", (A&&B&&C&&g=="" ? o60 : ""))
  h = (substr($2,1,4) + 0 <= 2012 ? "h1" : "h2"); add("O1+120 rs=" rs, o120); add("O1+120 rs=" rs " " h, o120); add("room rs=" rs, $(c["e1_room"])) }
END { dump(42) }
