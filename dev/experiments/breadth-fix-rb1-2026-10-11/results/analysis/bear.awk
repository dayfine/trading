# period return from the close on/just before d0 to the close on/just before d1; in-period max DD; avg invested
# inputs: spy_regime.csv expo_X.csv ; vars d0 d1 tag
FILENAME ~ /spy_regime/ {spy[$1]=$2; next}
{ d=$1; if(d<=d0){ base=$2; sbase=spy[d]; pk=$2 } else if(d<=d1){ v=$2; if(v>pk) pk=v; dd=1-v/pk; if(dd>mdd) mdd=dd; ex+=$3; n++; last=v; slast=spy[d] } }
END{ printf "%-5s %+7.2f%% (SPY %+6.1f%%) maxDD %5.2f%% inv %4.1f%%\n", tag, 100*(last/base-1), 100*(slast/sbase-1), 100*mdd, ex/n }
