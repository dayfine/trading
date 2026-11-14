# combine.awk -- the combined outcome of ../../README.md §Arm G "The combined outcome", from the RULE lines the three
# pair reads print (split.sh with PAIRS S:C S:G G:C). The first matching row wins. It overrides nothing: C's outcome is
# the C vs S rule's and G's the G vs S rule's. The table names the reading and the candidate that follow from the two,
# and in every row it states what each of the three channel values means there: C vs G reads "admissions add",
# "admissions cost" or "unresolved" (README §C vs G), and an arm that fails ESCALATE on a secondary bar can sit beside
# any of them.
$1 == "RULE" { p = $2; out[p] = $3; for (i = 4; i <= NF; i++) { j = index($i, "="); if (j) v[p, substr($i, 1, j - 1)] = substr($i, j + 1) } }
# The secondary ESCALATE bars that pair p's arm fails (sign count, drawdown gap, trim3), for an arm whose median clears
# its bar. An arm that fails for another reason (NOT LIVE, fewer than 4 valid seeds, the median short of the bar, the
# harm bar) is named by its outcome alone.
function failed(p,   n, r, m, b) {
  n = v[p, "n"] + 0; m = v[p, "median"]; b = v[p, "delta"] + 0; r = ""
  if (m == "nan" || m + 0 < b || n < 4) return ""
  if (v[p, "pos"] + 0 < n - 1) r = r "; delta > 0 in only " v[p, "pos"] " of " n " seeds"
  if (v[p, "mdd"] != "nan" && v[p, "mdd"] + 0 > 3.0) r = r "; maxDD gap " v[p, "mdd"] " pp above the 3.0 pp bar"
  if (v[p, "Tp"] + 0 < n - 1) r = r "; trim3 > 0 in only " v[p, "Tp"] " of " n " seeds"
  return substr(r, 3)
}
function named(o, p,   f) { f = failed(p); return o (f == "" ? "" : ", median clears the bar but " f) }
END {
  c = ("S,C" in out) ? out["S,C"] : "MISSING"; g = ("S,G" in out) ? out["S,G"] : "MISSING"
  n = v["G,C", "n"] + 0; m = v["G,C", "median"]; b = v["G,C", "delta"] + 0
  ok = ("G,C" in out) && n >= 4 && m != "nan"
  up = ok && m + 0 >= b && v["G,C", "pos"] + 0 >= n - 1      # C beats G by the bar in all but one seed: admissions add
  down = ok && m + 0 <= -b && v["G,C", "neg"] + 0 >= n - 1   # G beats C by the bar in all but one seed: admissions cost
  ch = up ? "admissions add" : (down ? "admissions cost" : "unresolved")
  ginv = g == "MISSING" || v["S,G", "gbad"] + 0 != 0 || v["S,G", "n"] + 0 < 4 || g == "NOT_LIVE"
  prov = (v["S,C", "marked"] == "0" || v["S,G", "marked"] == "0" || v["G,C", "marked"] == "0" \
    || v["S,C", "unmarked"] + 0 > 0 || v["S,G", "unmarked"] + 0 > 0 || v["G,C", "unmarked"] + 0 > 0)
  a = v["S,C", "Ale0"] + 0; an = v["S,C", "n"]
  print "== 6. Combined outcome (README §Arm G, the combined table: the first row that matches)"
  printf "C vs S: %s; G vs S: %s; G check: %s; C vs G: %s\n", c, g, (g == "MISSING" ? "n/a" : (v["S,G", "gbad"] + 0 == 0 ? "pass" : "FAIL")),
    (("G,C" in out) ? sprintf("median %s against the bar %.4f, > 0 in %d, < 0 in %d of %d valid seeds (%s)", (ok ? sprintf("%+.4f", m) : "n/a"), b,
      v["G,C", "pos"], v["G,C", "neg"], n, ch) : "not read")
  if (ginv) {
    why = g == "MISSING" ? "no G read" : (v["S,G", "gbad"] + 0 != 0 ? "the G check failed" : (g == "NOT_LIVE" ? "G vs S is NOT LIVE" \
      : "fewer than 4 valid G seeds (" v["S,G", "n"] ")"))
    r = "G INVALID"; why = why "; C's outcome " c " stands alone, G reads are information only, no channel is named"
  } else if (c == "ESCALATE" && g == "ESCALATE") {
    r = "BOTH PASS"
    why = down ? "candidate: the cap with the uncapped gate (G); C vs G says the admissions cost" \
      : (up ? "candidate: the cap as built (C); the lever alone clears the bar, and C vs G says the admissions add to it" \
      : "candidate: the cap as built (C); the lever alone clears the bar, and C vs G is unresolved, so it does not show the admissions taking it back")
    why = why "; A without its 3 largest keys <= 0 in " a " of " an " valid seeds (reported for C's candidacy: it changes neither the row nor the candidate)"
  } else if (g == "ESCALATE") {
    r = "LEVER, NOT ADMISSIONS"; why = "G passes and C (" named(c, "S,C") ") does not; C vs G: " ch "; candidate: the cap with the uncapped gate (G); C's own outcome stands for the flag as built; "
    why = why (up ? "C's admissions added at least the bar over G, but C failed its own bar, so the gain does not make C a candidate" \
      : (down ? "the admissions cost the lever's gain" : "the admissions neither clearly add nor cost: they bury the lever's gain in noise, or C fails for another reason"))
  } else if (c == "ESCALATE") {
    r = "ADMISSIONS"; why = "C passes and G (" named(g, "S,G") ") does not; C vs G: " ch "; C's ESCALATE stands under its rule, "
    if (down) why = why "but the lever, not the admissions, carries the gain: G beat C by at least the bar and failed its own bar, so no candidate is named and the call between C and G goes to the user with both outcomes"
    else why = why (up ? "and the gain rides on the admissions" : "but this run cannot say the screen's lever carries it") ", read as a stop-gate change against the stop-width history"
    why = why "; A without its 3 largest keys <= 0 in " a " of " an " valid seeds" (a >= 3 ? ": FLAG to the user with the ESCALATE, before any promotion work" : "")
  } else {
    r = "NEITHER PASSES"; why = "C: " c ", G: " g "; each arm's own outcome applies to its configuration"
  }
  printf "COMBINED: %s (%s)%s\n", r, why, (prov ? "  PROVISIONAL: an open-leg key has no mark" : "")
}
