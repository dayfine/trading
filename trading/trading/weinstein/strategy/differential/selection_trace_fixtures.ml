(** Fixture builders for [Selection_trace]: bars, price series, the stock
    universe and sector map. Internal; see [selection_trace.mli]. *)

open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Fixture parameters. Every literal is bound to a name so the fixture  *)
(* is readable as a specification rather than a pile of constants.      *)
(* ------------------------------------------------------------------ *)

let _as_of = Date.of_string "2024-01-05"

(* A Friday. The replay section below feeds one bar per element of a series
   straight into [on_market_close], and the strategy screens only on Fridays, so
   a Friday-aligned weekly series makes every replay step a screening day. *)
let _series_origin = Date.of_string "2020-01-03"
let _days_per_week = 7
let _base_volume = 1_000
let _spike_volume = 3_000

(* A weaker-but-still-present volume expansion. Yields a lower volume score than
   [_spike_volume], which is what gives the fixture a SECOND admitted score
   tier — without one, every cap in the sweep would cut inside a single tie
   group and a cross-tier ordering change would go unseen. *)
let _moderate_spike_volume = 1_800
let _intrabar_high_mult = 1.02
let _intrabar_low_mult = 0.98
let _index_symbol = "GSPCX"
let _portfolio_cash = 250_000.0
let _fill_volume = 1_000_000
let _score_probe_offsets = [ -1; 0; 1 ]

(* ------------------------------------------------------------------ *)
(* Bar construction                                                     *)
(* ------------------------------------------------------------------ *)

let _bar ~volume ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. _intrabar_high_mult;
    low_price = close *. _intrabar_low_mult;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(** Weekly bars from [(close, volume)] pairs, one week apart from
    [_series_origin]. *)
let _weekly_bars closes_and_volumes =
  List.mapi closes_and_volumes ~f:(fun i (close, volume) ->
      let date = Date.add_days _series_origin (i * _days_per_week) in
      _bar ~volume ~date ~close)

(** [n] evenly spaced closes from [from_] to [to_] inclusive. *)
let _ramp ~n ~from_ ~to_ =
  let step = (to_ -. from_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> from_ +. (Float.of_int i *. step))

(** Attach [_base_volume] to every close except [spike_idx], which gets
    [_spike_volume] — the volume expansion Weinstein requires at a breakout. *)
let _volumes_with_spike ?(spike = _spike_volume) ~spike_idx closes =
  List.mapi closes ~f:(fun i close ->
      (close, if i = spike_idx then spike else _base_volume))

(* ------------------------------------------------------------------ *)
(* Universe shapes                                                      *)
(* ------------------------------------------------------------------ *)

(* Must exceed [Weinstein_strategy] config's [lookback_bars = 52], or the
   replay's weekly window is shorter than the strategy's lookback and no symbol
   is ever classifiable — the replay then emits nothing on every step and the
   trace is stable because it is empty, not because the code agrees. *)
let _base_weeks = 60
let _advance_weeks = 8
let _late_advance_weeks = 24
let _base_price = 50.0
let _breakout_price = 90.0
let _late_top_price = 140.0
let _decline_top = 120.0
let _decline_bottom = 40.0
let _decline_weeks = 40

(** A Stage-1 base followed by a Stage-2 advance with a volume spike at the
    breakout bar. [advance_weeks] controls [weeks_advancing], which is what
    separates an early Stage 2 from a late one. *)
let _breakout_series ?spike ~advance_weeks ~top () =
  let base = List.init _base_weeks ~f:(fun _ -> _base_price) in
  let advance = _ramp ~n:advance_weeks ~from_:_base_price ~to_:top in
  _volumes_with_spike ?spike ~spike_idx:_base_weeks (base @ advance)
  |> _weekly_bars

(** A flat base with no advance — Stage 1, must never be admitted (spine item:
    buy only in Stage 2). *)
let _basing_series () =
  let base =
    List.init (_base_weeks + _advance_weeks) ~f:(fun _ -> _base_price)
  in
  List.map base ~f:(fun c -> (c, _base_volume)) |> _weekly_bars

(** A sustained decline below a falling MA — Stage 4, the short-side cohort. *)
let _declining_series () =
  let top = List.init _base_weeks ~f:(fun _ -> _decline_top) in
  let decline =
    _ramp ~n:_decline_weeks ~from_:_decline_top ~to_:_decline_bottom
  in
  _volumes_with_spike ~spike_idx:(_base_weeks + 1) (top @ decline)
  |> _weekly_bars

type shape =
  | Early_breakout
  | Modest_breakout
  | Late_breakout
  | Basing
  | Declining

