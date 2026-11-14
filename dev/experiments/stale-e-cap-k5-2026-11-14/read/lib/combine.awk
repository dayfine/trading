# combine.awk -- the combined outcome of ../../README.md §Arm G "The combined outcome", from the RULE lines the three
# pair reads print (split.sh with PAIRS S:C S:G G:C). The first matching row wins. It overrides nothing: C's outcome is
# the C vs S rule's and G's the G vs S rule's. The table names the reading and the candidate that follow from the two.
$1 == "RULE" { p = $2; out[p] = $3; for (i = 4; i <= NF; i++) { j = index($i, "="); if (j) v[p, substr($i, 1, j - 1)] = substr($i, j + 1) } }
END {
  c = ("S,C" in out) ? out["S,C"] : "MISSING"; g = ("S,G" in out) ? out["S,G"] : "MISSING"
  n = v["G,C", "n"] + 0; m = v["G,C", "median"]; b = v["G,C", "delta"] + 0
  ok = ("G,C" in out) && n >= 4 && m != "nan"
  up = ok && m + 0 >= b && v["G,C", "pos"] + 0 >= n - 1      # C beats G by the bar in all but one seed: admissions add
  down = ok && m + 0 <= -b && v["G,C", "neg"] + 0 >= n - 1   # G beats C by the bar in all but one seed: admissions cost
  ginv = g == "MISSING" || v["S,G", "gbad"] + 0 != 0 || v["S,G", "n"] + 0 < 4 || g == "NOT_LIVE"
  prov = (v["S,C", "marked"] == "0" || v["S,G", "marked"] == "0" || v["G,C", "marked"] == "0")
  print "== 6. Combined outcome (README §Arm G, the combined table: the first row that matches)"
  printf "C vs S: %s; G vs S: %s; G check: %s; C vs G: %s\n", c, g, (g == "MISSING" ? "n/a" : (v["S,G", "gbad"] + 0 == 0 ? "pass" : "FAIL")),
    (("G,C" in out) ? sprintf("median %s against the bar %.4f, > 0 in %d, < 0 in %d of %d valid seeds (%s)", (ok ? sprintf("%+.4f", m) : "n/a"), b,
      v["G,C", "pos"], v["G,C", "neg"], n, (up ? "admissions add" : (down ? "admissions cost" : "inside the band or unreadable"))) : "not read")
  if (ginv) {
    why = g == "MISSING" ? "no G read" : (v["S,G", "gbad"] + 0 != 0 ? "the G check failed" : (g == "NOT_LIVE" ? "G vs S is NOT LIVE" \
      : "fewer than 4 valid G seeds (" v["S,G", "n"] ")"))
    r = "G INVALID"; why = why "; C's outcome " c " stands alone, G reads are information only, no channel is named"
  } else if (c == "ESCALATE" && g == "ESCALATE") {
    r = "BOTH PASS"; why = down ? "candidate: the cap with the uncapped gate (G); C vs G says the admissions cost" \
                                : "candidate: the cap as built (C); the lever alone clears the bar, and the admissions do not take it back"
  } else if (g == "ESCALATE") {
    r = "LEVER, NOT ADMISSIONS"; why = "G passes and C (" c ") does not: candidate: the cap with the uncapped gate (G); C's own outcome stands for the flag as built"
  } else if (c == "ESCALATE") {
    a = v["S,C", "Ale0"] + 0
    r = "ADMISSIONS"; why = "C passes and G (" g ") does not: C's ESCALATE stands under its rule, read as a stop-gate change against the stop-width history; channel " \
      (up ? "admissions add" : "unresolved") "; A without its 3 largest keys <= 0 in " a " of " v["S,C", "n"] " valid seeds" \
      (a >= 3 ? ": FLAG to the user with the ESCALATE, before any promotion work" : "")
  } else {
    r = "NEITHER PASSES"; why = "C: " c ", G: " g "; each arm's own outcome applies to its configuration"
  }
  printf "COMBINED: %s (%s)%s\n", r, why, (prov ? "  PROVISIONAL: open positions not marked" : "")
}
