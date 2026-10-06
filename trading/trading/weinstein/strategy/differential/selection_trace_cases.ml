(** Case definitions for [Selection_trace]: the screener input matrix. Internal;
    see [selection_trace.mli]. *)

open Core
open Weinstein_types
open Selection_trace_fixtures

(* ------------------------------------------------------------------ *)
(* Cases                                                                *)
(* ------------------------------------------------------------------ *)

type case = {
  label : string;
  config : Screener.config;
  macro : market_trend;
  held : string list;
  stop_outs : (string * Date.t) list;
  non_members : string list;
      (** Tickers the point-in-time membership closure reports as absent from
          the index at [_as_of]. Empty means [?membership_at] is not supplied at
          all, which is the production default — so the gate is armed only by
          the cases that mean to arm it. *)
  use_plain_screen : bool;
      (** [true] drives {!Screener.screen} directly rather than
          {!Screener.screen_with_cooldown}, so the thin wrapper is covered as
          its own entry point rather than assumed equivalent. *)
}

let _case ?(held = []) ?(stop_outs = []) ?(non_members = [])
    ?(use_plain_screen = false) ~label ~config ~macro () =
  { label; config; macro; held; stop_outs; non_members; use_plain_screen }

let _base_config = Screener.default_config
let _all_trends = [ Bullish; Neutral; Bearish ]

(** Macro gate x plain-vs-cooldown entry point. The macro gate is an
    unconditional spine item, so every trend is walked. *)
let _macro_cases () =
  List.concat_map _all_trends ~f:(fun macro ->
      let name = Sexp.to_string (sexp_of_market_trend macro) in
      [
        _case
          ~label:(sprintf "macro/%s/screen" name)
          ~config:_base_config ~macro ~use_plain_screen:true ();
        _case
          ~label:(sprintf "macro/%s/cooldown" name)
          ~config:_base_config ~macro ();
      ])

(** Ranking modes: a tiebreak change is invisible unless the tie group is ranked
    under each mode the config can express. *)
let _ranking_cases () =
  List.map
    [ Screener.Alphabetical; Screener.Quality; Screener.Quality_earliness ]
    ~f:(fun ranking ->
      let label =
        sprintf "ranking/%s"
          (Sexp.to_string (Screener.sexp_of_candidate_ranking ranking))
      in
      _case ~label
        ~config:{ _base_config with candidate_ranking = ranking }
        ~macro:Bullish ())

(** Cap sweep. [max_buy_candidates] is walked across the whole universe size so
    that at least one cap lands strictly inside a tie group — the case where a
    reorder or an off-by-one at the cap changes which symbol is selected. *)
let _cap_cases () =
  List.init
    (List.length _universe_tickers + 1)
    ~f:(fun cap ->
      _case
        ~label:(sprintf "cap/max_buy=%d" cap)
        ~config:{ _base_config with max_buy_candidates = cap }
        ~macro:Bullish ())

(** Held / cooldown gates. The cooldown boundary is probed at exactly
    [cooldown_weeks] before [_as_of] — a [>=] / [>] flip at that edge admits or
    blocks the symbol. *)
let _cooldown_cases () =
  let weeks = 4 in
  let exact = Date.add_days _as_of (-weeks * _days_per_week) in
  let victim = List.hd_exn _tie_group_a in
  List.concat_map
    [ (-1, "inside"); (0, "exact"); (1, "outside") ]
    ~f:(fun (shift, name) ->
      let d = Date.add_days exact (shift * _days_per_week) in
      [
        _case
          ~label:(sprintf "cooldown/%s" name)
          ~config:{ _base_config with cascade_post_stop_cooldown_weeks = weeks }
          ~macro:Bullish
          ~stop_outs:[ (victim, d) ]
          ();
      ])

(** Point-in-time membership gate. [?membership_at] is a real gate on the
    default path — the backtest supplies it from the universe snapshot — and it
    is the one gate whose {e absence} is indistinguishable from a gate that
    admits everything. Arming it on one admitted long and one admitted short
    makes a change to the gate observable in the candidate lists. *)
let _membership_cases () =
  [
    _case ~label:"membership/drops-long" ~config:_base_config ~macro:Bullish
      ~non_members:[ List.hd_exn _tie_group_a ]
      ();
    _case ~label:"membership/drops-short" ~config:_base_config ~macro:Bearish
      ~non_members:[ List.hd_exn _short_group ]
      ();
  ]

let _held_cases () =
  [
    _case ~label:"held/one" ~config:_base_config ~macro:Bullish
      ~held:[ List.hd_exn _tie_group_a ]
      ();
    _case ~label:"held/all-ties" ~config:_base_config ~macro:Bullish
      ~held:_tie_group_a ();
  ]

(* ------------------------------------------------------------------ *)
(* Boundary cases derived from the fixture's own observed values        *)
(* ------------------------------------------------------------------ *)

let _reference_result () =
  Screener.screen ~config:_base_config ~macro_trend:Neutral
    ~sector_map:(_sector_map ()) ~stocks:_stocks ~held_tickers:[]

let _observed_scores () =
  let r = _reference_result () in
  List.map (r.buy_candidates @ r.short_candidates) ~f:(fun c ->
      c.Screener.score)
  |> List.dedup_and_sort ~compare:Int.compare

let _observed_breakout_prices () =
  List.filter_map _stocks ~f:(fun (a : Stock_analysis.t) -> a.breakout_price)
  |> List.dedup_and_sort ~compare:Float.compare

(** Score-floor and score-ceiling probes at, just below, and just above every
    score the fixture actually produces. [min_score_override] is a [score >= n]
    gate and [max_score_override] a [score < m] gate, so an inclusive/exclusive
    flip in either shows up as a candidate appearing or vanishing at exactly one
    of these offsets. *)
let _score_boundary_cases () =
  List.concat_map (_observed_scores ()) ~f:(fun score ->
      List.concat_map _score_probe_offsets ~f:(fun offset ->
          let n = score + offset in
          [
            _case
              ~label:(sprintf "score/min>=%d" n)
              ~config:{ _base_config with min_score_override = Some n }
              ~macro:Bullish ();
            _case ~label:(sprintf "score/max<%d" n)
              ~config:{ _base_config with max_score_override = Some n }
              ~macro:Bullish ();
          ]))

(** Price-floor probes at exactly each observed breakout price. [min_price] is a
    [p >= floor] gate; setting the floor to a candidate's own breakout price is
    the single input that distinguishes [>=] from [>]. *)
let _price_boundary_cases () =
  List.map (_observed_breakout_prices ()) ~f:(fun price ->
      _case
        ~label:(sprintf "price/min=%.6f" price)
        ~config:{ _base_config with min_price = price }
        ~macro:Bullish ())
