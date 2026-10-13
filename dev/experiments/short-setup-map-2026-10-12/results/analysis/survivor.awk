# Sector coverage is survivor-only: delisted share by group availability, and the checklist without the group filter.
# Files: lastdate.csv (SYM,last bar date) then evx.csv.
NR == FNR { ld[$1] = $2; next }
FNR == 1 { hdr(); next }
{ g = ($(c["group_rel"]) == "" ? "group=na" : "group known"); dead = (ld[$1] < "2026-01-01") ? 1 : 0; ng[g]++; dg[g] += dead
  st = dead ? "delisted" : "live"; ph=$(c["phase"]); adv=$(c["advance"]); rs=$(c["rs_class"])
  A = (ph=="s4_early"||ph=="s3") && adv!="" && adv+0>=0.30 && rs!="rising" && rs!="na"
  add("ALL " st " O2", $(c["e1_o2_exc"])); add("ALL " st " O1+120", $(c["e1_o1_120"]))
  if (A) { add("checklist w/o group, " st ", O2", $(c["e1_o2_exc"])); add("checklist w/o group, " st ", O1+120", $(c["e1_o1_120"])) } }
END { for (g in ng) printf "%-12s events=%5d, symbol delisted before 2026: %.1f%%\n", g, ng[g], 100*dg[g]/ng[g]; dump(38) }
