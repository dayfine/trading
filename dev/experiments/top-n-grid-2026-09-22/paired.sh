#!/bin/sh
# Paired read of one salt: sh paired.sh <null-trades.csv> <arm-trades.csv>
# Join key symbol|entry_date (position_id differs across runs — feedback_position_id_is_the_only_join_key applies WITHIN a
# run; across arms the (symbol, entry_date) pair is the only stable key). Prints shared / null-only / arm-only counts +
# realised P&L, the first-divergence date, per-entry-year realised for both arms, and the arm-only cohort by entry-year
# with its >= +20 % share (the pre-registered "fresh winners vs stale entries" read). trades.csv columns: 1 symbol,
# 3 entry_date, 9 pnl_dollars, 10 pnl_percent (verify with head -1 before trusting a new build's layout).
set -u
N=$1; A=$2
key() { awk -F, 'NR>1{print $1"|"$3"\t"$9"\t"substr($3,1,4)"\t"$10}' "$1"; }
key "$N" | LC_ALL=C sort > /tmp/paired_null.$$; key "$A" | LC_ALL=C sort > /tmp/paired_arm.$$
T="$(printf '\t')"
LC_ALL=C join -t "$T" /tmp/paired_null.$$ /tmp/paired_arm.$$ > /tmp/paired_shared.$$
LC_ALL=C join -t "$T" -v1 /tmp/paired_null.$$ /tmp/paired_arm.$$ > /tmp/paired_nullonly.$$
LC_ALL=C join -t "$T" -v2 /tmp/paired_null.$$ /tmp/paired_arm.$$ > /tmp/paired_armonly.$$
sum() { awk -F'\t' -v c="$2" '{n++; s+=$c} END{printf "n=%d pnl=$%.0f", n, s}' "$1"; }
echo "shared:    $(sum /tmp/paired_shared.$$ 2) (null pnl) / $(awk -F'\t' '{s+=$5} END{printf "$%.0f", s}' /tmp/paired_shared.$$) (arm pnl)"
echo "null-only: $(sum /tmp/paired_nullonly.$$ 2)"
echo "arm-only:  $(sum /tmp/paired_armonly.$$ 2)"
fd=$(cat /tmp/paired_nullonly.$$ /tmp/paired_armonly.$$ | awk -F'\t' '{print substr($1,index($1,"|")+1)}' | LC_ALL=C sort | head -1)
echo "first divergence (earliest entry present in only one arm): ${fd:-none}"
echo "--- per entry-year realised: year null_n null_pnl arm_n arm_pnl"
awk -F'\t' 'FNR==NR{nn[$3]++; np[$3]+=$2; next} {an[$3]++; ap[$3]+=$2} END{for(y in nn) ys[y]=1; for(y in an) ys[y]=1; for(y in ys) printf "%s %d $%.0f %d $%.0f\n", y, nn[y]+0, np[y]+0, an[y]+0, ap[y]+0}' /tmp/paired_null.$$ /tmp/paired_arm.$$ | sort
echo "--- arm-only cohort by entry-year: year n pnl winners>=+20% losers"
awk -F'\t' '{y=$3; n[y]++; p[y]+=$2; if($4>=20) w[y]++; if($2<0) l[y]++} END{for(y in n) printf "%s %d $%.0f %d %d\n", y, n[y], p[y], w[y]+0, l[y]+0}' /tmp/paired_armonly.$$ | sort
echo "--- null-only cohort by entry-year: year n pnl winners>=+20% losers"
awk -F'\t' '{y=$3; n[y]++; p[y]+=$2; if($4>=20) w[y]++; if($2<0) l[y]++} END{for(y in n) printf "%s %d $%.0f %d %d\n", y, n[y], p[y], w[y]+0, l[y]+0}' /tmp/paired_nullonly.$$ | sort
echo "--- arm-only top winners / losers"
sort -t"$T" -k2,2nr /tmp/paired_armonly.$$ | awk -F'\t' 'NR<=6{print "  arm-winner", $1, "$" int($2)}'
sort -t"$T" -k2,2n /tmp/paired_armonly.$$ | awk -F'\t' 'NR<=6{print "  arm-loser", $1, "$" int($2)}'
rm -f /tmp/paired_*.$$
