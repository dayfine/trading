# dates.awk -- day and week numbers of an ISO date, the formulas of the screen's lib/mscan.awk (week_of there).
# Monday-to-Sunday weeks; every bar of one trading week shares a week_of. POSIX awk.
function days(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd
}
function week_of(d) { return int((days(d) + 1) / 7) }
