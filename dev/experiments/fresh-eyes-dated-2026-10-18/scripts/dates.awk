# dates.awk: stratified draw of decision Fridays (see dates.sh). Needs days.awk.
# Draw (default): block b covers the Fridays in [z0 + (b-1) L, z0 + b L), L = (z1 - z0 + 7) / n; one is drawn
# uniformly. mode=nearest -v y=YEAR: reads "block date" lines and prints the date nearest YEAR-07-01.
BEGIN {
  if (mode == "nearest") { mid = days(y "-07-01"); next_ok = 1 }
  else {
    srand(seed); z0 = friday(days(from)); z1 = friday(days(to)); L = (z1 - z0 + 7) / n
    for (b = 1; b <= n; b++) {
      lo = z0 + (b - 1) * L; hi = z0 + b * L; k = 0
      for (z = z0; z <= z1; z += 7) if (z >= lo && z < hi) f[++k] = z
      print b, civil(f[1 + int(rand() * k)])
    }
    exit
  }
}
{ z = days($2) - mid; if (z < 0) z = -z; if (best == "" || z < bz) { best = $2; bz = z } }
END {
  if (mode != "nearest") exit
  print best
  if (substr(best, 1, 4) != y) printf "dates.sh: no drawn date in %s; nearest to %s-07-01 is %s\n", y, y, best > "/dev/stderr"
}
