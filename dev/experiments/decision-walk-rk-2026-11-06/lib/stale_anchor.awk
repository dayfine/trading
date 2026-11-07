# Stale-anchor footprint from the stop decisions (stopdec_bars.tsv sorted by sym, pid, date).
# After a completed cycle (Raised / Cycle_stalled) both trailing extremes reset to that bar's close c. The correction
# extreme then only moves down (running min of lows), and the phantom-cycle guard needs a bar to touch it. While no bar
# has traded at or below c, the extreme stays exactly c: the anchor is stale, every later pullback that holds above c
# is invisible to the cycle test, and no cycle can complete until price returns to c.
# Per position: weeks spent stale (from the first stale row to the last), the trend extreme reached above c,
# and the reasons logged while stale. Output: pid sym first_stale last_stale weeks max_advance_above_anchor n_rows reasons
function jd(d,   y, m, dd) { y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd }
function flush_run() { if (rs != "") { w = (jd(re) - jd(rs)) / 7; if (w > best_w) { best_w = w; bs = rs; be = re; bx = rx; bn = rn; br = rr_ } } rs = ""; re = ""; rx = 0; rn = 0; rr_ = "" }
function flush_pos() { flush_run(); if (cur != "" && best_w > 0) printf "%s\t%s\t%s\t%s\t%.1f\t%.3f\t%d\t%s\n", cur, csym, bs, be, best_w, bx, bn, br; best_w = 0 }
BEGIN { FS = "\t" }
$1 != cur { flush_pos(); cur = $1; csym = $2; anchor = ""; best_w = 0 }
{
  if (anchor != "" && $4 == "Trailing" && ($14 == "No_correction_yet" || $14 == "Correction_not_recovered" || $14 == "Anchor_not_fresh")) {
    if ($12 + 0 >= anchor * (1 - 1e-9)) { if (rs == "") rs = $3; re = $3; adv = $11 / anchor - 1; if (adv > rx) rx = adv; rn++; if (index(rr_, $14) == 0) rr_ = rr_ (rr_ == "" ? "" : ",") $14 }
    else flush_run()
  } else if ($14 != "Raised" && $14 != "Cycle_stalled") flush_run()
  if ($14 == "Raised" || $14 == "Cycle_stalled") { flush_run(); anchor = $15 + 0 }
  if ($5 != "Trailing") anchor = ""
}
END { flush_pos() }
