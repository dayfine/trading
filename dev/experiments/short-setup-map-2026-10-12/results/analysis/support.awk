# Does the "breakdown" close below the broken support (the E2 level)? E2 by that; entries at/above their own stop;
# stopped shares; data truncation before +120 bars.
NR==1 { hdr(); next }
{ n++; b = $(c["below_sup"]); bs += b; P = isP(); if (P) { np++; bsp += b; if ($(c["e1_room"]) + 0 <= 0.15) pr15++; ps1 += $(c["e1_o2_stopped"]) }
  w = $(c["e2_weeks"]) + 0; if (w == 1) { w1++; if (b == 0) w1a++ }
  if (b == 0) { na++; if (w > 0) na2++; if (w == 1) na1++ } else { nb++; if (w > 0) nb2++; if (w == 1) nb1++ }
  if ($(c["e1_room"]) + 0 <= 0) e1neg++; if ($(c["e2_room"]) != "") { ne2++; if ($(c["e2_room"]) + 0 <= 0) e2neg++ }
  x = $(c["nbars_after"]) + 0; if (x < 120) { t120++; o = $(c["e1_o1_120"]); if (o != "") { tn++; ts += o; if (o + 0 > 0) tpos++ } }
  if ($(c["e1_o2_bars"]) + 0 < 120 && $(c["e1_o2_stopped"]) == 0) t2++ }
END { printf "breakdown weekly close below the broken support: %d of %d (%.1f%%); P1: %d of %d (%.1f%%)\n", bs, n, 100*bs/n, bsp, np, 100*bsp/np
  printf "close at/above support: %d -> E2 found %.1f%%, in week 1 %.1f%% | close below support: %d -> E2 found %.1f%%, in week 1 %.1f%%\n", na, 100*na2/na, 100*na1/na, nb, 100*nb2/nb, 100*nb1/nb
  printf "week-1 E2 entries whose breakdown close was not below support: %d of %d (%.1f%%)\n", w1a, w1, 100*w1a/w1
  printf "entry close at/above its own stop (room <= 0): E1 %d of %d (%.1f%%); E2 %d of %d (%.1f%%)\n", e1neg, n, 100*e1neg/n, e2neg, ne2, 100*e2neg/ne2
  printf "P1: room <= 15%% %.1f%%, O2 stopped %.1f%% (n=%d)\n", 100*pr15/np, 100*ps1/np, np
  printf "data ends < 120 bars after E1: %d (%.2f%%); their O1+120 mean %+.2f%%, beat %.1f%%; O2 rows truncated (bars<120, not stopped): %d (%.2f%%)\n", t120, 100*t120/n, 100*ts/tn, 100*tpos/tn, t2, 100*t2/n }
