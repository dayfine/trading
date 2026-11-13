# features.awk -- one row per unique trade (symbol + fill date, first seed that has it) with decision-time features.
# usage: awk -F'\t' -f features.awk pct.tsv entries-k0.tsv .. entries-k4.tsv specs.tsv floor.tsv replay.tsv
# out: pid fill_date trade% nav_pct ext_screen ext_fill E/fill rt4/fill code_stop_dist book_floor_dist vol_ratio rs
#      weeks_adv score ma_slope ticket_age macro          (book_floor_dist from floor.tsv N=13 M=4; blank when none)
FILENAME ~ /pct.tsv/ { P[$1, $2] = $3; next }
FILENAME ~ /entries-k/ { split(FILENAME, a, "entries-k"); k = substr(a[2], 1, 1); AGE[k, $3] = $7; SLOPE[k, $3] = $34; next }
FILENAME ~ /specs.tsv/ { VR[$1, $2] = $18; RSV[$1, $2] = $19; MAC[$1, $2] = $20; WK[$1, $2] = $21; SC[$1, $2] = $23; ER[$1, $2] = $12; SR[$1, $2] = $13; next }
FILENAME ~ /floor.tsv/ { FLD[$1, $2] = ($24 == "D" || $24 == "K") ? $25 : ""; next }
$4 != "NODATA" && $10 == 1 { k = $1; p = $2; key = $3 "|" $5; if (key in seen) next; seen[key] = 1
  sd = (ER[k, p] > 0) ? (ER[k, p] - SR[k, p]) / ER[k, p] : ""
  print p "\t" $5 "\t" P[k, p] "\t" 100 * $8 / $9 "\t" $11 "\t" $13 "\t" $14 "\t" $15 "\t" sd "\t" FLD[k, p] "\t" VR[k, p] "\t" RSV[k, p] "\t" WK[k, p] "\t" SC[k, p] "\t" SLOPE[k, p] "\t" AGE[k, p] "\t" MAC[k, p] }
