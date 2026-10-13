#!/bin/sh
# Fresh-eyes study, plan §2: the pool and the stratified seeded draw of 100 symbols.
# Usage (repo root): DATA=<data dir, default data> sh dev/experiments/fresh-eyes-2026-10-13/scripts/sample.sh
# Writes results/pool.txt (symbol first_list_year weeks) and results/sample.txt (stratum symbol first_list_year).
# Pool: in the yearly PIT top-3000 lists, >= 156 weekly bars inside 2000-01-01..2026-06-30.
# Strata by first list year: 2000-04 (list years <= 2004, incl. 1998-99), 2005-09, 2010-14, 2015-19, 2020-25.
# Draw: pool sorted by symbol, one rand() per row after srand(20261013), 20 lowest keys per stratum.
set -e
E=dev/experiments/fresh-eyes-2026-10-13; DATA=${DATA:-data}
MEM=dev/experiments/short-setup-map-2026-10-12/results/membership.txt
mkdir -p $E/results
sort -k1,1 $MEM | while read -r s first rest; do
  a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); f=$DATA/$a/$b/$s/data.csv
  [ -f "$f" ] || continue
  w=$(awk -F, 'NR>1 && $1>="2000-01-01" && $1<="2026-06-30" && $5+0>0 { split($1,d,"-"); \
      y=d[1]+0; m=d[2]+0; dd=d[3]+0; if (m<=2) { y--; m+=12 } \
      n=365*y+int(y/4)-int(y/100)+int(y/400)+int((153*(m-3)+2)/5)+dd; k[int((n+2)/7)]=1 } \
      END { c=0; for (x in k) c++; print c }' "$f")
  [ "$w" -ge 156 ] && echo "$s $first $w"
done > $E/results/pool.txt
awk 'BEGIN { srand(20261013) }
  { y=$2+0; st=(y<=2004)?"2000-04":(y<=2009)?"2005-09":(y<=2014)?"2010-14":(y<=2019)?"2015-19":"2020-25"
    printf "%s %.9f %s %s\n", st, rand(), $1, $2 }' $E/results/pool.txt \
  | sort -k1,1 -k2,2 | awk '{ c[$1]++; if (c[$1] <= 20) print $1, $3, $4 }' > $E/results/sample.txt
wc -l $E/results/pool.txt $E/results/sample.txt
