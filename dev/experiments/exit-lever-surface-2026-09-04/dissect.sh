#!/bin/sh
# dissect.sh NULL.trades.csv ARM.trades.csv [TOPN]
# Paired trade dissection on the symbol|entry_date join
# (feedback_dissect_before_proposing_a_mechanism): realised $ per arm, shared-
# trade drift (arm - null on shared keys), unique-cohort sums, top trades per
# cohort (monster check), and exit_trigger histograms. POSIX sh + awk only.
set -u
null=$1; arm=$2; topn=${3:-3}
awk -F, -v TOPN="$topn" '
  BEGIN { top = "sort -gr | head -" TOPN; bot = "sort -g | head -" TOPN }
  FNR == 1 { next }
  FILENAME == ARGV[1] { k = $1 "|" $3; np[k] += $9; nn[k]++; nt[$13]++; nsum += $9; ncount++;
                        ndesc[k] = $1 " " $3 "->" $4 " " $13 " " sprintf("%+.0f", $9); next }
  { k = $1 "|" $3; ap[k] += $9; an[k]++; at[$13]++; asum += $9; acount++;
    adesc[k] = $1 " " $3 "->" $4 " " $13 " " sprintf("%+.0f", $9) }
  END {
    for (k in np) { if (k in ap) { sh++; drift += ap[k] - np[k]; d[k] = ap[k] - np[k] } else { no++; nonly += np[k]; nu[k] = np[k] } }
    for (k in ap) { if (!(k in np)) { ao++; aonly += ap[k]; au[k] = ap[k] } }
    printf "trades      null=%d arm=%d   shared=%d null-only=%d arm-only=%d\n", ncount, acount, sh, no, ao
    printf "realised $  null=%+.0f arm=%+.0f  delta=%+.0f\n", nsum, asum, asum - nsum
    printf "shared drift (arm-null) = %+.0f over %d shared\n", drift, sh
    printf "null-only cohort = %+.0f (%d)   arm-only cohort = %+.0f (%d)\n", nonly, no, aonly, ao
    printf "check: drift + arm-only - null-only = %+.0f\n", drift + aonly - nonly
    print "-- top null-only --"; n = 0; for (k in nu) print nu[k] "\t" ndesc[k] | top; close(top)
    print "-- bottom null-only --"; for (k in nu) print nu[k] "\t" ndesc[k] | bot; close(bot)
    print "-- top arm-only --"; for (k in au) print au[k] "\t" adesc[k] | top; close(top)
    print "-- bottom arm-only --"; for (k in au) print au[k] "\t" adesc[k] | bot; close(bot)
    print "-- largest shared drift (arm-null) --"; for (k in d) print d[k] "\t" ndesc[k] " => " adesc[k] | top; close(top)
    print "-- most negative shared drift --"; for (k in d) print d[k] "\t" ndesc[k] " => " adesc[k] | bot; close(bot)
    print "-- exit_trigger null / arm --"
    for (t in nt) seen[t] = 1; for (t in at) seen[t] = 1
    for (t in seen) printf "  %-28s %4d %4d\n", t, nt[t] + 0, at[t] + 0
  }' "$null" "$arm"
