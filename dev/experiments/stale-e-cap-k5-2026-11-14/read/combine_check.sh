#!/bin/sh
# combine_check.sh -- feeds lib/combine.awk fabricated RULE lines for every row of the combined table (README §The
# combined outcome) and, in the three rows where the channel can disagree with the row's reading, for each of the three
# channel values. It checks the row name and the phrase that must be in the reading, and prints the COMBINED line of
# each case. POSIX sh + awk; no artifacts needed. Exit status 1 when any case fails.
# usage: sh combine_check.sh
LIB=$(cd "$(dirname "$0")/lib" && pwd); bad=0

# rule PAIR TAG MEDIAN POS NEG TP MDD ALE0 GBAD UNMARKED: one fabricated RULE line over 5 valid seeds, delta 0.2000.
rule() {
  printf 'RULE %s %s n=5 median=%s pos=%s neg=%s delta=0.2000 Dp=5 Tp=%s mdd=%s L=0.2000 F=0.9000 Mp=100 Ale0=%s gbad=%s marked=1 unmarked=%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
}
# case NAME EXPECT_ROW EXPECT_PHRASE SC SG GC: SC, SG and GC are the three RULE lines.
case_() {
  out=$(printf '%s\n%s\n%s\n' "$4" "$5" "$6" | awk -f "$LIB/combine.awk" | grep '^COMBINED:')
  if printf '%s' "$out" | grep -q "^COMBINED: $2 " && printf '%s' "$out" | grep -qF -- "$3"; then echo "OK   $1"; else echo "FAIL $1 (wanted row $2 with: $3)"; bad=1; fi
  echo "     $out"
}
pass_sc() { rule S,C ESCALATE +0.3100 5 0 5 1.00 "${1:-0}" 0 0; }          # C passes
pass_sg() { rule S,G ESCALATE +0.3000 5 0 5 1.00 0 0 0; }                  # G passes
cadd()  { rule G,C REPORT +0.2500 5 0 5 0.00 0 0 0; }                      # C beats G by the bar in all seeds: admissions add
ccost() { rule G,C REPORT -0.2500 0 5 5 0.00 0 0 0; }                      # G beats C by the bar in all seeds: admissions cost
cnone() { rule G,C REPORT +0.0500 3 2 5 0.00 0 0 0; }                      # inside the band: unresolved

case_ "G check failed"          "G INVALID" "the G check failed"          "$(pass_sc)" "$(rule S,G ESCALATE +0.3000 5 0 5 1.00 0 1 0)" "$(cadd)"
case_ "G NOT LIVE"              "G INVALID" "G vs S is NOT LIVE"          "$(pass_sc)" "$(rule S,G NOT_LIVE +0.3000 5 0 5 1.00 0 0 0)" "$(cadd)"
case_ "fewer than 4 G seeds"    "G INVALID" "fewer than 4 valid G seeds"  "$(pass_sc)" "$(rule S,G INCONCLUSIVE +0.3000 3 0 3 1.00 0 0 0 | sed 's/n=5/n=3/')" "$(cadd)"

case_ "both pass, admissions add"        "BOTH PASS" "the lever alone clears the bar, and C vs G says the admissions add to it" "$(pass_sc 2)" "$(pass_sg)" "$(cadd)"
case_ "both pass, unresolved"            "BOTH PASS" "C vs G is unresolved, so it does not show the admissions taking it back" "$(pass_sc 2)" "$(pass_sg)" "$(cnone)"
case_ "both pass, admissions cost"       "BOTH PASS" "candidate: the cap with the uncapped gate (G)" "$(pass_sc 2)" "$(pass_sg)" "$(ccost)"
case_ "both pass, A count printed"       "BOTH PASS" "A without its 3 largest keys <= 0 in 4 of 5 valid seeds" "$(pass_sc 4)" "$(pass_sg)" "$(cadd)"

