# One line per audit record (records.txt) -> entries.tsv. Fields (tab-separated):
#  1 sym  2 decision_date  3 pid  4 macro  5 score  6 grade  7 ticket_age_wk  8 exit_date  9 exit_kind
# 10 filled(0/1)  11 n_alt  12 n_alt_cash  13 floor_kind  14 risk_pct  15 init_value  16 fill_vs_trigger
# 17 suggested_entry  18 installed_stop  19 close_at_decision  20 adj_close_at_decision  21 ma_value
# 22 screener_proxy_stop  23 weeks_advancing  24 placement_date  25 fill_price  26 designed_trigger
# 27 audit_mfe  28 audit_mae  29 exit_stop_price  30 exit_actual_price  31 n_alt_nss  32 volume_ratio
# 33 rs_value  34 ma_slope_pct  35 late_flag  36 exit_macro  37 exit_stage
function f(k,   r) { if (match($0, "\\(" k " [^()]*\\)")) return substr($0, RSTART + length(k) + 2, RLENGTH - length(k) - 3); return "" }
function g(k) { if (match($0, "\\(" k " \\([^()]*\\)\\)")) return substr($0, RSTART + length(k) + 3, RLENGTH - length(k) - 5); return "" }
{
  alts = $0; na = gsub(/reason_skipped /, "&", alts); cash = gsub(/reason_skipped Insufficient_cash/, "&", alts)
  nss = gsub(/reason_skipped No_structural_stop/, "&", alts)
  filled = index($0, "(fill_price") > 0
  kind = ""; if (match($0, /\(exit_trigger \([A-Za-z_]+/)) kind = substr($0, RSTART + 15, RLENGTH - 15)
  if (kind == "Strategy_signal" && match($0, /\(exit_trigger \(Strategy_signal \(label [a-z_]+\)/)) { kind = substr($0, RSTART, RLENGTH); sub(/.*label /, "", kind); sub(/\)$/, "", kind) }
  xs = ""; xa = ""
  if (match($0, /\(exit_trigger \(Stop_loss \(stop_price [^()]*\) \(actual_price [^()]*\)/)) { s = substr($0, RSTART, RLENGTH); xs = s; sub(/.*stop_price /, "", xs); sub(/\).*/, "", xs); xa = s; sub(/.*actual_price /, "", xa); sub(/\)$/, "", xa) }
  late = ""; if (match($0, /\(stage \(Stage2 \(weeks_advancing [0-9]+\) \(late [a-z]+\)/)) { late = substr($0, RSTART, RLENGTH); sub(/.*late /, "", late); sub(/\)$/, "", late) }
  xstage = ""; if (match($0, /\(stage_at_exit \(Stage[0-9]/)) xstage = substr($0, RSTART + 16, 6)
  print f("symbol") "\t" f("entry_date") "\t" f("position_id") "\t" f("macro_trend") "\t" f("cascade_score") "\t" f("cascade_grade") "\t" \
    f("ticket_age_weeks_at_fill") "\t" f("exit_date") "\t" kind "\t" filled "\t" na "\t" cash "\t" f("stop_floor_kind") "\t" f("risk_pct") "\t" \
    f("initial_position_value") "\t" f("fill_vs_trigger_pct") "\t" f("suggested_entry") "\t" f("installed_stop") "\t" f("close_at_decision") "\t" \
    f("adjusted_close_at_decision") "\t" f("ma_value") "\t" f("screener_proxy_stop") "\t" f("weeks_advancing") "\t" f("placement_date") "\t" \
    f("fill_price") "\t" f("designed_trigger") "\t" f("max_favorable_excursion_pct") "\t" f("max_adverse_excursion_pct") "\t" xs "\t" xa "\t" nss "\t" \
    g("volume_ratio") "\t" g("rs_value") "\t" f("ma_slope_pct") "\t" late "\t" f("macro_trend_at_exit") "\t" xstage
}
