#!/bin/sh
R=${R:-dev/experiments/fresh-eyes-dated-2026-10-18/results/run}   # run from the repo root
T=$(mktemp -d)
syms() { awk -F, 'NR>1{print $2}' "$1/pool.csv" | sort > "$2"; }
slsyms() { awk -F, 'FNR==1{f++} f==1&&FNR>1{s[$1]=$2} f==2&&$1!=""{print s[$1]}' "$1/pool.csv" "$1/shortlist.txt" | sort > "$2"; }
for d in 2003-05-23 2009-01-16 2016-11-11 2023-01-20; do
  for a in "$d" "$d-r1" "$d-r2"; do for b in "$d" "$d-r1" "$d-r2"; do
    [ "$a" = "$b" ] && continue
    case "$a|$b" in "$d-r1|$d"|"$d-r2|$d"|"$d-r2|$d-r1") continue;; esac
    syms $R/$a $T/pa; syms $R/$b $T/pb; pc=$(comm -12 $T/pa $T/pb | wc -l | tr -d ' ')
    slsyms $R/$a $T/sa; slsyms $R/$b $T/sb; sc=$(comm -12 $T/sa $T/sb | wc -l | tr -d ' ')
    awk -F, 'NR>1{print $1","$2}' $R/$a/pool.csv | sort > $T/qa; awk -F, 'NR>1{print $1","$2}' $R/$b/pool.csv | sort > $T/qb
    ps=$(comm -12 $T/qa $T/qb | wc -l | tr -d ' ')
    printf "%-14s %-14s pool_common %3s/120 same_pseudo %3s shortlist_common %2s/10 groups %s | %s\n" $a $b $pc $ps $sc "$(cat $R/$a/groups.txt)" "$(cat $R/$b/groups.txt)"
  done; done
done
rm -rf $T
