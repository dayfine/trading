# unfilled_specs.awk -- tickets the code placed but never filled, with NAV at placement.
# usage: awk -F'\t' -v k=SEED -f unfilled_specs.awk equity_curve.csv entries.tsv
# out: seed pid sym placement E stop nav
FILENAME ~ /equity/ { split($0, a, ","); if (FNR > 1) { nd[++n] = a[1]; nv[n] = a[2] }; next }
$10 == 0 && $17 > 0 && $18 > 0 { sd = $24; j = 1; while (j < n && nd[j + 1] <= sd) j++; print k "\t" $3 "\t" $1 "\t" sd "\t" $17 "\t" $18 "\t" nv[j] }
