open Core
module FM = Synthetic.Factor_model
module SC = Shiller.Shiller_client
module KF = Kenneth_french.Kenneth_french_client

let _industries_v1 = [ "Cnsmr"; "Manuf"; "HiTec"; "Hlth"; "Other" ]
let _industry_count_v1 = List.length _industries_v1

(* Default tolerance on the anchor-equality constraint. Closed-form rescale
   should land near 1e-15; this wider default insulates against numerical
   pathologies. *)
let _default_epsilon = 0.005

(* Window length: one calendar year from [date]. *)
let _window_days = 365

type config = {
  size : int;
  per_industry_count : int;
  rng_seed : int;
  shiller_anchor_epsilon : float;
}
[@@deriving sexp]

let default_config ~size ~rng_seed =
  {
    size;
    per_industry_count = size / _industry_count_v1;
    rng_seed;
    shiller_anchor_epsilon = _default_epsilon;
  }

let _validate_size size =
  if size <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "build_from_index: size must be > 0 (got %d)" size)
  else if size mod _industry_count_v1 <> 0 then
    Status.error_invalid_argument
      (Printf.sprintf
         "build_from_index: size (%d) must be divisible by %d (v1 splits \
          equally across French 5-industry buckets)"
         size _industry_count_v1)
  else Ok ()

let _validate_inputs ~config ~shiller_obs ~french_obs =
  let nonempty name lst =
    if List.is_empty lst then
      Status.error_invalid_argument
        (Printf.sprintf "build_from_index: %s observations must be non-empty"
           name)
    else Ok ()
  in
  Status.combine_status_list
    [
      _validate_size config.size;
      nonempty "shiller" shiller_obs;
      nonempty "french" french_obs;
    ]

let _window_end ~date = Date.add_days date _window_days

let _in_window ~start_date ~end_date d =
  Date.( >= ) d start_date && Date.( <= ) d end_date

let _shiller_window ~date obs =
  let end_date = _window_end ~date in
  List.filter obs ~f:(fun (o : SC.monthly_observation) ->
      _in_window ~start_date:date ~end_date o.period)

let _french_window ~date obs =
  let end_date = _window_end ~date in
  List.filter obs ~f:(fun (o : KF.daily_return) ->
      _in_window ~start_date:date ~end_date o.date)

