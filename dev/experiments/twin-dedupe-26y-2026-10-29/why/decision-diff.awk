# Per screening Friday, the decisions present in one arm and not the other, flagged with how many removed twins the cur
# arm held in its recorded top-N that week (the list in force: dated May 31 of year Y governs [Y-05-31, Y+1-05-31)).
# Usage: awk -f decision-diff.awk removed.txt cur-decisions.txt dd-decisions.txt
#   prints: DATE twin=N | cur-only: SYM:OUTCOME ... | dd-only: SYM:OUTCOME ...   (dates with identical lists are skipped)
function gov_year(d,   y, md) { y = substr(d, 1, 4) + 0; md = substr(d, 6, 5); if (md < "05-31") y--; return y }
FILENAME == ARGV[1] { rem[$1 " " $2] = 1; next }
FILENAME == ARGV[2] { cur[$1] = $7; next }
{
  d = $1; if (!(d in cur) || cur[d] == $7) next
  split("", C); split("", Dd); nc = split(cur[d], A, ","); for (i = 1; i <= nc; i++) C[A[i]] = 1
  ndd = split($7, B, ","); for (i = 1; i <= ndd; i++) Dd[B[i]] = 1
  tw = 0; y = gov_year(d); for (k in C) { split(k, P, ":"); if ((y " " P[1]) in rem) tw++ }
  co = ""; for (k in C) if (!(k in Dd)) co = co " " k
  dO = ""; for (k in Dd) if (!(k in C)) dO = dO " " k
  print d, "twin=" tw, "| cur-only:" co, "| dd-only:" dO
}
