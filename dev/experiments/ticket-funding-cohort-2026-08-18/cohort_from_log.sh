#!/bin/sh
# Ticket-funding rejection cohort — measured from a scenario_runner stderr log.
#
# Plan step 2 of dev/plans/ticket-funding-2026-08-16.md: "measure the cohort".
# Reads the loud per-trade WARN that Cancel_handler emits on a portfolio-rejected
# fill and reports the SHORTFALL DISTRIBUTION (not its median), plus the burst
# structure — how many rejections share one available-cash value, i.e. how much
# of the population is "the book emptied and everything after it in arrival
# order died" versus independent near-misses.
#
# Usage: sh dev/experiments/ticket-funding-cohort-2026-08-18/cohort_from_log.sh <log-file>
# Log may be host-side; for a container path, docker cp it out first.

LOG=${1:?usage: ticket_funding_cohort.sh <scenario_runner log>}

awk '
  /WARN: portfolio rejected fill/ {
    sym = $0; sub(/.*rejected fill for /, "", sym); sub(/ .*/, "", sym)
    side = $0; sub(/.*\(side=/, "", side); sub(/ .*/, "", side)
    pending_sym = sym; pending_side = side; next
  }
  /Insufficient cash for trade/ && pending_sym != "" {
    req = $0; sub(/.*Required: /, "", req); sub(/,.*/, "", req)
    avl = $0; sub(/.*Available: /, "", avl); sub(/,.*/, "", avl)
    printf "%s\t%s\t%.2f\t%.2f\t%.2f\t%.4f\n", \
      pending_sym, pending_side, req+0, avl+0, (req-avl), ((req-avl)/req)
    pending_sym = ""
  }
' "$LOG" > /tmp/_cohort.tsv

N=$(wc -l < /tmp/_cohort.tsv | tr -d ' ')
echo "rejections parsed: $N"
[ "$N" -gt 0 ] || exit 0

echo
echo "== shortfall as % of required (distribution, not median) =="
sort -g -k6 /tmp/_cohort.tsv | awk -v n="$N" '
  { p[NR] = $6 * 100; s += $6 * 100 }
  END {
    printf "  n=%d  mean=%.1f%%\n", n, s / n
    split("1 10 25 50 75 90 99", qs, " ")
    for (i = 1; i <= 7; i++) {
      k = int(qs[i] / 100 * n); if (k < 1) k = 1
      printf "  p%-2s = %6.1f%%\n", qs[i], p[k]
    }
  }'

echo
echo "== how many were NEAR misses (the 0.3%-shortfall class) =="
awk '{ pct = $6 * 100
       if (pct <= 1) a++; else if (pct <= 5) b++; else if (pct <= 25) c++;
       else if (pct <= 75) d++; else e++ }
     END { printf "  <=1%%: %d   1-5%%: %d   5-25%%: %d   25-75%%: %d   >75%%: %d\n",
                  a+0, b+0, c+0, d+0, e+0 }' /tmp/_cohort.tsv

echo
echo "== burst structure (rejections sharing one available-cash value) =="
cut -f4 /tmp/_cohort.tsv | sort | uniq -c | sort -rn > /tmp/_cohort_bursts.txt
awk '{ bursts++; tot += $1; if ($1 > 1) { multi++; multi_n += $1 } }
     END { printf "  distinct available-cash values: %d over %d rejections\n", bursts, tot
           printf "  bursts of >1: %d, covering %d rejections (%.0f%% of the cohort)\n",
                  multi+0, multi_n+0, 100 * multi_n / tot }' /tmp/_cohort_bursts.txt
echo "  largest bursts (count, available-cash):"
head -5 /tmp/_cohort_bursts.txt | sed 's/^/    /'

echo
echo "== most-rejected symbols =="
cut -f1 /tmp/_cohort.tsv | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'

echo
echo "  per-rejection rows: /tmp/_cohort.tsv (sym side required available shortfall shortfall_frac)"
