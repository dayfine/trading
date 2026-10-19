#!/bin/sh
T0=/Users/difan/Projects/trading-1/.sweep-output/breadth-pair-N/rb1-26-s0-v12-trades.csv
for p in "MTB 2016-11-11 2017-11-11" "EXPO 2016-11-11 2017-11-11" "BK 2016-11-11 2017-11-11" "SLF 2016-11-11 2017-11-11" "VTR 2003-05-23 2004-05-23" "TDG 2023-01-20 2024-01-20" "AVGO 2013-07-01 2013-09-30" "CMI 2007-02-23 2008-02-23" "WKC 2005-01-07 2006-01-07" "GIS 2005-01-07 2006-01-07" "AKRX 2013-08-30 2014-08-30" "KALU 2013-08-30 2014-08-30" "ASL 2003-05-23 2004-05-23" "AMGN 2017-07-14 2018-07-14" "DCI 2018-09-07 2019-09-07" "WPC 2023-01-20 2024-01-20"; do
  set -- $p; s=$1; a=$2; b=$3
  la=$(awk -F, -v s=$s -v a=$a -v b=$b '$1==0 && $4==s && $2>=a && $2<=b {n++; o[$6]++; if (f=="") f=$2; l=$2} END {printf "%d appearances", n; for (k in o) printf " %s=%d", k, o[k]; if (n) printf " (%s..%s)", f, l}' decisions.csv)
  tr=$(awk -F, -v s=$s 'NR>1 && $1==s {printf "%s->%s %s %+.1f%%; ", $3, $4, $13, $10}' $T0)
  echo "$s from $a, next 12 months: $la | record s0 trades ever: ${tr:-none}"
done
