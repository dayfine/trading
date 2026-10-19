#!/bin/sh
for p in "2003-05-23 ASL" "2005-01-07 GIS" "2005-01-07 WKC" "2007-02-23 CMI" "2013-08-30 KALU" "2013-08-30 AKRX" "2016-11-11 MTB" "2016-11-11 EXPO" "2016-11-11 BK" "2016-11-11 SLF" "2017-07-14 AMGN" "2018-09-07 DCI" "2023-01-20 WPC"; do
  set -- $p
  awk -F, -v d=$1 -v s=$2 '$1==d && $4==s {printf "%s %-5s aoff %3s close below 90-bar high by %5.1f%%\n", d, s, $6, 100*($8-$11)/$8}' lists_scan.csv
done
