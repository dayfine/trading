# Prior decline at the breakdown, stop room under three definitions, and the E1 stop-width surface.
NR==1 { hdr(); split("s05 s10 s15 s20 s30 s50 s100 sh26 sh52", L, " "); next }
{ P = isP(); for (z = 1; z <= 9; z++) { split($(c[L[z]]), a, ";"); add("ALL " L[z], a[1]); if (P) add("P1 " L[z], a[1]); if (a[2] == 1) { st["ALL " L[z]]++; if (P) st["P1 " L[z]]++ } }
  add("ALL O2 pre-reg", $(c["e1_o2_exc"])); add("ALL O1+120 no stop", $(c["e1_o1_120"])); add("ALL dd52", $(c["dd52"]))
  add("ALL room pre-reg", $(c["e1_room"])); add("ALL room 26wk", $(c["room26"])); add("ALL room 52wk", $(c["room52"]))
  if (P) { add("P1 O2 pre-reg", $(c["e1_o2_exc"])); add("P1 O1+120 no stop", $(c["e1_o1_120"])); add("P1 dd52", $(c["dd52"]))
    add("P1 room pre-reg", $(c["e1_room"])); add("P1 room 26wk", $(c["room26"])); add("P1 room 52wk", $(c["room52"])) } }
END { print "-- breakdown close vs the max weekly close of the prior 52 weeks"; print "ALL " full("ALL dd52"); print "P1  " full("P1 dd52")
  print "-- stop room from the E1 entry: pre-reg (1 % above the Stage-3 high), 1 % above the 26- / 52-week high"
  split("room pre-reg|room 26wk|room 52wk", R, "|"); for (z = 1; z <= 3; z++) { print "ALL " R[z] ": " full("ALL " R[z]); print "P1  " R[z] ": " full("P1 " R[z]) }
  print "-- E1 stop-width surface: excess vs the SPY short, hold to the buy-stop or +120 bars"
  for (u = 1; u <= 2; u++) { pre = (u == 1 ? "ALL " : "P1 "); printf "%-22s %s\n", pre "O2 pre-reg", full(pre "O2 pre-reg")
    for (z = 1; z <= 9; z++) printf "%-22s %s stopped=%.1f%%\n", pre L[z], full(pre L[z]), 100*st[pre L[z]]/cnt[pre L[z]]
    printf "%-22s %s\n", pre "O1+120 no stop", full(pre "O1+120 no stop") } }
