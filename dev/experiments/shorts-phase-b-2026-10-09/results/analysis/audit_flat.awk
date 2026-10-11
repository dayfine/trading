# Flatten one trade_audit.sexp (pretty-printed) into three tab-separated row kinds.
#   T  one row per ticket (audit record):
#      pid sym decision_date side macro_at_decision suggested_entry close_at_decision installed_stop
#      stop_floor_kind placement_date age_at_fill age_at_cancel cancel_reason designed_trigger fill_price
#      exit_date exit_kind exit_stop_price exit_actual_price mfe mae initial_position_value
#      macro_confidence confidence_ex_momentum index_stage_signal index_stage_detail momentum_signal
#      weeks_declining rs_trend support_quality resistance_quality sector_rating cascade_score volume_ratio
#      stage_tag (S3toS4 = "Stage3->Stage4 breakdown" rationale, EarlyS4 = "Early Stage4")
#   S  one row per stop decision: pid date state_before state_after stop_before stop_after reason
#   C  one row per cascade week: date macro_trend short_macro short_breakdown short_sector short_rs
#      short_grade short_top_n entered n_placed n_no_structural_stop n_notional_cap n_sized_to_zero
#      n_share_class n_other
# usage: awk -f audit_flat.awk <cell>-trade_audit.sexp
function grab(s, key,    re) {
  re = "\\(" key " [^()]*\\)"
  if (match(s, re)) return substr(s, RSTART + length(key) + 2, RLENGTH - length(key) - 3)
  return ""
}
function nz(v) { return v == "" ? "-" : v }
function emit_ticket(    xk, xs, xa) {
  if (head == "") return
  gsub(/[ \t]+/, " ", head); gsub(/[ \t]+/, " ", xtext); gsub(/[ \t]+/, " ", etext)
  xk = ""; xs = ""; xa = ""
  if (match(xtext, /\(Stop_loss \(stop_price [-0-9.e]+\) \(actual_price [-0-9.e]+\)\)/)) {
    xk = "Stop_loss"; xs = grab(xtext, "stop_price"); xa = grab(xtext, "actual_price")
  } else if (match(xtext, /\(Strategy_signal \(label [A-Za-z_]+\)/)) {
    xk = grab(substr(xtext, RSTART, RLENGTH) ")", "label")
  } else if (match(xtext, /\(exit_trigger \(\(?[A-Za-z_]+/)) {
    xk = substr(xtext, RSTART + 14, RLENGTH - 14); gsub(/\(/, "", xk)
  }
  # macro indicators at decision: confidence as the simulator computes it (bullish weight / non-Neutral weight,
  # macro.ml _compute_confidence) and the same with the Momentum Index read as Neutral (see the A-D fixture note)
  mtxt = head; ab = 0; aa = 0; bb = 0; ba = 0; isig = "-"; idet = "-"; msig = "-"
  while (match(mtxt, /\(name ("[^"]*"|[^ )]+)\) \(signal [A-Za-z]+\) \(weight [0-9.]+\)( \(detail "[^"]*"\))?/)) {
    blk = substr(mtxt, RSTART, RLENGTH); mtxt = substr(mtxt, RSTART + RLENGTH)
    nm = blk; sub(/^\(name /, "", nm); sub(/\) \(signal.*/, "", nm); gsub(/"/, "", nm)
    sg = grab(blk, "signal"); wt = grab(blk, "weight") + 0
    dt = ""; if (match(blk, /\(detail "[^"]*"\)/)) dt = substr(blk, RSTART + 9, RLENGTH - 11)
    if (sg != "Neutral") { aa += wt; if (sg == "Bullish") ab += wt }
    if (sg != "Neutral" && nm != "Momentum Index") { ba += wt; if (sg == "Bullish") bb += wt }
    if (nm == "Index Stage") { isig = sg; idet = dt }
    if (nm == "Momentum Index") msig = sg
  }
  c1 = (aa > 0 ? ab / aa : 0.5); c2 = (ba > 0 ? bb / ba : 0.5)
  wd = "-"; if (match(head, /\(weeks_declining [0-9]+\)/)) wd = substr(head, RSTART + 17, RLENGTH - 18)
  rst = "-"; if (match(head, /\(rs_trend \([A-Za-z_]+\)\)/)) { rst = substr(head, RSTART + 11, RLENGTH - 13) }
  spq = "-"; if (match(head, /\(support_quality \([A-Za-z_]+\)\)/)) { spq = substr(head, RSTART + 18, RLENGTH - 20) }
  rsq = "-"; if (match(head, /\(resistance_quality \([A-Za-z_]+\)\)/)) { rsq = substr(head, RSTART + 21, RLENGTH - 23) }
  vr = "-"; if (match(head, /\(volume_ratio \([-0-9.e]+\)\)/)) { vr = substr(head, RSTART + 15, RLENGTH - 17) }
  tag = "-"; if (head ~ /Stage4 breakdown/) tag = "S3toS4"; else if (head ~ /Early Stage4/) tag = "EarlyS4"
  printf "T\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.4f\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
    grab(head, "position_id"), grab(head, "symbol"), grab(head, "entry_date"), nz(grab(head, "side")),
    nz(grab(head, "macro_trend")), nz(grab(head, "suggested_entry")), nz(grab(head, "close_at_decision")),
    nz(grab(head, "installed_stop")), nz(grab(head, "stop_floor_kind")), nz(grab(head, "placement_date")),
    nz(grab(head, "ticket_age_weeks_at_fill")), nz(grab(head, "ticket_age_weeks_at_cancel")),
    nz(grab(head, "cancel_reason")), nz(grab(etext, "designed_trigger")), nz(grab(etext, "fill_price")),
    nz(grab(xtext, "exit_date")), nz(xk), nz(xs), nz(xa), nz(grab(xtext, "max_favorable_excursion_pct")),
    nz(grab(xtext, "max_adverse_excursion_pct")), nz(grab(head, "initial_position_value")),
    nz(grab(head, "macro_confidence")), c2, isig, idet, msig, wd, rst, spq, rsq, nz(grab(head, "sector_rating")),
    nz(grab(head, "cascade_score")), vr, tag
  head = ""; xtext = ""; etext = ""
}
function emit_stop(s) {
  if (s !~ /\(date [0-9-]+\)/) return
  gsub(/[ \t]+/, " ", s)
  printf "S\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", grab(s, "position_id"), grab(s, "date"), grab(s, "state_before"),
    grab(s, "state_after"), grab(s, "stop_before"), grab(s, "stop_after"), grab(s, "reason")
}
function emit_week(s,    n, a, i, np, nss, nnc, nsz, nsc, no) {
  if (s !~ /\(total_stocks/) return
  gsub(/[ \t]+/, " ", s)
  np = gsub(/\(outcome Placed\)/, "&", s); nss = gsub(/Skipped No_structural_stop/, "&", s)
  nnc = gsub(/Skipped Short_notional_cap/, "&", s); nsz = gsub(/Skipped Sized_to_zero/, "&", s)
  nsc = gsub(/Skipped Share_class_held/, "&", s); no = gsub(/\(outcome /, "&", s) - np - nss - nnc - nsz - nsc
  printf "C\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n", grab(s, "date"), grab(s, "macro_trend"),
    grab(s, "short_macro_admitted"), grab(s, "short_breakdown_admitted"), grab(s, "short_sector_admitted"),
    grab(s, "short_rs_hard_gate_admitted"), grab(s, "short_grade_admitted"), grab(s, "short_top_n_admitted"),
    grab(s, "entered"), np, nss, nnc, nsz, nsc, no
}
BEGIN { OFS = "\t"; mode = ""; head = ""; xtext = ""; etext = ""; stext = ""; wtext = "" }
/\(cascade_summaries/ { emit_stop(stext); stext = ""; emit_ticket(); mode = "C"; next }
mode == "C" {
  if ($0 ~ /\(\(date [0-9-]+\) \(total_stocks/) { emit_week(wtext); wtext = $0 } else wtext = wtext " " $0
  next
}
/\(entry *$/ { emit_stop(stext); stext = ""; emit_ticket(); mode = "E"; head = " "; next }
mode == "E" && /\(alternatives_considered/ { mode = "A"; next }
/^ *\(exit_/ || /^ *\(external_exit/ { mode = "X"; xtext = xtext " " $0; next }
/^ *\(execution/ { mode = "Q"; etext = $0; next }
/^ *\(stop_decisions/ { mode = "S"; stext = $0; next }
mode == "E" { head = head " " $0; next }
mode == "X" { xtext = xtext " " $0; next }
mode == "Q" { etext = etext " " $0; next }
mode == "S" {
  if ($0 ~ /\(\(date [0-9-]+\) \(position_id/) { emit_stop(stext); stext = $0 } else stext = stext " " $0
  next
}
END { if (mode == "C") emit_week(wtext); else { emit_stop(stext); emit_ticket() } }