let _series_of_shape = function
  | Early_breakout ->
      _breakout_series ~advance_weeks:_advance_weeks ~top:_breakout_price ()
  | Modest_breakout ->
      _breakout_series ~spike:_moderate_spike_volume
        ~advance_weeks:_advance_weeks ~top:_breakout_price ()
  | Late_breakout ->
      _breakout_series ~advance_weeks:_late_advance_weeks ~top:_late_top_price
        ()
  | Basing -> _basing_series ()
  | Declining -> _declining_series ()

let _prior_stage_of_shape = function
  | Early_breakout | Modest_breakout | Late_breakout | Basing ->
      Some (Stage1 { weeks_in_base = _base_weeks })
  | Declining -> Some (Stage3 { weeks_topping = _advance_weeks })

let _analysis ~ticker ~shape =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
    ~bars:(_series_of_shape shape) ~benchmark_bars:[]
    ~prior_stage:(_prior_stage_of_shape shape)
    ~as_of_date:_as_of

(* ------------------------------------------------------------------ *)
(* The universe                                                         *)
(* ------------------------------------------------------------------ *)

(* Tie groups are the load-bearing part of this fixture. Members of a group
   share a shape verbatim, so their analyses — and therefore their scores — are
   exactly equal, and only the ticker distinguishes them. Two things become
   observable that generic random input hides:

   - the equal-score tiebreak (a change reorders the group), and
   - the top-N cap when it cuts THROUGH a group (a >= / > flip at the cap, or a
     reorder, changes WHICH member survives).

   Tickers are deliberately listed out of alphabetical order so "the order the
   screener emitted" and "the order they were fed in" cannot be confused. *)
let _tie_group_a = [ "TIEM"; "TIEA"; "TIEZ"; "TIEC"; "TIEQ" ]
let _tie_group_b = [ "MIDX"; "MIDB"; "MIDN" ]
let _late_group = [ "LATEP"; "LATED" ]
let _short_group = [ "FALLR"; "FALLA"; "FALLK" ]

(* Two symbols that exist ONLY to make the sector gate bite, one per arm. Each is
   shape-identical to a group that IS admitted, so the sector rating is the
   single thing separating it from admission — which is what makes a
   sector-gate change observable at all.

   Without them the gate was invisible (found in review of #2507): deleting
   BOTH sector conjuncts from [screener_admission.ml] left the trace
   byte-identical, because [Weak] was carried only by [_short_group] (whose
   members are Stage-4 and never long candidates) and [Strong] only by
   [_tie_group_a] (whose members are Stage-2 and never short candidates). A
   gate that never fires cannot discriminate two builds of itself. *)
let _weak_sector_long = "WEAKB"
let _strong_sector_short = "STRGD"

let _universe_spec =
  List.concat
    [
      List.map _tie_group_a ~f:(fun t -> (t, Early_breakout));
      List.map _tie_group_b ~f:(fun t -> (t, Modest_breakout));
      List.map _late_group ~f:(fun t -> (t, Late_breakout));
      List.map _short_group ~f:(fun t -> (t, Declining));
      [ (_weak_sector_long, Early_breakout); (_strong_sector_short, Declining) ];
      [ ("BASE1", Basing); ("BASE2", Basing) ];
    ]

let _stocks =
  List.map _universe_spec ~f:(fun (ticker, shape) -> _analysis ~ticker ~shape)

let _universe_tickers = List.map _universe_spec ~f:fst

(* Sector ratings are assigned by group, not round-robin, so each arm of the
   sector gate has a symbol it actually rejects: [WEAKB] is a Stage-2 breakout
   in a Weak sector (the long arm), [STRGD] a Stage-4 decliner in a Strong
   sector (the short arm). *)
let _sector ~rating name : Screener.sector_context =
  {
    sector_name = name;
    rating;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

let _sector_of_ticker ticker =
  if List.mem _tie_group_a ticker ~equal:String.equal then
    _sector ~rating:Screener.Strong "Technology"
  else if List.mem _tie_group_b ticker ~equal:String.equal then
    _sector ~rating:Screener.Neutral "Industrials"
  else if List.mem _short_group ticker ~equal:String.equal then
    _sector ~rating:Screener.Weak "Energy"
  else if String.equal ticker _weak_sector_long then
    _sector ~rating:Screener.Weak "Materials"
  else if String.equal ticker _strong_sector_short then
    _sector ~rating:Screener.Strong "Healthcare"
  else _sector ~rating:Screener.Neutral "Utilities"

let _sector_map () =
  let m = Hashtbl.create (module String) in
  List.iter _universe_tickers ~f:(fun t ->
      Hashtbl.set m ~key:t ~data:(_sector_of_ticker t));
  m
