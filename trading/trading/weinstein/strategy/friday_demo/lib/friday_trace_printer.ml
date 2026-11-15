open Core
open Friday_trace_format
module P = Friday_trace
module Audit_recorder = Weinstein_strategy.Audit_recorder

let _closes closes =
  String.concat ~sep:" " (List.map closes ~f:(sprintf "%7.2f"))

let _inputs_output =
  sprintf
    "the last weekly closes (oldest first), and this week's volume over the \
     prior %d weeks' average."
    Volume.default_config.lookback_bars

let _stage1 buf (t : P.t) =
  header buf ~n:1 ~title:"INPUTS"
    ~does:[ "rolls each ticker's daily bars up to weeks ending on Friday." ]
    ~input:
      (sprintf "daily bars through %s: %d stocks, index %s, %d sector ETFs."
         (Date.to_string t.setup.date)
         (List.length t.tickers) t.setup.config.indices.primary
         (List.length t.sectors))
    ~output:_inputs_output;
  row buf "%-12s %-12s %31s %8s" "ticker" "sector" "weekly closes" "vol/avg";
  List.iter t.tickers ~f:(fun (r : P.ticker_row) ->
      row buf "%-12s %-12s %31s %8s" r.ticker
        (Option.value r.sector ~default:"-")
        (_closes r.recent_closes)
        (opt (sprintf "%.2fx") r.volume_ratio))

let _transition (r : P.ticker_row) =
  match r.stage.transition with
  | Some (from, to_) ->
      sprintf "  <- Stage %d to %d" (stage_number from) (stage_number to_)
  | None -> ""

let _stage2_row buf (sc : Stage.config) (r : P.ticker_row) =
  row buf "%-12s %8.2f %9s %5d/%d  %-16s %s%s" r.ticker r.stage.ma_value
    (signed_pct r.stage.ma_slope_pct)
    r.stage.above_ma_count sc.confirm_weeks
    (opt stage_name r.prior_stage)
    (stage_name r.stage.stage) (_transition r)

let _stage2 buf (t : P.t) =
  let sc = t.setup.config.stage_config in
  header buf ~n:2 ~title:"STAGE CLASSIFICATION"
    ~does:(Friday_trace_rules.stage_classification sc)
    ~input:
      "the weekly closes, and last Friday's stage (state the strategy carries)."
    ~output:"this Friday's stage. A change of stage number is a transition.";
  row buf "%-12s %8s %9s %7s  %-16s %s" "ticker" "MA"
    (sprintf "%dw slope" sc.slope_lookback)
    "wks>MA" "last Friday" "this Friday";
  List.iter t.tickers ~f:(_stage2_row buf sc)

