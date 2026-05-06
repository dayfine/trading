(** Fixed-dollar all-eligible trade-grading diagnostic.

    See [all_eligible.mli] for the API contract. *)

open Core
module OT = Backtest_optimal.Optimal_types

(* ------------------------------------------------------------------ *)
(* Defaults                                                             *)
(* ------------------------------------------------------------------ *)

let _default_entry_dollars = 10_000.0
let _default_return_buckets : float list = [ -0.5; -0.2; 0.0; 0.2; 0.5; 1.0 ]
let _default_min_grade : Weinstein_types.grade = C

(* ------------------------------------------------------------------ *)
(* Types                                                                *)
(* ------------------------------------------------------------------ *)

type config = {
  entry_dollars : float;
  return_buckets : float list;
  min_grade : Weinstein_types.grade; [@sexp.default Weinstein_types.C]
}
[@@deriving sexp]

let default_config : config =
  {
    entry_dollars = _default_entry_dollars;
    return_buckets = _default_return_buckets;
    min_grade = _default_min_grade;
  }

type trade_record = {
  signal_date : Date.t;
  symbol : string;
  side : Trading_base.Types.position_side;
  entry_price : float;
  exit_date : Date.t;
  exit_reason : OT.exit_trigger;
  return_pct : float;
  hold_days : int;
  entry_dollars : float;
  shares : float;
  pnl_dollars : float;
  cascade_score : int;
  passes_macro : bool;
}
[@@deriving sexp]

type aggregate = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  mean_return_pct : float;
  median_return_pct : float;
  total_pnl_dollars : float;
  return_buckets : (float * float * int) list;
}
[@@deriving sexp]

type result = { trades : trade_record list; aggregate : aggregate }
[@@deriving sexp]

(* ------------------------------------------------------------------ *)
(* Per-trade projection                                                 *)
(* ------------------------------------------------------------------ *)

let build_trade_record ~(config : config) (sc : OT.scored_candidate) :
    trade_record =
  let entry = sc.entry in
  let shares = config.entry_dollars /. entry.entry_price in
  let pnl_per_share =
    match entry.side with
    | Trading_base.Types.Long -> sc.exit_price -. entry.entry_price
    | Short -> entry.entry_price -. sc.exit_price
  in
  let pnl_dollars = pnl_per_share *. shares in
  let hold_days = Date.diff sc.exit_week entry.entry_week in
  {
    signal_date = entry.entry_week;
    symbol = entry.symbol;
    side = entry.side;
    entry_price = entry.entry_price;
    exit_date = sc.exit_week;
    exit_reason = sc.exit_trigger;
    return_pct = sc.raw_return_pct;
    hold_days;
    entry_dollars = config.entry_dollars;
    shares;
    pnl_dollars;
    cascade_score = entry.cascade_score;
    passes_macro = entry.passes_macro;
  }

(* ------------------------------------------------------------------ *)
(* Aggregate helpers                                                    *)
(* ------------------------------------------------------------------ *)

(** Median of a non-empty float list, with the standard "average of the two
    middles for even N" rule. Returns [0.0] for the empty list — caller is
    responsible for the empty-trades short-circuit. *)
let _median (xs : float list) : float =
  match xs with
  | [] -> 0.0
  | _ ->
      let sorted = List.sort xs ~compare:Float.compare |> Array.of_list in
      let n = Array.length sorted in
      if n mod 2 = 1 then sorted.(n / 2)
      else
        let lo = sorted.((n / 2) - 1) in
        let hi = sorted.(n / 2) in
        (lo +. hi) /. 2.0

(** Build the [(low, high)] bucket boundary pairs from [config.return_buckets].
    Prepends [neg_infinity] and appends [infinity] so the first / last buckets
    are unbounded. *)
let _bucket_bounds (boundaries : float list) : (float * float) list =
  let starts = Float.neg_infinity :: boundaries in
  let ends = boundaries @ [ Float.infinity ] in
  List.zip_exn starts ends

(** Count returns falling into each bucket. Bucket interval is half-open
    [\[low, high)]. The last bucket's [high] is [+infinity], so any positive
    return falls cleanly into [\[bn, +inf)]. *)
let _bucketize ~(boundaries : float list) (returns : float list) :
    (float * float * int) list =
  let bounds = _bucket_bounds boundaries in
  List.map bounds ~f:(fun (low, high) ->
      let count =
        List.count returns ~f:(fun r ->
            Float.( >= ) r low && Float.( < ) r high)
      in
      (low, high, count))

