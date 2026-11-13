# funnel.awk -- Measurement 4 (README): where the population screen's breakouts, and its monsters, leave the cascade on
# this run's path, by raw price band; the #2533 sub-gate on Dropped_at_breakout. POSIX awk; load with
# -f dates.awk -f rank.awk -f funnel.awk (rank.awk for band_of).
#
# usage: awk -F'\t' -v GATES=fgates.txt -f dates.awk -f rank.awk -f funnel.awk weeks.tsv events.tsv rows.tsv
#   weeks.tsv   date n_long_rows                            (cands.awk)
#   events.tsv  the screen's lib/mscan.awk output: symbol date monster fwd ride ... price(col 10)
#   rows.tsv    date symbol outcome gate score              (cands.awk, every Long row)
# An event joins the candidate row of its symbol in its own week (exact view), or the best row over that week and the
# next four (window view: the cascade may take a week or more to see a breakout). Without a row the event is
# NOT_SURFACED (the week has Long rows: held, cooldown, phase-1, sector filter, membership or warehouse), MACRO_BLOCKED
# (the week has no Long rows) or NO_SCREEN (the week was not screened). Prints aggregates only.
FILENAME == ARGV[1] { w = week_of($1); SCR[w] = $2 + 0; if (w0 == "" || w < w0) w0 = w; if (w > w1) w1 = w; next }
FILENAME == ARGV[2] {
  w = week_of($2); if (w < w0 || w > w1) next
  ne++; ES[ne] = $1; EW[ne] = w; EM[ne] = $3 + 0; EB[ne] = band_of($10 + 0)
  for (o = 0; o <= 4; o++) WANT[$1, w + o] = 1
  next
}
{ w = week_of($1); if (($2, w) in WANT) CL[$2, w] = cls($3, $4) }

function cls(out, gate) {
  if (out == "Admitted") return "ADMITTED"
  if (out == "Dropped_at_top_n") return "TOP_N"
  if (out == "Dropped_at_grade") return "GRADE"
  if (out == "Dropped_at_sector") return "SECTOR"
  if (out == "Dropped_at_breakout") return "BRK_" gate
  return "OTHER_" out
}
function crank(c) {
  if (c == "ADMITTED") return 1; if (c == "TOP_N") return 2; if (c == "GRADE") return 3; if (c == "SECTOR") return 4
  if (substr(c, 1, 4) == "BRK_") return 5; if (substr(c, 1, 6) == "OTHER_") return 5.5
  if (c == "NOT_SURFACED") return 6; if (c == "MACRO_BLOCKED") return 7; return 8
}
function class_at(s, w) {
  if ((s, w) in CL) return CL[s, w]
  if (!(w in SCR)) return "NO_SCREEN"
  return (SCR[w] == 0) ? "MACRO_BLOCKED" : "NOT_SURFACED"
}
function tally(view, c, b, m) {
  T[view, c, b, m]++; seen[c] = 1
  if (crank(c) <= 5.5) { NW[view, b, m]++; if (b <= 1) NW[view, "cheap", m]++; if (substr(c, 1, 4) == "BRK_") { G[view, c, (b <= 1) ? "cheap" : b, m]++ } }
}
END {
  for (e = 1; e <= ne; e++) {
    c0 = class_at(ES[e], EW[e]); cb = c0
    for (o = 1; o <= 4; o++) { c = class_at(ES[e], EW[e] + o); if (crank(c) < crank(cb)) cb = c }
    b = EB[e]; NE[b, "A"]++; if (EM[e]) NE[b, "M"]++
    tally("exact", c0, b, "A"); tally("window", cb, b, "A")
    if (EM[e]) { tally("exact", c0, b, "M"); tally("window", cb, b, "M") }
  }
  split("ADMITTED TOP_N GRADE SECTOR BRK_Price_floor BRK_Stage_setup BRK_Breakout_volume BRK_Rs_declining BRK_Failed_breakout BRK_Volume_band NOT_SURFACED MACRO_BLOCKED NO_SCREEN", ORD, " ")
  no = 13; for (c in seen) { k = 0; for (i = 1; i <= no; i++) if (ORD[i] == c) k = 1; if (!k) ORD[++no] = c }
  split("<$8 $8-14 $14-33 >=$33", L, " ")
  print "== Measurement 4: the population screen's breakouts in this run's cascade (README §Measurements) =="
  printf "events in the screened weeks: %d; by band (all / monster): %s %d/%d, %s %d/%d, %s %d/%d, %s %d/%d\n", ne, L[1], NE[0, "A"], NE[0, "M"], L[2], NE[1, "A"], NE[1, "M"], L[3], NE[2, "A"], NE[2, "M"], L[4], NE[3, "A"], NE[3, "M"]
  for (v = 1; v <= 2; v++) {
    view = (v == 1) ? "exact" : "window"
    printf "\n-- %s view: share of the band's events (monster | all) --\n", (v == 1) ? "exact-week" : "best of weeks 0..+4"
    printf "%-22s", "class"; for (b = 0; b <= 3; b++) printf " | %-17s", L[b + 1]; print ""
    for (i = 1; i <= no; i++) {
      printf "%-22s", ORD[i]
      for (b = 0; b <= 3; b++) printf " | %6s  %6s   ", sh(T[view, ORD[i], b, "M"], NE[b, "M"]), sh(T[view, ORD[i], b, "A"], NE[b, "A"])
      print ""
    }
    printf "\n-- %s view: breakout sub-gates among events with a cascade row (monster share, all share, lift = M/A) --\n", view
    printf "%-22s | %-30s | %-30s | %-30s\n", "sub-gate", "< $14 (cheap)", "$14-33", ">= $33"
    for (i = 1; i <= no; i++) {
      c = ORD[i]; if (substr(c, 1, 4) != "BRK_") continue
      printf "%-22s", c
      for (gi = 1; gi <= 3; gi++) {
        gk = (gi == 1) ? "cheap" : gi; mS = fr(G[view, c, gk, "M"], NW[view, gk, "M"]); aS = fr(G[view, c, gk, "A"], NW[view, gk, "A"])
        printf " | M %5.1f %% A %5.1f %% lift %4.2f", 100 * mS, 100 * aS, (aS > 0) ? mS / aS : 0
      }
      print ""
      mS = fr(G[view, c, "cheap", "M"], NW[view, "cheap", "M"]); aS = fr(G[view, c, "cheap", "A"], NW[view, "cheap", "A"])
      if (mS >= 0.20 && aS > 0 && mS / aS >= 1.25 && NW[view, "cheap", "M"] >= 30) hit[view] = hit[view] "," substr(c, 5)
    }
    printf "events with a cascade row: cheap monster %d, cheap all %d; $14-33 %d / %d; >= $33 %d / %d\n", NW[view, "cheap", "M"], NW[view, "cheap", "A"], NW[view, 2, "M"], NW[view, 2, "A"], NW[view, 3, "M"], NW[view, 3, "A"]
  }
  printf "F_exact %s F_window %s F_cheap_monsters_exact %d\n", (hit["exact"] == "") ? "none" : substr(hit["exact"], 2), (hit["window"] == "") ? "none" : substr(hit["window"], 2), NW["exact", "cheap", "M"] > GATES
}
function fr(a, b) { return (b > 0) ? a / b : 0 }
function sh(a, b) { return (b > 0) ? sprintf("%5.1f%%", 100 * a / b) : "  n/a" }
