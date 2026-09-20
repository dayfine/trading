#!/bin/sh
# Paired read of one salt: sh paired.sh <null-trades.csv> <arm-trades.csv>
# Join key symbol|entry_date (position_id differs across runs). Prints shared / null-only / arm-only counts + realised P&L,
# per-entry-year realised for both arms, and the four re-entry episodes (2003, 2009, 2020, 2022-23) per side.
set -u
N=$1; A=$2
key() { awk -F, 'NR>1{print $1"|"$3"\t"$9"\t"substr($3,1,4)}' "$1"; }
key "$N" | LC_ALL=C sort > /tmp/paired_null.$$; key "$A" | LC_ALL=C sort > /tmp/paired_arm.$$
LC_ALL=C join -t "$(printf '\t')" /tmp/paired_null.$$ /tmp/paired_arm.$$ > /tmp/paired_shared.$$
LC_ALL=C join -t "$(printf '\t')" -v1 /tmp/paired_null.$$ /tmp/paired_arm.$$ > /tmp/paired_nullonly.$$
LC_ALL=C join -t "$(printf '\t')" -v2 /tmp/paired_null.$$ /tmp/paired_arm.$$ > /tmp/paired_armonly.$$
sum() { awk -F'\t' -v c="$2" '{n++; s+=$c} END{printf "n=%d pnl=$%.0f", n, s}' "$1"; }
echo "shared:    $(sum /tmp/paired_shared.$$ 2) (null pnl) / $(awk -F'\t' '{s+=$4} END{printf "$%.0f", s}' /tmp/paired_shared.$$) (arm pnl)"
echo "null-only: $(sum /tmp/paired_nullonly.$$ 2)"
echo "arm-only:  $(sum /tmp/paired_armonly.$$ 2)"
echo "--- per entry-year realised: year null_n null_pnl arm_n arm_pnl"
awk -F'\t' 'FNR==NR{nn[$3]++; np[$3]+=$2; next} {an[$3]++; ap[$3]+=$2} END{for(y in nn) ys[y]; for(y in an) ys[y]; n=asorti(ys, o); for(i=1;i<=n;i++){y=o[i]; printf "%s %d $%.0f %d $%.0f\n", y, nn[y], np[y], an[y], ap[y]}}' /tmp/paired_null.$$ /tmp/paired_arm.$$ 2>/dev/null || \
awk -F'\t' 'FNR==NR{nn[$3]++; np[$3]+=$2; next} {an[$3]++; ap[$3]+=$2} END{for(y in nn) print y, nn[y], "$" int(np[y]), an[y]+0, "$" int(ap[y]+0)}' /tmp/paired_null.$$ /tmp/paired_arm.$$ | sort
echo "--- episodes (entries dated in window): window side n pnl"
for w in 2003-01-01:2003-12-31 2009-01-01:2009-12-31 2020-03-01:2020-12-31 2022-01-01:2023-12-31; do lo=${w%%:*}; hi=${w#*:}
  for side in null arm; do f=/tmp/paired_$side.$$; awk -F'\t' -v lo="$lo" -v hi="$hi" -v w="$w" -v s="$side" '{d=substr($1,index($1,"|")+1)} d>=lo && d<=hi {n++; p+=$2} END{printf "%s %s n=%d pnl=$%.0f\n", w, s, n, p}' "$f"; done; done
echo "--- 2022 cohort removed by the arm (null-only entries dated 2022): top losers / winners by pnl"
awk -F'\t' '{d=substr($1,index($1,"|")+1)} d>="2022-01-01" && d<="2022-12-31"' /tmp/paired_nullonly.$$ | sort -t"$(printf '\t')" -k2,2n | awk -F'\t' 'NR<=8{print "  removed-loser", $1, "$" int($2)}'
awk -F'\t' '{d=substr($1,index($1,"|")+1)} d>="2022-01-01" && d<="2022-12-31"' /tmp/paired_nullonly.$$ | sort -t"$(printf '\t')" -k2,2nr | awk -F'\t' 'NR<=5{print "  removed-winner", $1, "$" int($2)}'
rm -f /tmp/paired_*.$$
