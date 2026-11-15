# row.awk -- the one mark-free surface.tsv row of an arm, from pair.awk's per-seed M lines, with the flag rule of
# dev/plans/axis-observatory-2026-11-14.md §3 (set before any arm ran; change it only before P3 starts).
# Environment: OBS_LABEL, OBS_OVERLAY, OBS_COMMIT. Variables: arms_run, v6; header=1 prints only the header.
# Needs common.awk. The columns are defined in ../../README.md §Definitions.
BEGIN { FS = "\t"
  FLAG_D_END = 0.20        # the median D_end must reach this many log points (UP), or its negative (HARM)
  FLAG_SIGN_RATE = 0.60    # share of one seed's yearly increments that carry the flag's sign ...
  FLAG_SEEDS = 4           # ... in at least this many seeds
  FLAG_STEP_SHARE = 0.5    # the median over seeds of the largest single step's share of D_end must stay under this
  MARK_MAX = 10000         # computed fields are logs, rates, pp and counts: a larger magnitude is a leaked level
  H = "arms_run\tarm\toverlay\tcommit\tseeds\tyears\tv6\td_end_med\td_end_seeds\tyr_pos_rate\tyr_neg_rate"
  H = H "\tseeds_pos60\tseeds_neg60\td_mac_bull\td_mac_neut\td_mac_bear\td_bull_yr\td_bear_yr\tstep_max_med"
  H = H "\tstep_max_seeds\ttop5_seed\ttop5_steps\td_maxdd_pp\td_ulcer\td_pos_held\td_entries_yr\ts_out\ta_new\tflag"
  if (header) { print H; exit } }
$1 == "M" { n++; for (c = 2; c <= NF; c++) F[n, c] = $c }
function med(c, na,   i, j, m, v, x) {   # median of column c over seeds; an NA value is na ("NA" makes the median NA)
  for (i = 1; i <= n; i++) { v = F[i, c]; if (v == "NA") { if (na == "NA") return "NA"; v = na }
    m++; x[m] = v + 0; for (j = m; j > 1 && x[j - 1] > x[j]; j--) { v = x[j]; x[j] = x[j - 1]; x[j - 1] = v } }
  return (m % 2) ? x[(m + 1) / 2] : (x[m / 2] + x[m / 2 + 1]) / 2
}
function f(v, p) { return (v == "NA") ? v : fmt(v, p) }
function list(c,   i, o) { o = F[1, c]; for (i = 2; i <= n; i++) o = o "," F[i, c]; return o }
function midseed(   i, j, o, t) {   # the seed at the lower-middle rank of D_end (ties keep seed order)
  for (i = 1; i <= n; i++) { o[i] = i
    for (j = i; j > 1 && F[o[j - 1], 3] + 0 > F[o[j], 3] + 0; j--) { t = o[j]; o[j] = o[j - 1]; o[j - 1] = t } }
  return o[int((n + 1) / 2)]
}
function guard(r,   t, i, c, k, v) {   # every computed numeric field must stay under MARK_MAX in magnitude
  split(r, t, "\t")
  for (i = 5; i <= 28; i++) { if (i == 7 || (i >= 19 && i <= 22)) continue
    c = split(t[i], v, ",")
    for (k = 1; k <= c; k++) if (v[k] ~ /^[-+]?[0-9.]+$/ && (v[k] + 0 >= MARK_MAX || v[k] + 0 <= -MARK_MAX)) {
      print "obs_read: column " i " value " v[k] " looks like a price or NAV level; not appending" > "/dev/stderr"; exit 3 } }
}
END {
  if (header) exit
  if (n == 0) { print "obs_read: no per-seed lines" > "/dev/stderr"; exit 2 }
  for (i = 1; i <= n; i++) { yrs += F[i, 4]; pos += F[i, 5]; neg += F[i, 6]
    if (F[i, 4] > 0 && F[i, 5] / F[i, 4] >= FLAG_SIGN_RATE) spos++
    if (F[i, 4] > 0 && F[i, 6] / F[i, 4] >= FLAG_SIGN_RATE) sneg++ }
  d = med(3, "NA"); s = med(13, 1e9); ms = midseed()
  flag = (d >= FLAG_D_END && spos >= FLAG_SEEDS && s < FLAG_STEP_SHARE) ? "UP" : \
         (d <= -FLAG_D_END && sneg >= FLAG_SEEDS && s < FLAG_STEP_SHARE) ? "HARM" : "none"
  r = arms_run "\t" ENVIRON["OBS_LABEL"] "\t" ENVIRON["OBS_OVERLAY"] "\t" ENVIRON["OBS_COMMIT"] "\t" n "\t" F[1, 4] "\t" v6
  r = r "\t" fmt(d, 4) "\t" list(3) "\t" (yrs ? fmt(pos / yrs, 3) : "NA") "\t" (yrs ? fmt(neg / yrs, 3) : "NA") "\t" (spos + 0)
  r = r "\t" (sneg + 0) "\t" f(med(7, "NA"), 4) "\t" f(med(8, "NA"), 4) "\t" f(med(9, "NA"), 4) "\t" f(med(11, "NA"), 4)
  r = r "\t" f(med(12, "NA"), 4) "\t" (s == 1e9 ? "NA" : fmt(s, 3)) "\t" list(13) "\t" F[ms, 2] "\t" F[ms, 14]
  r = r "\t" f(med(15, "NA"), 2) "\t" f(med(16, "NA"), 2) "\t" f(med(17, "NA"), 2) "\t" f(med(18, "NA"), 2)
  r = r "\t" f(med(19, 0), 1) "\t" f(med(20, 0), 1) "\t" flag
  guard(r); print r
}
