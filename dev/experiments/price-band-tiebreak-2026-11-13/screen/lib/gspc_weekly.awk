# Weekly (Monday-based) last adjusted close of a CSV store file: "week_index<TAB>adjusted_close".
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
NR > 1 && $6 + 0 > 0 { w = week_of($1); if (w != lw && lw != "") print lw "\t" c; lw = w; c = $6 }
END { print lw "\t" c }
