# Removed-twin legs in an arm's recorded top-N: DATE TWIN OUTCOME RANK N_DECISIONS LONG_TOP_N ENTERED
# Usage: awk -f twin-slots.awk removed.txt <arm>-decisions.txt
function gov_year(d,   y, md) { y = substr(d, 1, 4) + 0; md = substr(d, 6, 5); if (md < "05-31") y--; return y }
NR == FNR { rem[$1 " " $2] = 1; next }
{ y = gov_year($1); n = split($7, A, ","); if ($7 == "") n = 0
  for (i = 1; i <= n; i++) { split(A[i], B, ":"); if ((y " " B[1]) in rem) print $1, B[1], B[2], i, n, $4, $5 } }
