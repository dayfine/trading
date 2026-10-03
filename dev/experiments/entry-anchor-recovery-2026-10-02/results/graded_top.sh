#!/bin/sh
# usage: graded_top.sh <file with "SYM DATE ..." lines>  -> SYM DATE close maxhigh_56_420d
# Julian day arithmetic in awk; raw (unadjusted) high/close.
while read sym d rest; do
  f="data/$(printf %.1s "$sym")/$(printf %s "$sym" | tail -c 1)/$sym/data.csv"
  [ -f "$f" ] || { echo "$sym $d 0 0"; continue; }
  awk -F, -v d="$d" 'function jd(x, y,m,dd,a,yy,mm){ y=substr(x,1,4)+0; m=substr(x,6,2)+0; dd=substr(x,9,2)+0; a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3; return dd+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
    BEGIN{ J=jd(d); mh=0; c=0 }
    NR>1 { j=jd($1); if (j<=J) c=$5; if (j<=J-56 && j>=J-420 && $3+0>mh) mh=$3+0 }
    END{ print "'"$sym"'", d, c+0, mh }' "$f"
done
