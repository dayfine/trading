# Append group_rel (sector median 26w return minus SPY's, at the breakdown date) to events.csv.
# Usage: awk -F, -f join_group.awk results/sector-median.csv data/sectors.csv results/events.csv
FILENAME ~ /sector-median/ { if ($2 == "SPY") spy[$1] = $3; else med[$1, $2] = $3; next }
FILENAME ~ /sectors.csv/ { if (FNR > 1) sec[$1] = $2; next }
FNR == 1 { print $0 ",sector,group_rel"; next }
{ s = sec[$1]; g = ((($2, s) in med) && ($2 in spy) && s != "") ? sprintf("%.5f", med[$2, s] - spy[$2]) : ""
  print $0 "," s "," g }
