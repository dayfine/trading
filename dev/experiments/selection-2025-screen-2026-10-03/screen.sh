#!/bin/sh
# selection-2025-screen-2026-10-03: 26-week forward returns, from each 2025 decision date, for
#   SPY | the investor picks | the screener's skipped alternatives | the equal-weight PIT top-3000 (2025 list) by
#   dollar-volume tier. Then a bootstrap: how often 24 random draws from each pool have a median <= the picks'.
# Read-only, host only (no container). Usage, from the repo root:
#   sh dev/experiments/selection-2025-screen-2026-10-03/screen.sh <trade_audit.sexp> <out_dir>
set -eu
AUDIT=$1; OUT=$2; mkdir -p "$OUT"
UNIV=trading/test_data/backtest_scenarios/pit-v11/composition/top-3000-2025.sexp
FROM=2025-05-23; TO=2025-12-31; HORIZON_DAYS=182

# 1. Picks and alternatives per decision (kind,date,sym,reason,score).
awk -v from=$FROM -v to=$TO '
/^ +\(\(symbol [A-Z0-9.-]+\) \(entry_date [0-9-]+\)/ { match($0,/symbol [A-Z0-9.-]+/); sym=substr($0,RSTART+7,RLENGTH-7)
  match($0,/entry_date [0-9-]+/); d=substr($0,RSTART+11,RLENGTH-11); inalt=0
  if (d>=from && d<=to) { keep=1; print "PICK," d "," sym ",entered," } else keep=0; next }
keep && /alternatives_considered/ { inalt=1 }
keep && inalt && /\(\(symbol [A-Z0-9.-]+\) \(side/ { match($0,/symbol [A-Z0-9.-]+/); asym=substr($0,RSTART+7,RLENGTH-7); match($0,/score -?[0-9]+/); sc=substr($0,RSTART+6,RLENGTH-6) }
keep && inalt && /reason_skipped/ { match($0,/reason_skipped [A-Za-z_]+/); print "ALT," d "," asym "," substr($0,RSTART+15,RLENGTH-15) "," sc }
' "$AUDIT" > "$OUT/cands.csv"

# 2. Decision date -> horizon end date (BSD date).
cut -d, -f2 "$OUT/cands.csv" | sort -u | while read -r d; do
  echo "$d $(date -j -v+${HORIZON_DAYS}d -f %Y-%m-%d "$d" +%Y-%m-%d)"; done > "$OUT/datemap.txt"

# 3. Universe ranks (file order = dollar volume) and the symbol set.
grep -oE '\(symbol [A-Z0-9.-]+\)' $UNIV | sed 's/(symbol //; s/)//' | awk '{print NR","$0}' > "$OUT/univ.csv"
{ cut -d, -f2 "$OUT/univ.csv"; cut -d, -f3 "$OUT/cands.csv"; echo SPY; } | sort -u > "$OUT/syms.txt"

# 4. Forward return on adjusted_close: last bar <= decision date -> first bar >= decision + horizon.
#    A symbol with no bar at the horizon end (delisted) is dropped -- an upward bias on the universe rows.
: > "$OUT/fwd.csv"
while read -r sym; do
  f=data/$(printf %s "$sym" | cut -c1)/$(printf %s "$sym" | rev | cut -c1)/$sym/data.csv; [ -f "$f" ] || continue
  awk -F, -v sym="$sym" -v dm="$OUT/datemap.txt" 'BEGIN{ while ((getline l < dm) > 0) { split(l,a," "); D[a[1]]=a[2] } }
    NR>1 && $6>0 { for (d in D) { if ($1<=d) base[d]=$6; if ($1>=D[d] && !(d in endv)) endv[d]=$6 } }
    END{ for (d in D) if ((d in base) && (d in endv)) printf "%s,%s,%.5f\n", sym, d, endv[d]/base[d]-1 }' "$f" >> "$OUT/fwd.csv"
done < "$OUT/syms.txt"
awk -F, 'FILENAME==ARGV[1]{R[$2]=1;next} ($1 in R)' "$OUT/univ.csv" "$OUT/fwd.csv" > "$OUT/fwd_univ.csv"

# 5. Distribution per group.
awk -F, '
FILENAME==ARGV[1] { F[$1","$2]=$3; next }
FILENAME==ARGV[2] { R[$2]=$1; next }
FILENAME==ARGV[3] { k=$3","$2; if (k in F) print (($1=="PICK") ? "2pick" : "3alt") "," F[k]; next }
END { for (k in F) { split(k,a,","); if (a[1]=="SPY") { print "1SPY," F[k]; continue }
    if (!(a[1] in R)) continue; r=R[a[1]]+0; print "4univ_all," F[k]
    print ((r<=100) ? "5univ_top100" : (r<=500) ? "6univ_101_500" : (r<=1500) ? "7univ_501_1500" : "8univ_1501_3000") "," F[k] } }
' "$OUT/fwd.csv" "$OUT/univ.csv" "$OUT/cands.csv" | sort -t, -k1,1 -k2,2g | awk -F, '
function flush() { if (g=="") return
  printf "| %s | %d | %.1f %% | %.1f %% | %.1f %% | %.1f %% | %.1f %% | %.1f %% | %.0f %% |\n", substr(g,2), m, 100*s/m,
    100*x[int(.1*(m-1))+1], 100*x[int(.25*(m-1))+1], 100*x[int(.5*(m-1))+1], 100*x[int(.75*(m-1))+1], 100*x[int(.9*(m-1))+1], 100*neg/m }
BEGIN { print "| group | n | mean | p10 | p25 | median | p75 | p90 | negative |"; print "|---|---:|---:|---:|---:|---:|---:|---:|---:|" }
$1!=g { flush(); g=$1; m=0; s=0; neg=0; delete x }
{ m++; s+=$2; x[m]=$2; if ($2<0) neg++ }
END { flush() }' > "$OUT/distribution.md"

# 6. Bootstrap (seed 7, 20,000 draws of 24).
awk -F, 'FILENAME==ARGV[1] { F[$1","$2]=$3; next }
FILENAME==ARGV[2] { k=$3","$2; if (k in F) { if ($1=="PICK") P[++np]=F[k]; else A[++na]=F[k] } next }
FILENAME==ARGV[3] { U[++nu]=$3 }
function med(v,m,  i,j,t) { for (i=2;i<=m;i++) { t=v[i]; j=i-1; while (j>0 && v[j]>t) { v[j+1]=v[j]; j-- } v[j+1]=t }
  return (m%2) ? v[(m+1)/2] : (v[m/2]+v[m/2+1])/2 }
END { srand(7); for (i=1;i<=np;i++) pp[i]=P[i]; pm=med(pp,np); N=20000
  for (r=1;r<=N;r++) { for (i=1;i<=np;i++) s[i]=A[int(rand()*na)+1]; if (med(s,np)<=pm) ca++
                       for (i=1;i<=np;i++) s[i]=U[int(rand()*nu)+1]; if (med(s,np)<=pm) cu++ }
  printf "picks n=%d median %.1f %%; P(median of %d alternatives <= it) = %.3f; P(median of %d universe draws <= it) = %.3f\n", np, 100*pm, np, ca/N, np, cu/N }
' "$OUT/fwd.csv" "$OUT/cands.csv" "$OUT/fwd_univ.csv" > "$OUT/bootstrap.txt"

# 7. Per pick, paired with SPY on the same decision date.
awk -F, 'FILENAME==ARGV[1] { F[$1","$2]=$3; next }
$1=="PICK" { k=$3","$2; printf "| %s | %s | %.1f %% | %.1f %% | %+.1f pp |\n", $2, $3, 100*F[k], 100*F["SPY,"$2], 100*(F[k]-F["SPY,"$2]) }
' "$OUT/fwd.csv" "$OUT/cands.csv" > "$OUT/picks.md"
cat "$OUT/distribution.md" "$OUT/bootstrap.txt"
