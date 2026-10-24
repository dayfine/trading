# One held position's price-only open gain at a NAV peak, on raw closes.
# Vars: ed, end (exit day or run end), peak_date, ep, qty, side.
# A later split basis cannot be reconstructed from a cash-adjusted price ratio:
# conservatively return null when the adjustment factor moves >5% during the hold,
# or the entry fill is not on its bar's raw basis. Dividends are not open gain.
BEGIN { FS = "," }
NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
{
  d = $(col["date"]); c = $(col["close"]) + 0; a = $(col["adjusted_close"]) + 0
  if (d > end || c <= 0 || a <= 0) next
  if (d <= ed) { low = $(col["low"]) + 0; high = $(col["high"]) + 0; have_entry = 1; f = a / c }
  if (d > ed) {
    ratio = f > 0 ? (a / c) / f : 1
    if (ratio > 1.05 || ratio < 0.95) ambiguous = 1
    f = a / c
  }
  if (d <= peak_date && d >= ed) { mark = c; have_mark = 1 }
}
END {
  if (!col["close"] || !col["adjusted_close"] || !col["low"] || !col["high"] || !have_entry || !have_mark || ambiguous || ep <= 0 || qty <= 0 || (side != "LONG" && side != "SHORT") || ep < low * 0.995 || ep > high * 1.005) print "null"
  else printf "%.2f\n", (side == "SHORT" ? -1 : 1) * qty * (mark - ep)
}
