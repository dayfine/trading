# N-O log return by regime over [d0,d1]; inputs: regime file, expo_O, expo_N (same salt)
FILENAME==ARGV[1] {reg[$1]=$3; next}
FILENAME==ARGV[2] {if(po!="") lo[$1]=log($2/po); po=$2; next}
{ d=$1; if(pn!="" && d>=d0 && d<=d1 && reg[d]!=""){ r=reg[d]; dl[r]+=log($2/pn)-lo[d] } pn=$2 }
END{ printf "UP %+.4f MIXED %+.4f DOWN %+.4f\n", dl["UP"], dl["MIXED"], dl["DOWN"] }
