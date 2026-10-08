#!/bin/sh
# pid -> replay stage at entry/exit week, Stage3/Stage4 weeks during hold, hold weeks,
# Stage2 weeks during hold (a short's wrong-side stage, #3149)
D=$1
tail -n +2 "$D/trades.csv" | awk -F, '{print $20, $3, $4}' | while read pid ed xd; do
  f="$D/stage/$pid.png.csv"; [ -s "$f" ] || continue
  awk -F, -v pid="$pid" -v ed="$ed" -v xd="$xd" 'NR>1 { if ($2 <= ed) se=$5; if ($2 <= xd) sx=$5; if ($2 >= ed && $2 <= xd) { h++; if ($5=="Stage2") s2++; if ($5=="Stage3") s3++; if ($5=="Stage4") s4++ } }
    END { printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\n", pid, se, sx, s3, s4, h, s2 }' "$f"
done
