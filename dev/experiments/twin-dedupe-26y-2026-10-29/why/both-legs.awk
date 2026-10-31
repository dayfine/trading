# Weeks where BOTH legs of one twin pair (dropped leg and its survivor, per twin-drops.txt) sit in the recorded top-N.
# Usage: awk -f both-legs.awk pit-v12/twin-drops.txt <arm>-decisions.txt   -> DATE DROPPED#RANK SURVIVOR#RANK
function gov_year(d,   y, md) { y = substr(d, 1, 4) + 0; md = substr(d, 6, 5); if (md < "05-31") y--; return y }
NR == FNR { if ($1 ~ /^top-3000-/) surv[(substr($1, 10, 4) + 0) " " $2] = $3; next }
{ y = gov_year($1); n = split($7, A, ","); split("", at)
  for (i = 1; i <= n; i++) { split(A[i], B, ":"); at[B[1]] = i }
  for (s in at) if ((y " " s) in surv) { v = surv[y " " s]; if (v in at) print $1, s "#" at[s], v "#" at[v] } }
