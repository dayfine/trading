# mweek.awk -- the macro proxy's population: each screen event (the population screen's lib/mscan.awk) that falls in
# the week of a screened Friday that was not open, mapped to that Friday. Those breakouts were removed before the
# trace could name them (it omits a blocked side), so the macro gate's counterfactual can only be read through them.
# POSIX awk; load with -f ../../../price-band-binding-2026-11-13/read/lib/dates.awk -f mweek.awk.
# usage: awk -F'\t' -f dates.awk -f mweek.awk open.tsv events.tsv   ->   date  symbol
FILENAME == ARGV[1] { if ($2 != 1) B[week_of($1)] = $1; next }
(week_of($2) in B) { print B[week_of($2)] "\t" $1 }
