(* Portfolio risk primitive — snapshot construction and position sizing. Each
   concern is independently testable, and the module's surface is intentionally
   cohesive. *)
open Core
module Force_liquidation = Force_liquidation

type portfolio_snapshot = {
  total_value : float;
  cash : float;
  cash_pct : float;
  long_exposure : float;
  long_exposure_pct : float;
  short_exposure : float;
  short_exposure_pct : float;
  position_count : int;
  sector_counts : (string * int) list;
  sector_exposures : (string * float) list;
}
[@@deriving show, eq]

type sizing_result = {
  shares : int;
  position_value : float;
  position_pct : float;
  risk_amount : float;
}
[@@deriving show, eq]

(* Named defaults for the per-position cap so the [@sexp.default] attributes
   reference bindings rather than bare numeric literals — the magic-number
   linter accepts named constants but flags inline floats. *)
let default_max_position_pct_long = 0.30
let default_max_position_pct_short = 0.20
let default_max_position_pct = 0.20

type config = {
  risk_per_trade_pct : float;
  max_positions : int;
  max_long_exposure_pct : float;
  max_short_exposure_pct : float;
  max_short_notional_fraction : float;
  min_cash_pct : float;
  max_position_pct_long : float; [@sexp.default default_max_position_pct_long]
  max_position_pct_short : float; [@sexp.default default_max_position_pct_short]
  max_position_pct : float; [@sexp.default default_max_position_pct]
  max_sector_concentration : int;
  max_sector_exposure_pct : float option; [@sexp.default None]
  max_unknown_sector_positions : int;
  big_winner_multiplier : float;
  force_liquidation : Force_liquidation.config;
      [@sexp.default Force_liquidation.default_config]
  exempt_closing_trades_from_cash_floor : bool; [@sexp.default true]
}
[@@deriving show, eq, sexp]

let default_config =
  {
    risk_per_trade_pct = 0.01;
    max_positions = 20;
    max_long_exposure_pct = 0.90;
    max_short_exposure_pct = 0.30;
    max_short_notional_fraction = 0.30;
    min_cash_pct = 0.10;
    max_position_pct_long = default_max_position_pct_long;
    max_position_pct_short = default_max_position_pct_short;
    max_position_pct = default_max_position_pct;
    max_sector_concentration = 5;
    max_sector_exposure_pct = None;
    max_unknown_sector_positions = 2;
    big_winner_multiplier = 1.5;
    force_liquidation = Force_liquidation.default_config;
    exempt_closing_trades_from_cash_floor = true;
  }

(* ---- Snapshot helpers ---- *)

let _compute_exposures positions =
  List.fold positions ~init:(0.0, 0.0, 0)
    ~f:(fun (long_exp, short_exp, count) (_, qty, price) ->
      let market_value = qty *. price in
      if Float.( >= ) market_value 0.0 then
        (long_exp +. market_value, short_exp, count + 1)
      else (long_exp, short_exp +. Float.abs market_value, count + 1))

(* Build a (sector_name, count) list from open positions and an optional
   (symbol, sector) lookup. Positions whose symbol is missing from the lookup
   — or whose sector is the empty string — are bucketed under the empty
   string, which [max_unknown_sector_positions] governs. *)
let _compute_sector_counts positions sectors =
  let sector_map =
    List.fold sectors ~init:String.Map.empty ~f:(fun m (sym, sec) ->
        Map.set m ~key:sym ~data:sec)
  in
  List.fold positions ~init:String.Map.empty ~f:(fun acc (sym, _, _) ->
      let sector = Map.find sector_map sym |> Option.value ~default:"" in
      Map.update acc sector ~f:(function None -> 1 | Some n -> n + 1))
  |> Map.to_alist
  |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)

(* Build a (sector_name, dollar_exposure) list parallel to sector_counts.
   Dollar exposure is the absolute value of the position's market value
   (|qty * price|), summed within each sector bucket. Long + short positions
   to the same sector aggregate — the cap measures total sector concentration,
   not directional concentration. Empty-string sector follows the same
   bucketing as _compute_sector_counts; the exposure-percent cap exempts it,
   but it's still reported here for consistency with [sector_counts]. *)
let _compute_sector_exposures positions sectors =
  let sector_map =
    List.fold sectors ~init:String.Map.empty ~f:(fun m (sym, sec) ->
        Map.set m ~key:sym ~data:sec)
  in
  List.fold positions ~init:String.Map.empty ~f:(fun acc (sym, qty, price) ->
      let sector = Map.find sector_map sym |> Option.value ~default:"" in
      let exposure = Float.abs (qty *. price) in
      Map.update acc sector ~f:(function
        | None -> exposure
        | Some v -> v +. exposure))
  |> Map.to_alist
  |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)