(* Shiller's dividend column is annualized; per-month accrual is div / 12. *)
let _monthly_dividend_amount (o : SC.monthly_observation) =
  match o.dividend with Some d -> d /. 12.0 | None -> 0.0

let _sum_dividends_in_window obs =
  List.fold obs ~init:0.0 ~f:(fun acc o -> acc +. _monthly_dividend_amount o)

let _shiller_too_short () =
  Status.error_invalid_argument
    "build_from_index: shiller window has fewer than 2 monthly observations; \
     cannot compute composite return"

let _shiller_zero_price () =
  Status.error_invalid_argument "build_from_index: shiller starting price <= 0"

let _composite_return ~p_start ~p_end ~div_total =
  ((p_end +. div_total) /. p_start) -. 1.0

let _anchor_return_from_shiller_first ~first ~last ~obs =
  let p_start = first.SC.sp_price in
  let p_end = last.SC.sp_price in
  if Float.(p_start <= 0.0) then _shiller_zero_price ()
  else
    let div_total = _sum_dividends_in_window obs in
    Ok (_composite_return ~p_start ~p_end ~div_total)

let _anchor_return_from_shiller obs =
  match obs with
  | [] | [ _ ] -> _shiller_too_short ()
  | first :: _ ->
      let last = List.last_exn obs in
      _anchor_return_from_shiller_first ~first ~last ~obs

(* French values are in percent (0.46 = 0.46%). Convert to fraction. *)
let _percent_to_fraction p = p /. 100.0

let _industry_return_in_row ~industry (row : KF.daily_return) =
  match List.Assoc.find row.industry_returns ~equal:String.equal industry with
  | Some (Some p) -> _percent_to_fraction p
  | Some None | None -> 0.0

let _industry_series ~industry rows =
  List.map rows ~f:(fun row -> _industry_return_in_row ~industry row)

let _all_industry_series rows =
  List.map _industries_v1 ~f:(fun industry ->
      (industry, _industry_series ~industry rows))

(* Seed offsets — mirror Synth_v3's scheme so role sub-streams stay
   independent across industries. *)
let _beta_seed ~base ~industry_idx = base + 100_000 + (industry_idx * 10_000)
let _idio_seed ~base ~industry_idx = base + 200_000 + (industry_idx * 10_000)

let _return_seed ~base ~industry_idx ~symbol_idx =
  base + 1_000_000 + (industry_idx * 100_000) + symbol_idx

(* Compound a log-return list to one period return: R = exp(sum log_r) - 1.
   Factor_model output is treated as log-returns, matching Synth_v3. *)
let _compound_log_returns log_returns =
  let total = List.fold log_returns ~init:0.0 ~f:( +. ) in
  Float.exp total -. 1.0

let _generate_symbol_period_return ~market_returns ~beta ~idio_params ~seed =
  let log_returns =
    FM.generate_symbol_returns ~market_returns ~beta ~idio_params ~seed
  in
  _compound_log_returns log_returns

let _per_industry_returns ~base_seed ~industry_idx ~per_industry_count
    ~market_returns =
  let beta_seed = _beta_seed ~base:base_seed ~industry_idx in
  let idio_seed = _idio_seed ~base:base_seed ~industry_idx in
  let betas =
    FM.sample_betas FM.default_loading_distribution ~n:per_industry_count
      ~seed:beta_seed
  in
  let idio_params_list =
    FM.sample_idio_params FM.default_idio_distribution ~n:per_industry_count
      ~seed:idio_seed
  in
  List.mapi (List.zip_exn betas idio_params_list)
    ~f:(fun symbol_idx (beta, idio_params) ->
      let seed = _return_seed ~base:base_seed ~industry_idx ~symbol_idx in
      _generate_symbol_period_return ~market_returns ~beta ~idio_params ~seed)

let _zero_pad_4 i = Printf.sprintf "%04d" i

let _synthetic_symbol ~industry ~rank =
  "SYNTH_" ^ industry ^ "_" ^ _zero_pad_4 rank

let _make_entry ~industry ~uniform_weight ~rank : Snapshot.entry =
  {
    symbol = _synthetic_symbol ~industry ~rank;
    weight = uniform_weight;
    sector = industry;
    synthetic = true;
  }

(* Per-symbol period returns are summarized into [aggregate_period_return]
   after the global rescale; the entries themselves only carry identity +
   uniform weight. We iterate over the per-symbol return list purely to
   size the per-industry batch correctly. *)
let _make_entries_for_industry ~industry ~uniform_weight ~returns =
  List.mapi returns ~f:(fun i _raw_return ->
      _make_entry ~industry ~uniform_weight ~rank:(i + 1))

let _sum_returns returns = List.fold returns ~init:0.0 ~f:( +. )

let _initial_aggregate ~total_size ~per_industry_results =
  let total = List.sum (module Float) per_industry_results ~f:_sum_returns in
  total /. Float.of_int total_size

(* If [initial] vanishes and [target] does not, the rescale is undefined; we
   surface [nan] and let the build step convert that to an error. *)
let _aggregate_scale ~target ~initial =
  if Float.(Float.abs initial < 1e-15) then
    if Float.(Float.abs target < 1e-15) then 1.0 else Float.nan
  else target /. initial

let _per_industry_results ~config ~french_window_rows =
  let industry_series = _all_industry_series french_window_rows in
  List.mapi industry_series ~f:(fun industry_idx (_industry, returns) ->
      _per_industry_returns ~base_seed:config.rng_seed ~industry_idx
        ~per_industry_count:config.per_industry_count ~market_returns:returns)

let _entries_for_industries ~uniform_weight ~per_industry_results =
  List.concat_mapi per_industry_results ~f:(fun industry_idx returns ->
      let industry = List.nth_exn _industries_v1 industry_idx in
      _make_entries_for_industry ~industry ~uniform_weight ~returns)

let _calibration_drift_error ~target ~achieved ~epsilon =
  let drift = Float.abs (achieved -. target) in
  let msg =
    Printf.sprintf
      "build_from_index: calibration drift %.6e exceeds epsilon %.6e \
       (target=%.6e achieved=%.6e)"
      drift epsilon target achieved
  in
  Status.{ code = Failed_precondition; message = msg }

let _verify_calibration ~target ~achieved ~epsilon =
  if Float.(Float.abs (achieved -. target) <= epsilon) then Ok ()
  else Error (_calibration_drift_error ~target ~achieved ~epsilon)

let _decomposition_method () : Snapshot.method_ =
  Decomposition_from_index
    { anchor = `Shiller_sp_composite; factor_skeleton = `French_5_industry }

let _make_snapshot ~date ~config ~entries ~aggregate_period_return : Snapshot.t
    =
  {
    date;
    method_ = _decomposition_method ();
    size = config.size;
    entries;
    aggregate_period_return;
  }

let _non_finite_scale_error () =
  Status.error_internal
    "build_from_index: aggregate scale is non-finite (degenerate inputs)"

let _build_snapshot_with_scale ~date ~config ~anchor_target ~scale
    ~initial_aggregate ~per_industry_results =
  let uniform_weight = 1.0 /. Float.of_int config.size in
  let entries = _entries_for_industries ~uniform_weight ~per_industry_results in
  (* Closed-form rescale: aggregate_after = scale * initial_aggregate =
     anchor_target up to float precision. *)
  let achieved = scale *. initial_aggregate in
  let%bind.Result () =
    _verify_calibration ~target:anchor_target ~achieved
      ~epsilon:config.shiller_anchor_epsilon
  in
  Ok (_make_snapshot ~date ~config ~entries ~aggregate_period_return:achieved)

let _build_with_anchor ~date ~french_obs ~config ~anchor_target =
  let french_window = _french_window ~date french_obs in
  let per_industry_results =
    _per_industry_results ~config ~french_window_rows:french_window
  in
  let initial_aggregate =
    _initial_aggregate ~total_size:config.size ~per_industry_results
  in
  let scale =
    _aggregate_scale ~target:anchor_target ~initial:initial_aggregate
  in
  if not (Float.is_finite scale) then _non_finite_scale_error ()
  else
    _build_snapshot_with_scale ~date ~config ~anchor_target ~scale
      ~initial_aggregate ~per_industry_results

let _build_validated ~date ~shiller_obs ~french_obs ~config =
  let shiller_window = _shiller_window ~date shiller_obs in
  let%bind.Result anchor_target = _anchor_return_from_shiller shiller_window in
  _build_with_anchor ~date ~french_obs ~config ~anchor_target

let build ~date ~shiller_obs ~french_obs ~config =
  match _validate_inputs ~config ~shiller_obs ~french_obs with
  | Error _ as e -> e
  | Ok () -> _build_validated ~date ~shiller_obs ~french_obs ~config
