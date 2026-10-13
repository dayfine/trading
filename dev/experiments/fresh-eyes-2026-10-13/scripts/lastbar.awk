# Last weekly bar at or before the cut, on the chart's basis (rescaled so the close is the raw close), as JSON.
# Usage: awk -F, -v cut=... -v sym=... -v sector=... -f days.awk -f lastbar.awk <weekly.csv>
NR > 1 && days($1) <= friday(days(cut)) { r = $0 }
END {
  if (r == "") { printf "{\"symbol\":\"%s\",\"cut\":\"%s\",\"last_bar\":null}\n", sym, cut; exit }
  split(r, f, ","); k = f[9] / f[5]
  printf "{\"symbol\":\"%s\",\"sector\":\"%s\",\"cut\":\"%s\",\"week\":\"%s\",\"open\":%.4f,\"high\":%.4f,\"low\":%.4f,\"close\":%.4f,\"volume\":%.0f,\"ma30\":%s,\"rs_mansfield\":%s}\n", \
    sym, sector, cut, f[1], f[2] * k, f[3] * k, f[4] * k, f[9], f[6] * f[10], (f[7] == "" ? "null" : sprintf("%.4f", f[7] * k)), (f[8] == "" ? "null" : f[8])
}