let _make_snapshot ~cash ~positions ~sector_counts ~sector_exposures =
  let long_exp, short_exp, position_count = _compute_exposures positions in
  let total_value = cash +. long_exp -. short_exp in
  let safe_pct v =
    if Float.( <= ) total_value 0.0 then 0.0 else v /. total_value
  in
  {
    total_value;
    cash;
    cash_pct = safe_pct cash;
    long_exposure = long_exp;
    long_exposure_pct = safe_pct long_exp;
    short_exposure = short_exp;
    short_exposure_pct = safe_pct short_exp;
    position_count;
    sector_counts;
    sector_exposures;
  }

let snapshot ~cash ~positions ?(sectors = []) () =
  let sector_counts = _compute_sector_counts positions sectors in
  let sector_exposures = _compute_sector_exposures positions sectors in
  _make_snapshot ~cash ~positions ~sector_counts ~sector_exposures

(* Extract (symbol, total_quantity, current_price) triples from a portfolio
   and price lookup. Position quantity is the sum across all lots. *)
let _positions_of_portfolio ~portfolio ~prices =
  let price_of sym =
    List.Assoc.find prices ~equal:String.equal sym |> Option.value ~default:0.0
  in
  let (p : Trading_portfolio.Portfolio.t) = portfolio in
  List.map p.positions ~f:(fun pos ->
      let qty =
        List.fold pos.lots ~init:0.0 ~f:(fun acc lot -> acc +. lot.quantity)
      in
      (pos.symbol, qty, price_of pos.symbol))

let snapshot_of_portfolio ~portfolio ~prices ?(sectors = []) () =
  let positions = _positions_of_portfolio ~portfolio ~prices in
  snapshot ~cash:portfolio.current_cash ~positions ~sectors ()

(* ---- Position sizing ---- *)

(* Reject NaN, infinity, and non-positive values in one check. IEEE-754
   comparisons against NaN always return false, so bare [Float.( <= ) x 0.0]
   guards let NaN propagate through division and crash at [Int.of_float NaN].
   The v7 production sweep (2026-05-25) crashed in fold 22 (2020-12-26 →
   2021-12-25) from this path when a NaN sizing input slipped past the bare
   <= 0 guards in [_max_shares_by_caps] and [compute_position_size]. *)
let _is_finite_positive x = Float.is_finite x && Float.( > ) x 0.0

let _zero_sizing =
  { shares = 0; position_value = 0.0; position_pct = 0.0; risk_amount = 0.0 }

(* G7 fix: cap shares so that position_value never exceeds the side's
   max-exposure budget. Without this, a tight stop (small risk_per_share)
   relative to dollar_risk produces an unbounded share count, allowing single
   positions whose notional dwarfs portfolio_value (observed: ABBV short at 124%
   of $1M starting portfolio, sp500-2019-2023 rerun 2026-04-30). *)
(* Extended to also cap per-position notional at [portfolio_value *.
   config.max_position_pct]. Per-position concentration sat well above the
   side-exposure cap; the [min()] of both caps tightens this. *)
