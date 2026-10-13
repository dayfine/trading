# E2 vs E1 on the same events (paired), and what the E2 events' own E1 outcome was.
NR==1 { hdr(); next }
{ x2 = $(c["e2_o2_exc"]); if (x2 == "") next; x1 = $(c["e1_o2_exc"]); P = isP(); wk = ($(c["e2_weeks"]) == 1 ? "wk1" : "wk2-8")
  d = x2 - x1; px = $(c["e2_px"]) / $(c["e1_px"]) - 1
  add("ALL E2-E1 O2", d); add("ALL E2-E1 O2 " wk, d); add("ALL E2 entry vs E1 entry " wk, px)
  if (P) { add("P2 E2-E1 O2", d); add("P2 E2-E1 O2 " wk, d); add("P2 E2-E1 O1+60", $(c["e2_o1_60"]) - $(c["e1_o1_60"])); add("P2 E2 entry vs E1 entry", px)
    add("P2 events: their E1 O2", x1); add("P2 E2 O2 " wk, x2); n2++; if ($(c["e2_room"]) + 0 <= 0) neg++; s2 += $(c["e2_o2_stopped"]) } }
END { dump(30); printf "P2: n=%d, entry at/above own stop %.1f%%, stopped %.1f%%\n", n2, 100*neg/n2, 100*s2/n2 }
