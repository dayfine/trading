open Core
module Bar_reader = Weinstein_strategy.Bar_reader

type verdict =
  | Eligible
  | Sparse_tail of {
      bars_present : int;
      min_bars : int;
      window_trading_days : int;
    }
[@@deriving eq, show]

(* Armed path (window_trading_days > 0): actually read the window and compare.
   Split out of [check] so the disabled-gate short-circuit stays a flat
   if/else with no nested else-branch (nesting linter). *)
let _check_armed bar_reader ~symbol ~as_of ~min_bars ~window_trading_days =
  let view =
    Bar_reader.daily_view_for bar_reader ~symbol ~as_of
      ~lookback:window_trading_days
  in
  let bars_present = view.n_days in
  if bars_present >= min_bars then Eligible
  else Sparse_tail { bars_present; min_bars; window_trading_days }

let check bar_reader ~symbol ~as_of ~min_bars ~window_trading_days =
  if window_trading_days <= 0 then Eligible
  else _check_armed bar_reader ~symbol ~as_of ~min_bars ~window_trading_days

(* Message body for a [Sparse_tail] verdict. Split out of [warning] so the
   match arm is a flat [Some (call)] (nesting linter). *)
let _message ~symbol ~bars_present ~min_bars ~window_trading_days =
  Printf.sprintf
    "%s: dropped from candidate consideration — sparse tail (%d bars present \
     in the last %d trading days, need >= %d; see issue #2083)"
    symbol bars_present window_trading_days min_bars

let warning ~symbol = function
  | Eligible -> None
  | Sparse_tail { bars_present; min_bars; window_trading_days } ->
      Some (_message ~symbol ~bars_present ~min_bars ~window_trading_days)

(* [(ticker, warning option)] — [None] for an eligible ticker. *)
let _verdict_of bar_reader ~as_of ~min_bars ~window_trading_days ticker =
  ( ticker,
    check bar_reader ~symbol:ticker ~as_of ~min_bars ~window_trading_days
    |> warning ~symbol:ticker )

let partition bar_reader ~as_of ~min_bars ~window_trading_days tickers =
  let verdicts =
    List.map tickers
      ~f:(_verdict_of bar_reader ~as_of ~min_bars ~window_trading_days)
  in
  let eligible =
    List.filter_map verdicts ~f:(function
      | ticker, None -> Some ticker
      | _, Some _ -> None)
  in
  (eligible, List.filter_map verdicts ~f:snd)
