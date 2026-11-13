# bands.awk -- events.tsv split by fixed raw-price bands (the tiebreak's edges $8 / $14 / $33), per half.
# usage: awk -F'\t' -v CAP=1.90 -f bands.awk events.tsv      (CAP: PREREG.md Amendment 1, ride capped at p99.5)
# Per band and half: n, monster rate (2x within 52 weeks), win rate (capped ride > 0), mean capped ride.
BEGIN { print "# events.tsv by raw price band at the breakout (screen.sh step 3b; lib/bands.awk, CAP=" CAP ")." }
{ r = $5; if (r > CAP) r = CAP; p = $10 + 0; b = (p < 8) ? 1 : (p < 14) ? 2 : (p < 33) ? 3 : 4
  h = (substr($2, 1, 4) <= "2012") ? 1 : 2
  n[b, h]++; m[b, h] += $3; w[b, h] += (r > 0); s[b, h] += r; n[5, h]++; m[5, h] += $3; w[5, h] += (r > 0); s[5, h] += r }
END { split("$5-8 $8-14 $14-33 >$33 all", L, " ")
  for (b = 1; b <= 5; b++) { printf "%-7s", L[b]
    for (h = 1; h <= 2; h++) printf " | %s n=%5d monster %5.1f%% win %4.1f%% ride %+5.1f%%", (h == 1) ? "00-12" : "13-25", n[b, h], 100 * m[b, h] / n[b, h], 100 * w[b, h] / n[b, h], 100 * s[b, h] / n[b, h]
    print "" } }
