#!/bin/sh
# gate-funnel-2026-11-15: run read/lib/rules.awk on fabricated gate lines, one case per branch of both rules (README
# §Decision rule), and check each lands where the README's order puts it. No data: every number below is made up.
# usage: sh read/rules_check.sh   (prints one line per case; exit 1 if any case lands elsewhere)
set -u
L=$(cd "$(dirname "$0")" && pwd)/lib
bad=0
# case NAME EXPECT_RULE1 EXPECT_RULE2 GATE-LINE CF-LINES...
case_() {
  name=$1; e1=$2; e2=$3; g=$4; shift 4
  got=$( { echo "$g"; for l in "$@"; do echo "$l"; done; } | awk -v YARD="0.0048 2.7554 576" -f "$L/rules.awk")
  g1=$(echo "$got" | sed -n 's/^Rule 1 (gate before cap), mechanical: \([A-Z]*\).*/\1/p')
  g2=$(echo "$got" | sed -n 's/^Rule 2 (score tier), mechanical: \([A-Z]*\).*/\1/p')
  if [ "$g1" = "$e1" ] && [ "$g2" = "$e2" ]; then r=ok; else r=WRONG; bad=1; fi
  printf '%-44s rule 1 %-12s (expected %-12s) rule 2 %-12s (expected %-12s) %s\n' "$name" "$g1" "$e1" "$g2" "$e2" "$r"
}
# Tier lines: powered, A+ beats A by 3 pp / 2.5 pp and 1.4x monsters (a ranking lever) unless a case overrides them.
T="CF tier:A_plus 800 0.06 0.14 112
CF tier:A_plus|h1 400 0.06 0.14 56
CF tier:A_plus|h2 400 0.065 0.14 56
CF tier:A 3000 0.03 0.10 300
CF tier:A|h1 1500 0.03 0.10 150
CF tier:A|h2 1500 0.04 0.10 150"
F="CF walk:Funded 600 0.05 0.08 48"
gl() { # XN XR f bear_x bear_open [net_ok]
  echo "G_m 0.12 G_f $3 G_s 0.02 G_XG 30 G_net_ok ${6:-1} G_XN $1 G_XR $2 G_bear_x $4 G_bear_open $5 G_open 1099"
}
IFS_SAVE=$IFS; IFS='
'
set -f
case_ "field absent: not applied"            NOT  RANKING "$(gl NA NA 0.85 NA 0.2 0)" $T $F "CF crowd:net 0 0 0 0"
case_ "X net.f 17 < 25: close"               CLOSE RANKING "$(gl 20 19 0.85 0.2 0.2)" $T $F "CF crowd:net 20 0.05 0.08 2"
case_ "X net.f exactly 25: refine, all met"  BUILD RANKING "$(gl 25 40 1.0 0.2 0.2)" $T $F "CF crowd:net 25 0.05 0.08 2"
case_ "refine: X ref.f 46.8, ride, bear: build" BUILD RANKING "$(gl 60 55 0.85 0.25 0.2)" $T $F "CF crowd:net 60 0.045 0.08 5"
case_ "refine: X ref.f 35.7 < 40: park"      PARK RANKING "$(gl 40 42 0.85 0.2 0.2)" $T $F "CF crowd:net 40 0.05 0.08 3"
case_ "refine: ride 2 pp under funded: park" PARK RANKING "$(gl 80 70 0.85 0.2 0.2)" $T $F "CF crowd:net 80 0.03 0.08 6"
case_ "refine: ride exactly funded - 1 pp: build" BUILD RANKING "$(gl 80 70 0.85 0.2 0.2)" $T $F "CF crowd:net 80 0.04 0.08 6"
case_ "refine: bear share 0.35 > 0.30: park"  PARK RANKING "$(gl 80 70 0.85 0.35 0.2)" $T $F "CF crowd:net 80 0.05 0.08 6"
U="CF tier:A_plus 150 0.06 0.14 21
CF tier:A_plus|h1 60 0.06 0.14 8
CF tier:A_plus|h2 90 0.065 0.14 13
CF tier:A 3000 0.03 0.10 300
CF tier:A|h1 1500 0.03 0.10 150
CF tier:A|h2 1500 0.04 0.10 150"
case_ "ranking: A+ under 100 rows in a half"  CLOSE UNDERPOWERED "$(gl 20 19 0.85 0.2 0.2)" $U $F "CF crowd:net 20 0.05 0.08 2"
N="CF tier:A_plus 800 0.06 0.14 112
CF tier:A_plus|h1 400 0.06 0.14 56
CF tier:A_plus|h2 400 0.05 0.14 56
CF tier:A 3000 0.03 0.10 300
CF tier:A|h1 1500 0.03 0.10 150
CF tier:A|h2 1500 0.04 0.10 150"
case_ "ranking: 1 pp in 2013-26: no lever"   CLOSE NO "$(gl 20 19 0.85 0.2 0.2)" $N $F "CF crowd:net 20 0.05 0.08 2"
R="CF tier:A_plus 800 0.06 0.12 96
CF tier:A_plus|h1 400 0.06 0.12 48
CF tier:A_plus|h2 400 0.065 0.12 48
CF tier:A 3000 0.03 0.10 300
CF tier:A|h1 1500 0.03 0.10 150
CF tier:A|h2 1500 0.04 0.10 150"
case_ "ranking: monster x1.2 < 1.3: no lever" CLOSE NO "$(gl 20 19 0.85 0.2 0.2)" $R $F "CF crowd:net 20 0.05 0.08 2"
set +f; IFS=$IFS_SAVE
[ "$bad" = 0 ] && echo "rules_check: every case landed as the README orders" || { echo "rules_check: a case landed elsewhere"; exit 1; }