# C fails only a secondary bar (drawdown gap 4.20 pp, trim3 > 0 in 3 seeds, delta > 0 in 3 seeds).
c_dd()   { rule S,C INCONCLUSIVE +0.3100 5 0 5 4.20 0 0 0; }
c_trim() { rule S,C INCONCLUSIVE +0.3100 5 0 3 1.00 0 0 0; }
c_sign() { rule S,C INCONCLUSIVE +0.3100 3 2 5 1.00 0 0 0; }
case_ "lever, C fails drawdown, admissions add"  "LEVER, NOT ADMISSIONS" "maxDD gap 4.20 pp above the 3.0 pp bar"      "$(c_dd)"   "$(pass_sg)" "$(cadd)"
case_ "lever, C fails trim3, admissions add"     "LEVER, NOT ADMISSIONS" "trim3 > 0 in only 3 of 5 seeds"               "$(c_trim)" "$(pass_sg)" "$(cadd)"
case_ "lever, C fails sign count, admissions add" "LEVER, NOT ADMISSIONS" "delta > 0 in only 3 of 5 seeds"               "$(c_sign)" "$(pass_sg)" "$(cadd)"
case_ "lever, add: the gain does not make C a candidate" "LEVER, NOT ADMISSIONS" "so the gain does not make C a candidate" "$(c_dd)"   "$(pass_sg)" "$(cadd)"
case_ "lever, admissions cost"           "LEVER, NOT ADMISSIONS" "the admissions cost the lever's gain"            "$(rule S,C KEEP-AXIS +0.0500 3 2 5 1.00 0 0 0)" "$(pass_sg)" "$(ccost)"
case_ "lever, unresolved"                "LEVER, NOT ADMISSIONS" "bury the lever's gain in noise"                  "$(rule S,C KEEP-AXIS +0.0500 3 2 5 1.00 0 0 0)" "$(pass_sg)" "$(cnone)"

# G fails only a secondary bar (trim3 > 0 in 3 seeds).
g_trim() { rule S,G INCONCLUSIVE +0.3000 5 0 3 1.00 0 0 0; }
case_ "admissions, G fails trim3, admissions cost" "ADMISSIONS" "no candidate is named and the call between C and G goes to the user" "$(pass_sc 1)" "$(g_trim)" "$(ccost)"
case_ "admissions cost names G's failed bar"       "ADMISSIONS" "trim3 > 0 in only 3 of 5 seeds"       "$(pass_sc 1)" "$(g_trim)" "$(ccost)"
case_ "admissions, admissions add"                 "ADMISSIONS" "and the gain rides on the admissions" "$(pass_sc 1)" "$(rule S,G KEEP-AXIS +0.0500 3 2 5 1.00 0 0 0)" "$(cadd)"
case_ "admissions, unresolved"                     "ADMISSIONS" "this run cannot say the screen's lever carries it" "$(pass_sc 1)" "$(rule S,G KEEP-AXIS +0.0500 3 2 5 1.00 0 0 0)" "$(cnone)"
case_ "admissions, three-largest-keys flag"        "ADMISSIONS" "FLAG to the user with the ESCALATE"   "$(pass_sc 3)" "$(g_trim)" "$(cnone)"
case_ "admissions, no flag below 3"                "ADMISSIONS" "<= 0 in 2 of 5 valid seeds"           "$(pass_sc 2)" "$(g_trim)" "$(cnone)"

case_ "neither passes"          "NEITHER PASSES" "each arm's own outcome applies" "$(rule S,C KEEP-AXIS +0.0500 3 2 5 1.00 0 0 0)" "$(rule S,G KEEP-AXIS +0.0500 3 2 5 1.00 0 0 0)" "$(cnone)"
case_ "provisional (unmarked open-leg keys)" "BOTH PASS" "PROVISIONAL: an open-leg key has no mark" "$(rule S,C ESCALATE +0.3100 5 0 5 1.00 0 0 2)" "$(pass_sg)" "$(cadd)"
exit $bad
