#!/bin/sh
# stat.sh <file of "key<TAB>value" lines> : n mean median p10 p25 p75 p90 beat per key (lower-nearest quantile, as analyze.awk)
sort -t'	' -k1,1 -k2,2g "$1" | awk -F'\t' '
function flush(){ if(n==0) return; printf "%-28s n=%6d mean=%+7.2f%% med=%+7.2f%% p10=%+6.1f p25=%+6.1f p75=%+6.1f p90=%+6.1f beat=%5.1f%%\n", k, n, 100*s/n, 100*v[int(0.5*(n-1))+1], 100*v[int(0.1*(n-1))+1], 100*v[int(0.25*(n-1))+1], 100*v[int(0.75*(n-1))+1], 100*v[int(0.9*(n-1))+1], 100*p/n }
$1!=k { flush(); k=$1; n=0; s=0; p=0; delete v }
{ n++; v[n]=$2+0; s+=$2; if ($2+0>0) p++ }
END{ flush() }'