let compute_aggregate ~(config : config) (trades : trade_record list) :
    aggregate =
  let trade_count = List.length trades in
  let returns = List.map trades ~f:(fun t -> t.return_pct) in
  let winners = List.count returns ~f:(fun r -> Float.( > ) r 0.0) in
  let losers = List.count returns ~f:(fun r -> Float.( < ) r 0.0) in
  let total_pnl_dollars =
    List.fold trades ~init:0.0 ~f:(fun acc t -> acc +. t.pnl_dollars)
  in
  let win_rate_pct =
    if trade_count = 0 then 0.0
    else Float.of_int winners /. Float.of_int trade_count
  in
  let mean_return_pct =
    if trade_count = 0 then 0.0
    else List.fold returns ~init:0.0 ~f:( +. ) /. Float.of_int trade_count
  in
  let median_return_pct = _median returns in
  let return_buckets = _bucketize ~boundaries:config.return_buckets returns in
  {
    trade_count;
    winners;
    losers;
    win_rate_pct;
    mean_return_pct;
    median_return_pct;
    total_pnl_dollars;
    return_buckets;
  }

(* ------------------------------------------------------------------ *)
(* First-admission dedup                                                *)
(* ------------------------------------------------------------------ *)

(** Total order on scored candidates: [(entry_week, symbol, side)] ascending,
    side ordered Long < Short. The walk relies on chronological order; the
    secondary keys are deterministic tiebreakers for same-day cascade emissions
    so the dedup is reproducible across runs. *)
let _compare_scored_for_dedup (a : OT.scored_candidate)
    (b : OT.scored_candidate) : int =
  let by_date = Date.compare a.entry.entry_week b.entry.entry_week in
  if by_date <> 0 then by_date
  else
    let by_symbol = String.compare a.entry.symbol b.entry.symbol in
    if by_symbol <> 0 then by_symbol
    else
      (* Long < Short — purely a tiebreaker. *)
      match (a.entry.side, b.entry.side) with
      | Long, Long | Short, Short -> 0
      | Long, Short -> -1
      | Short, Long -> 1

(** Render a [(symbol, side)] pair as a string key for the watermark table. The
    pipe character is reserved (never appears in tickers) so the encoding is
    unambiguous. *)
let _key_of (sc : OT.scored_candidate) : string =
  let side_str =
    match sc.entry.side with Trading_base.Types.Long -> "L" | Short -> "S"
  in
  sc.entry.symbol ^ "|" ^ side_str

(** True iff [c] should be dropped given [watermark] (the [exit_week] of the
    most recently kept candidate for the same [(symbol, side)]). The "active
    window" semantics are inclusive of [exit_week] — a re-fire on the exact
    Friday the prior trade exits is treated as the same window, not a fresh
    admission. *)
let _is_within_active_window ~watermark ~(c : OT.scored_candidate) : bool =
  Date.( <= ) c.entry.entry_week watermark

let dedup_first_admission (scored : OT.scored_candidate list) :
    OT.scored_candidate list =
  let sorted = List.sort scored ~compare:_compare_scored_for_dedup in
  let watermarks = Hashtbl.create (module String) in
  List.filter sorted ~f:(fun (c : OT.scored_candidate) ->
      let key = _key_of c in
      match Hashtbl.find watermarks key with
      | Some watermark when _is_within_active_window ~watermark ~c -> false
      | _ ->
          Hashtbl.set watermarks ~key ~data:c.exit_week;
          true)

(* ------------------------------------------------------------------ *)
(* Min-grade quality gate                                               *)
(* ------------------------------------------------------------------ *)

(** Whether [actual] meets-or-beats [floor] in the standard cascade quality
    ordering [A_plus > A > B > C > D > F]. Mirrors the gate
    [Screener._passes_score_floor] uses with [min_score_override = None]. *)
let _grade_passes ~floor (actual : Weinstein_types.grade) : bool =
  Weinstein_types.compare_grade actual floor <= 0

let filter_by_min_grade ~(min_grade : Weinstein_types.grade)
    (scored : OT.scored_candidate list) : OT.scored_candidate list =
  List.filter scored ~f:(fun (c : OT.scored_candidate) ->
      _grade_passes ~floor:min_grade c.entry.cascade_grade)

(* ------------------------------------------------------------------ *)
(* Public entry point                                                   *)
(* ------------------------------------------------------------------ *)

let grade ~(config : config) ~(scored : OT.scored_candidate list) : result =
  let trades = List.map scored ~f:(build_trade_record ~config) in
  let aggregate = compute_aggregate ~config trades in
  { trades; aggregate }
