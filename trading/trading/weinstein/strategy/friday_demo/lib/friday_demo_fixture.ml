open Core
module WS = Weinstein_strategy

let demo_friday = Date.of_string "2024-06-28"

(* ------------------------------------------------------------------ *)
(* Calendar and bar shape                                               *)
(* ------------------------------------------------------------------ *)

let _history_weeks = 100
let _warmup_weeks = 30
let _days_per_week = 7
let _trading_days = 5
let _intraday_range = 0.01

let _friday_of_week w =
  Date.add_days demo_friday (-_days_per_week * (_history_weeks - 1 - w))

let warmup_fridays =
  List.init _warmup_weeks ~f:(fun k ->
      _friday_of_week (_history_weeks - 1 - _warmup_weeks + k))

(* A leg ramps the weekly close in a straight line to [close] over [weeks]
   weeks, at [volume] times the symbol's base weekly volume. *)
type leg = { weeks : int; close : float; volume : float }

let _leg ?(volume = 1.0) weeks close = { weeks; close; volume }

(* Weekly (close, volume multiple) pairs: [start] held flat until the legs
   begin, so every series is exactly [_history_weeks] long. *)
let _ramp from { weeks; close; volume } =
  let step = (close -. from) /. Float.of_int weeks in
  let week k = (from +. (step *. Float.of_int (k + 1)), volume) in
  (close, List.init weeks ~f:week)

let _weekly ~start legs =
  let ramps = List.concat (snd (List.fold_map legs ~init:start ~f:_ramp)) in
  List.init (_history_weeks - List.length ramps) ~f:(fun _ -> (start, 1.0))
  @ ramps

let _bar ~date ~close ~volume : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. (1.0 +. _intraday_range);
    low_price = close *. (1.0 -. _intraday_range);
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(* Monday..Friday of week [w], closes on a straight line from the prior
   Friday's close to this one's. *)
let _week_bars ~base_volume ~w ~prev (close, volume_mult) =
  let friday = _friday_of_week w in
  let volume =
    Float.to_int (Float.of_int base_volume *. volume_mult) / _trading_days
  in
  List.init _trading_days ~f:(fun d ->
      let frac = Float.of_int (d + 1) /. Float.of_int _trading_days in
      _bar
        ~date:(Date.add_days friday (d + 1 - _trading_days))
        ~close:(prev +. ((close -. prev) *. frac))
        ~volume)

let _daily_bars ~base_volume ~start legs =
  let weekly = _weekly ~start legs in
  List.folding_mapi weekly ~init:start ~f:(fun w prev week ->
      (fst week, _week_bars ~base_volume ~w ~prev week))
  |> List.concat

(* ------------------------------------------------------------------ *)
(* The market                                                           *)
(* ------------------------------------------------------------------ *)

let _index = "DEMO_INDEX"
let _stock_volume = 500_000
let _etf_volume = 1_000_000

(* Prices: every stock bases at [_base]; the last six weeks swing either side
   of its flat 30-week average, so last Friday reads 3 weeks of 6 above it. *)
let _base = 50.0
let _swing_up = 50.8
let _swing_down = 49.6
let _breakout_close = 54.5
let _spike_close = 57.0
let _deep_low = 42.0
let _fall_start = 80.0
let _fall_end = 45.0
let _fall_weeks = 40
let _surge = 3.0

let _swings =
  List.concat
    (List.init 3 ~f:(fun _ -> [ _leg 1 _swing_down; _leg 1 _swing_up ]))

(* The breakout week: one leg up to [_breakout_close] on [volume]x volume. *)
let _breakout ?(volume = _surge) () = [ _leg ~volume 1 _breakout_close ]

(* A one-week spike to [_spike_close] about 16 weeks back, then a pullback to
   [low]: the correction low the initial stop goes under. *)
let _pullback_base ~low =
  [ _leg 1 _spike_close; _leg 1 _base; _leg 2 low; _leg 4 _base; _leg 2 _base ]
  @ _swings

let _tech = "Technology"
let _industrials = "Industrials"
let _utilities = "Utilities"

(* (ticker, sector, starting price, weekly legs). The comment is where each
   one is built to stop; the README carries the same table. *)
let _stocks =
  [
    (* A Stage 1 base: stops at the pre-screen. *)
    ("DEMO_BASE", _industrials, _base, _swings);
    (* A Stage 4 decline: a short setup, but a Bullish market closes shorts. *)
    ("DEMO_FALL", _utilities, _fall_start, [ _leg _fall_weeks _fall_end ]);
    (* A breakout on flat volume: stops at the breakout-volume gate. *)
    ( "DEMO_QUIET",
      _industrials,
      _base,
      _pullback_base ~low:_swing_down @ _breakout ~volume:1.0 () );
    (* The clean one: placed, stop under the pullback low. *)
    ("DEMO_GOOD", _tech, _base, _pullback_base ~low:_swing_down @ _breakout ());
    (* A deep pullback: its stop is over 15 % below the trigger. *)
    ("DEMO_WIDE", _tech, _base, _pullback_base ~low:_deep_low @ _breakout ());
    (* No pullback of 8 % anywhere: only the fallback stop, which the
       investor preset refuses. *)
    ("DEMO_NOSTOP", _tech, _base, _swings @ _breakout ());
    (* Shaped like DEMO_GOOD, in a Weak sector: stops at the pre-screen. *)
    ( "DEMO_WEAK",
      _utilities,
      _base,
      _pullback_base ~low:_swing_down @ _breakout () );
    (* Two copies of DEMO_GOOD in a Neutral sector: a score tie the seeded
       tiebreak splits across the top-N cut. *)
    ( "DEMO_TIE_A",
      _industrials,
      _base,
      _pullback_base ~low:_swing_down @ _breakout () );
    ( "DEMO_TIE_B",
      _industrials,
      _base,
      _pullback_base ~low:_swing_down @ _breakout () );
  ]

(* Index and sector ETFs ramp in a straight line over the whole history:
   Technology outruns the rising index (Strong), Industrials is flat
   (Neutral), Utilities falls (Weak). *)
let _index_start = 1000.0
let _index_end = 1250.0
let _etf_start = 100.0
let _tech_end = 160.0
let _utilities_end = 70.0

let _ramps =
  [
    (_index, _index_start, _index_end);
    ("DEMO_XTECH", _etf_start, _tech_end);
    ("DEMO_XIND", _etf_start, _etf_start);
    ("DEMO_XUTIL", _etf_start, _utilities_end);
  ]

let _sector_etfs =
  [
    ("DEMO_XTECH", _tech);
    ("DEMO_XIND", _industrials);
    ("DEMO_XUTIL", _utilities);
  ]

let _top_n = 4
let _tiebreak_seed = 7
let _cash = 100_000.0

let config =
  let base =
    WS.Weinstein_strategy_config.default_config
      ~universe:(List.map _stocks ~f:(fun (symbol, _, _, _) -> symbol))
      ~index_symbol:_index
  in
  {
    base with
    sector_etfs = _sector_etfs;
    require_structural_stop = true;
    screening_config =
      {
        base.screening_config with
        max_buy_candidates = _top_n;
        tiebreak_seed = _tiebreak_seed;
      };
  }

let _all_bars () =
  List.map _stocks ~f:(fun (symbol, _, start, legs) ->
      (symbol, _daily_bars ~base_volume:_stock_volume ~start legs))
  @ List.map _ramps ~f:(fun (symbol, start, finish) ->
      ( symbol,
        _daily_bars ~base_volume:_etf_volume ~start
          [ _leg (_history_weeks - 1) finish ] ))

let inputs () : Friday_pipeline.inputs =
  let ticker_sectors = Hashtbl.create (module String) in
  List.iter _stocks ~f:(fun (symbol, sector, _, _) ->
      Hashtbl.set ticker_sectors ~key:symbol ~data:sector);
  {
    config;
    bar_reader = WS.Bar_reader.of_in_memory_bars (_all_bars ());
    ticker_sectors;
    portfolio = { cash = _cash; positions = String.Map.empty };
  }

let trace () =
  let inputs = inputs () in
  let state = Friday_pipeline.warm_up inputs ~fridays:warmup_fridays in
  Friday_pipeline.run inputs ~state demo_friday