let _max_shares_by_caps ~config ~side ~portfolio_value ~entry_price =
  if
    (not (Float.is_finite portfolio_value))
    || not (_is_finite_positive entry_price)
  then Int.max_value
  else
    let exposure_pct, position_pct =
      match side with
      | `Long -> (config.max_long_exposure_pct, config.max_position_pct_long)
      | `Short -> (config.max_short_exposure_pct, config.max_position_pct_short)
    in
    (* Clamp both caps to non-negative. With shorts, [portfolio_value] can go
       negative when short notional exceeds cash + longs; without the clamp,
       [position_cap] becomes negative and the share-count rounds to a negative
       integer, silently corrupting downstream metrics + Sexp serialization
       (sp500-2019-2023 with-shorts crashed silently post-#744 from this path).
       A negative cap means the strategy has no room to add positions — return
       zero shares instead of a negative count. *)
    let exposure_cap = Float.max 0.0 (portfolio_value *. exposure_pct) in
    let position_cap = Float.max 0.0 (portfolio_value *. position_pct) in
    let dollar_cap = Float.min exposure_cap position_cap in
    Int.of_float (Float.round_down (dollar_cap /. entry_price))

(* Spendable-cash cap (issue #859 Phase 1, item 3 / plan §1.1). The number of
   shares that [sizing_cash] dollars can fund at [entry_price]:
   [floor(sizing_cash / entry_price)]. Under margin accounting, [sizing_cash] is
   [Portfolio.available_cash] (= current_cash net of locked short collateral),
   so a long entry can no longer be funded by short proceeds that are pledged as
   collateral — the Stance-A long-sizing inflation the plan fixes.

   When the caller passes [sizing_cash = portfolio_value] (the default — see
   [compute_position_size]), this cap is >= both the exposure and per-position
   caps (which are fractions <= 1.0 of [portfolio_value]), so the subsequent
   [min] leaves the result bit-identical to the pre-change code. A non-finite or
   non-positive [sizing_cash] yields no constraint. *)
let _max_shares_by_sizing_cash ~sizing_cash ~entry_price =
  if
    (not (_is_finite_positive sizing_cash))
    || not (_is_finite_positive entry_price)
  then Int.max_value
  else Int.of_float (Float.round_down (sizing_cash /. entry_price))

(* Caller [compute_position_size] has already screened [portfolio_value],
   [entry_price], [stop_price] for NaN/inf. This helper handles the
   directional + zero-risk-per-share guards and the actual sizing math.
   Extracted so [compute_position_size] stays one if-level deep — the
   finite-input check would otherwise push nesting past the linter cap. *)
let _compute_position_size_finite ~config ~portfolio_value ~sizing_cash ~side
    ~entry_price ~stop_price ~big_winner =
  let stop_on_correct_side =
    match side with
    | `Long -> Float.( < ) stop_price entry_price
    | `Short -> Float.( > ) stop_price entry_price
  in
  let risk_per_share = Float.abs (entry_price -. stop_price) in
  if (not stop_on_correct_side) || Float.( <= ) risk_per_share 0.0 then
    _zero_sizing
  else
    let base_risk_pct = config.risk_per_trade_pct in
    let effective_risk_pct =
      if big_winner then base_risk_pct *. config.big_winner_multiplier
      else base_risk_pct
    in
    let dollar_risk = portfolio_value *. effective_risk_pct in
    let risk_based_shares =
      Int.of_float (Float.round_down (dollar_risk /. risk_per_share))
    in
    let exposure_capped_shares =
      _max_shares_by_caps ~config ~side ~portfolio_value ~entry_price
    in
    let sizing_cash_capped_shares =
      _max_shares_by_sizing_cash ~sizing_cash ~entry_price
    in
    let shares =
      Int.min risk_based_shares
        (Int.min exposure_capped_shares sizing_cash_capped_shares)
    in
    let position_value = Float.of_int shares *. entry_price in
    let position_pct =
      if Float.( <= ) portfolio_value 0.0 then 0.0
      else position_value /. portfolio_value
    in
    let risk_amount = Float.of_int shares *. risk_per_share in
    { shares; position_value; position_pct; risk_amount }

let compute_position_size ~config ~portfolio_value ?sizing_cash ~side
    ~entry_price ~stop_price ?(big_winner = false) () =
  (* [sizing_cash] defaults to [portfolio_value] — the legacy denominator. With
     the default, the spendable-cash cap is never binding (see
     [_max_shares_by_sizing_cash]), so behaviour is bit-identical to before this
     parameter existed. Margin-aware callers pass [Portfolio.available_cash]
     (cash net of locked short collateral) to fix the Stance-A long-sizing
     inflation (issue #859 Phase 1, item 3). *)
  let sizing_cash = Option.value sizing_cash ~default:portfolio_value in
  (* Defense against NaN/inf inputs — see [_is_finite_positive] above. A NaN
     [portfolio_value] (e.g. mark-to-market summed an inf bar from bad CSV) or
     NaN [entry_price]/[stop_price] would slip past the directional and <= 0
     guards in [_compute_position_size_finite] and crash at [Int.of_float].
     Returning zero shares makes the strategy skip the candidate silently —
     the audit recorder upstream emits a [Sized_zero] outcome trace. *)
  if
    (not (Float.is_finite portfolio_value))
    || (not (Float.is_finite entry_price))
    || not (Float.is_finite stop_price)
  then _zero_sizing
  else
    _compute_position_size_finite ~config ~portfolio_value ~sizing_cash ~side
      ~entry_price ~stop_price ~big_winner