let _signal_name = function
  | `Bullish -> "Bullish"
  | `Bearish -> "Bearish"
  | `Neutral -> "Neutral"

let _gate open_ = if open_ then "open" else "closed"

let _macro_gate_line buf (t : P.t) =
  let c = t.setup.config and trend = t.macro.trend in
  row buf "=> new longs %s, new shorts %s."
    (_gate
       (Screener.longs_admitted_by_macro
          ~neutral_blocks_longs:c.neutral_blocks_longs trend))
    (_gate
       (Screener.shorts_admitted_by_macro
          ~neutral_blocks_shorts:c.neutral_blocks_shorts trend))

let _stage3 buf (t : P.t) =
  let m = t.macro and c = t.setup.config in
  header buf ~n:3 ~title:"MACRO GATE"
    ~does:(Friday_trace_rules.macro_gate c)
    ~input:
      (sprintf
         "the index %s; the A-D line and global indices too when supplied \
          (none here)."
         c.indices.primary)
    ~output:"the market trend, and which side may open new positions.";
  row buf "index: %s, MA %.2f %s (%s)"
    (stage_name m.index_stage.stage)
    m.index_stage.ma_value
    (unqualified (Weinstein_types.show_ma_direction m.index_stage.ma_direction))
    (signed_pct m.index_stage.ma_slope_pct);
  List.iter m.indicators ~f:(fun (i : Macro.indicator_reading) ->
      row buf "indicator %-14s %-8s weight %.1f  %s" i.name
        (_signal_name i.signal) i.weight i.detail);
  row buf "confidence %.2f -> trend %s (Bullish above %.2f, Bearish below %.2f)"
    m.confidence
    (unqualified (Weinstein_types.show_market_trend m.trend))
    c.macro_config.bullish_threshold c.macro_config.bearish_threshold;
  _macro_gate_line buf t

let _pre_screen_text (r : P.ticker_row) =
  match r.pre_screen with
  | Analysed -> "goes on to full analysis"
  | Not_stage_2_or_4 -> "stops: neither Stage 2 (buy) nor Stage 4 (short)"
  | Sector_blocked ->
      sprintf "stops: its sector (%s) blocks this side"
        (Option.value r.sector ~default:"-")

let _context_cell f (s : P.sector_row) = opt f s.context

let _stage4 buf (t : P.t) =
  header buf ~n:4 ~title:"SECTORS AND PRE-SCREEN"
    ~does:
      [
        "rates each sector from its ETF's stage and relative strength (RS) \
         against the index. A Stage 2 stock in a Weak sector is not bought, a \
         Stage 4 stock in a Strong sector is not shorted, and only Stage 2 and \
         4 stocks go on.";
      ]
    ~input:"each sector ETF's weekly bars, the index, and each stock's stage."
    ~output:"a rating per sector, and the stocks that go on to full analysis.";
  row buf "%-12s %-12s %-16s %s" "sector" "ETF" "ETF stage" "rating";
  List.iter t.sectors ~f:(fun s ->
      row buf "%-12s %-12s %-16s %s" s.sector_name s.etf
        (_context_cell (fun c -> stage_name c.stage) s)
        (_context_cell
           (fun c -> unqualified (Screener.show_sector_rating c.rating))
           s));
  Buffer.add_char buf '\n';
  List.iter t.tickers ~f:(fun (r : P.ticker_row) ->
      row buf "%-12s %-16s %s" r.ticker (stage_name r.stage.stage)
        (_pre_screen_text r))

(* ------------------------------------------------------------------ *)
(* Stage 5: breakout cascade                                            *)
(* ------------------------------------------------------------------ *)

let _gate_text : Screener.breakout_gate -> string = function
  | Price_floor -> "price floor"
  | Stage_setup -> "stage setup"
  | Breakout_volume -> "breakout volume"
  | Rs_declining -> "RS declining"
  | Failed_breakout -> "failed breakout"
  | Volume_band -> "volume band"

let _phase_text : Screener.cascade_phase -> string = function
  | Dropped_at_macro -> "stopped: the macro gate closes this side"
  | Dropped_at_breakout gate ->
      "stopped at the breakout gate: " ^ _gate_text gate
  | Dropped_at_sector -> "stopped: sector gate"
  | Dropped_at_rs -> "stopped: RS gate"
  | Dropped_at_grade | Dropped_at_top_n | Admitted ->
      "passed the breakout gates: scored below"

let _volume_cell (a : Stock_analysis.t) =
  match a.volume with
  | Some { confirmation = Strong r; _ } -> sprintf "Strong %.2fx" r
  | Some { confirmation = Adequate r; _ } -> sprintf "Adequate %.2fx" r
  | Some { confirmation = Weak r; _ } -> sprintf "Weak %.2fx" r
  | None -> "-"

let _rs_cell (a : Stock_analysis.t) =
  opt
    (fun (r : Rs.result) -> unqualified (Weinstein_types.show_rs_trend r.trend))
    a.rs

let _stage5 buf (t : P.t) =
  header buf ~n:5 ~title:"BREAKOUT CASCADE"
    ~does:(Friday_trace_rules.breakout_cascade t.setup.config)
    ~input:
      "per analysed stock: stage, breakout-week volume, RS against the index."
    ~output:"where each stock stopped, per side.";
  row buf "%-12s %-6s %-16s %-16s %-18s %s" "ticker" "side" "stage" "volume"
    "RS" "result";
  List.iter t.cascade ~f:(fun (d : Audit_recorder.cascade_drop) ->
      row buf "%-12s %-6s %-16s %-16s %-18s %s" d.outcome.ticker
        (side_name d.side)
        (stage_name d.analysis.stage.stage)
        (_volume_cell d.analysis) (_rs_cell d.analysis)
        (_phase_text d.outcome.phase));
  if
    not
      (List.exists t.cascade ~f:(fun d ->
           Trading_base.Types.equal_position_side d.side Short))
  then
    row buf "No stock was checked as a short: %s"
      (if
         Screener.shorts_admitted_by_macro
           ~neutral_blocks_shorts:t.setup.config.neutral_blocks_shorts
           t.macro.trend
       then "none qualified."
       else "the macro gate (stage 3) closed new shorts.")

let render (t : P.t) =
  let buf = Buffer.create 8192 in
  bprintf buf "WEINSTEIN STRATEGY: ONE FRIDAY, STAGE BY STAGE (%s, %s)\n"
    (Date.to_string t.setup.date)
    (Day_of_week.to_string_long (Date.day_of_week t.setup.date));
  bprintf buf "Account: %s cash, portfolio value %s.\n" (money t.setup.cash)
    (money t.setup.portfolio_value);
  bprintf buf
    "Rule values quoted under \"Does:\" are read from the config this run uses:\n";
  bprintf buf "the strategy default, except where marked as a demo setting.\n";
  _stage1 buf t;
  _stage2 buf t;
  _stage3 buf t;
  _stage4 buf t;
  _stage5 buf t;
  Friday_trace_decisions.render buf t;
  Buffer.contents buf
