#!/bin/sh
# Validity gate 6 (interest reconstruction within +-2 % of cashinteresttotal) and the decision-8 read
# (README §Stopping rule): A, B, the bear-period table, give-back, calendar years, arm decisions.
# usage: sh decision8.sh   (after prep.sh; same env)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/common.sh"
cat > "$WORK/windows.txt" <<'EOF'
A_full,1999-12-31,2026-06-26
B1_2000-02,2000-03-24,2002-10-09
B2_2008-09,2007-10-09,2009-03-09
B3_2022,2022-01-03,2022-10-12
G1_2002-03,2002-10-09,2003-04-09
G2_2009,2009-03-09,2009-09-07
G3_2022-23,2022-10-12,2023-04-12
Y2000,1999-12-31,2000-12-31
Y2001,2000-12-31,2001-12-31
Y2002,2001-12-31,2002-12-31
Y2008,2007-12-31,2008-12-31
Y2009,2008-12-31,2009-12-31
Y2022,2021-12-31,2022-12-31
EOF
sx() { sed -nE "s/.*metric_type\.t\.$2 ([-0-9.e]+)\).*/\1/p" "$R/$1-v12-summary.sexp"; }
echo "=== gate 6: interest reconstruction (unscaled) vs cashinteresttotal; dividends and costs cross-checks"
printf 'cell\tCIT\trecon\tgap%%\tgate\tdiv_paid_sim\tdiv_recon\tcosts_residual\tborrow_est\tcomm_est\tmax|NAV_recon-V|\n'
: > "$WORK/rex.tsv"
for c in $CELLS; do
  out=$(awk -f "$HERE/recon.awk" -v DAY="$WORK/$c.day.csv" -v POS="$WORK/$c.pos.csv" "$DTB3" "$WORK/divs.csv" "$WORK/bars.csv" \
    "$R/$c-v12-trades.csv" "$R/$c-v12-equity_curve.csv")
  cit=$(sx "$c" cashinteresttotal); dps=$(sx "$c" dividendpaidshorttotal); pnl=$(sx "$c" totalpnl)
  fin=$(sed -nE 's/.*\(final_portfolio_value ([-0-9.]+)\).*/\1/p' "$R/$c-v12-summary.sexp")
  echo "$out" | awk -v c="$c" -v cit="$cit" -v dps="$dps" -v pnl="$pnl" -v fin="$fin" -v day="$WORK/$c.day.csv" '
    { for (i=1;i<=NF;i++) { split($i,kv,"="); v[kv[1]]=kv[2] } }
    END { g=100*(v["interest_recon"]/cit-1); res=1000000+pnl+cit-dps-fin
      while ((getline l < day) > 0) { split(l,f,","); d=f[9]-f[2]; if (d<0) d=-d; if (d>m) m=d }
      printf "%s\t%.2f\t%.2f\t%+.3f\t%s\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.0f\n", c, cit, v["interest_recon"], g, (g<2 && g>-2 ? "PASS" : "FAIL"),
        dps, v["dividends_paid"], res, v["borrow_est"], v["commission_est"], m }'
  awk -f "$HERE/rex.awk" -v CIT="$cit" -v CELL="$c" "$WORK/$c.day.csv" "$WORK/spy.csv" "$R/$c-v12-trades.csv" "$WORK/windows.txt" >> "$WORK/rex.tsv"
  awk -F, -v c="$c" 'NR==FNR { d[$1]=$5; next } FNR>1 { x=-$25-d[$20]; if (x<0) x=-x; if (x>0.05) k++; n++ }
    END { printf "  %s per-position dividends paid vs trades.csv dividends_received: %d positions, %d differ by > 5 cents\n", c, n, k+0 }' \
    "$WORK/$c.pos.csv" "$R/$c-v12-trades.csv"
done
echo
echo "=== decision 8 windows: cell window from to Rex_log Rex_\$ ln(V1/V0) L_int SPY_TR mean_short_exp% fills div_paid interest_stripped realised_covers V_start V_end both>0 | L_cost H_index_short names=Rex+L_cost-H"
cat "$WORK/rex.tsv"
echo
echo "=== A and B per cell, arm decision (>= 2 of 3 valid salts)"
awk -F'\t' '{ k=$1; if ($2=="A_full") a[k]=$17; if ($2 ~ /^B[123]_/) { if ($17=="PASS") b[k]++; nb[k]++ } cells[k]=1 }
  END { for (k in cells) { B=(b[k]>=2 ? "PASS" : "fail"); J=(a[k]=="PASS" && B=="PASS") ? "PASS" : "fail"
          printf "%s A=%s B=%s (%d of %d bear periods) joint=%s\n", k, a[k], B, b[k]+0, nb[k], J
          split(k, p, "-"); arm=p[1]; if (J=="PASS") pa[arm]++; na[arm]++ }
        for (arm in na) printf "ARM %s: %d of %d salts pass -> %s\n", arm, pa[arm]+0, na[arm], (pa[arm]+0>=2 ? "PASSES decision 8" : "does NOT pass decision 8") }' "$WORK/rex.tsv" | sort
echo
echo "=== salt spread of R_ex (log, \$) per arm and window"
awk -F'\t' '{ split($1,p,"-"); k=p[1] "\t" $2; if (!(k in lo) || $5<lo[k]) lo[k]=$5; if (!(k in hi) || $5>hi[k]) hi[k]=$5
  if (!(k in lo2) || $6<lo2[k]) lo2[k]=$6; if (!(k in hi2) || $6>hi2[k]) hi2[k]=$6 }
  END { for (k in lo) printf "%s\tlog %.4f..%.4f (spread %.4f)\t$ %.4f..%.4f\n", k, lo[k], hi[k], hi[k]-lo[k], lo2[k], hi2[k] }' "$WORK/rex.tsv" | sort
