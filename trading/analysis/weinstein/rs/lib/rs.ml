open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type config = {
  rs_ma_period : int;
  trend_lookback : int;
  flat_threshold : float;
}

let default_config =
  { rs_ma_period = 52; trend_lookback = 4; flat_threshold = 0.98 }

(* ------------------------------------------------------------------ *)
(* Result types                                                         *)
(* ------------------------------------------------------------------ *)

type raw_rs = Relative_strength.raw_rs
(** Re-export the raw RS type from the canonical indicator. *)

type result = {
  current_rs : float;
  current_normalized : float;
  trend : rs_trend;
  history : raw_rs list;
}

(* ------------------------------------------------------------------ *)
(* Trend classification                                                 *)
(* ------------------------------------------------------------------ *)

(** Classify the RS trend from the normalized history.

    We compare the current [rs_normalized] value against the value
    [trend_lookback] bars ago:
    - Whether the stock is above or below the zero line (1.0) determines the
      zone (positive vs negative).
    - A zone change between then and now is a crossover.
    - Within the positive zone, the stock is "flat" if its RS has not declined
      by more than [flat_threshold] (e.g., 0.98 means a < 2% drop is still
      considered flat). *)
let _classify_trend ~trend_lookback ~flat_threshold (history : raw_rs list) :
    rs_trend =
  let n = List.length history in
  if n < 2 then Positive_flat
  else
    let cur = (List.last_exn history).rs_normalized in
    let prev =
      (List.nth_exn history (max 0 (n - 1 - trend_lookback))).rs_normalized
    in
    match (Float.(cur > 1.0), Float.(prev > 1.0)) with
    | true, false -> Bullish_crossover
    | false, true -> Bearish_crossover
    | true, true ->
        if Float.(cur > prev) then Positive_rising
        else if Float.(cur >= prev *. flat_threshold) then Positive_flat
        else Positive_flat
    | false, false ->
        if Float.(cur > prev) then Negative_improving else Negative_declining

(* ------------------------------------------------------------------ *)
(* Shared core: from an aligned (date, stock_close, bench_close) series *)
(* in chronological order, produce the [raw_rs list] history.           *)
(*                                                                      *)
(* The arithmetic here mirrors                                          *)
(* [Relative_strength._build_history] / [Relative_strength.analyze]     *)
(* exactly, so both the bar-list wrapper (which delegates to            *)
(* [Relative_strength.analyze]) and the callback path produce           *)
(* bit-identical [raw_rs] values.                                       *)
(* ------------------------------------------------------------------ *)

(** Compute the raw RS ratio [stock_close / bench_close] (with the same
    [bench_close = 0.0 -> 1.0] guard [Relative_strength] uses). *)
let _raw_rs_value ~stock_close ~bench_close : float =
  if Float.(bench_close = 0.0) then 1.0 else stock_close /. bench_close

(** Compute the normalized RS [raw_rs / ma] (with the same [ma = 0.0 -> 1.0]
    guard [Relative_strength._build_history] uses). *)
let _normalized_rs ~rs_value ~ma : float =
  if Float.(ma = 0.0) then 1.0 else rs_value /. ma

(** Build the raw_rs history from a chronologically-ordered aligned series. *)
let _history_of_aligned ~rs_ma_period (aligned : (Date.t * float * float) list)
    : raw_rs list option =
  let n = List.length aligned in
  if n < rs_ma_period then None
  else
    (* Step 1: split aligned series into parallel arrays of dates and raw RS
       values. Pre-binding the close pair to named locals before the divide
       matches [Relative_strength.analyze]'s expression form. *)
    let dates = List.map aligned ~f:(fun (d, _, _) -> d) in
    let raw_values =
      List.map aligned ~f:(fun (_, sc, bc) ->
          _raw_rs_value ~stock_close:sc ~bench_close:bc)
    in
    (* Step 2: the Mansfield zero line — SMA of the raw RS series, computed
       through the same [Sma.calculate_sma] kernel [Relative_strength] uses. *)
    let indicator_values =
      List.map2_exn dates raw_values ~f:(fun date value ->
          Indicator_types.{ date; value })
    in
    let ma_indicator_values = Sma.calculate_sma indicator_values rs_ma_period in
    let ma_values =
      List.map ma_indicator_values ~f:(fun iv -> iv.Indicator_types.value)
    in
    (* Step 3: realign the MA output back onto the date / raw-value arrays.
       [ma_values] is shorter than [raw_values] by [rs_ma_period - 1]. *)
    let offset = n - List.length ma_values in
    let history =
      List.mapi ma_values ~f:(fun i ma ->
          let date = List.nth_exn dates (offset + i) in
          let rs_value = List.nth_exn raw_values (offset + i) in
          let rs_normalized = _normalized_rs ~rs_value ~ma in
          Relative_strength.{ date; rs_value; rs_normalized })
    in
    Some history

(** Build the trend-classification result from a non-empty raw_rs history. *)
let _result_of_history ~trend_lookback ~flat_threshold (history : raw_rs list) :
    result =
  let current = List.last_exn history in
  let trend = _classify_trend ~trend_lookback ~flat_threshold history in
  {
    current_rs = current.rs_value;
    current_normalized = current.rs_normalized;
    trend;
    history;
  }

(* ------------------------------------------------------------------ *)
(* Callback-shaped entry point                                          *)
(*                                                                      *)
(* Reads the stock + benchmark close + date trio at each [week_offset]  *)
(* via the supplied callbacks, where [week_offset:0] = current week,    *)
(* [week_offset:1] = previous week, etc. The walk stops at the first    *)
(* offset where any callback returns [None]; the depth is the size of   *)
(* the aligned series the caller has already produced.                  *)
(* ------------------------------------------------------------------ *)

(** Walk back from [week_offset:0] until any of the three callbacks returns
    [None]. Returns the aligned triples in chronological order (oldest first).
    The caller is responsible for ensuring the three callbacks are consistent —
    i.e., the panel reader has already date-aligned the two series so that each
    offset [k] refers to the same week across all three. *)
let _collect_aligned_from_callbacks ~get_stock_close ~get_benchmark_close
    ~get_date : (Date.t * float * float) list =
  let rec walk off acc =
    match
      ( get_date ~week_offset:off,
        get_stock_close ~week_offset:off,
        get_benchmark_close ~week_offset:off )
    with
    | Some date, Some sc, Some bc -> walk (off + 1) ((date, sc, bc) :: acc)
    | _ -> acc
  in
  (* [walk] accumulates newest-first (off=0 first). The aligned list is
     consumed in chronological order, so we keep the natural [(_ :: acc)]
     prepend, which leaves the result in oldest-first order — matching
     [Relative_strength._align_bars]. *)
  walk 0 []

let analyze_with_callbacks ~config ~get_stock_close ~get_benchmark_close
    ~get_date : result option =
  let { rs_ma_period; trend_lookback; flat_threshold } = config in
  let aligned =
    _collect_aligned_from_callbacks ~get_stock_close ~get_benchmark_close
      ~get_date
  in
  match _history_of_aligned ~rs_ma_period aligned with
  | None -> None
  | Some history ->
      Some (_result_of_history ~trend_lookback ~flat_threshold history)

(* ------------------------------------------------------------------ *)
(* Callback bundle — used by panel-backed callers                       *)
(*                                                                      *)
(* PR-D introduces this record so that callers like                     *)
(* [Stock_analysis.analyze_with_callbacks] can thread Rs's callbacks    *)
(* through their own callback bundles uniformly. The bar-list           *)
(* [callbacks_from_bars] constructor centralises the wrapper plumbing   *)
(* (date-align two bar lists once, build three index closures) into one *)
(* place.                                                               *)
(* ------------------------------------------------------------------ *)

type callbacks = {
  get_stock_close : week_offset:int -> float option;
  get_benchmark_close : week_offset:int -> float option;
  get_date : week_offset:int -> Date.t option;
}

(* ------------------------------------------------------------------ *)
(* Bar-list wrapper — preserves the existing API                        *)
(*                                                                      *)
(* Aligns the two bar lists once (using                                 *)
(* [Relative_strength]'s alignment), then builds three callbacks over   *)
(* the aligned arrays. Behaviour is bit-identical to the bar-list path  *)
(* because both paths feed the same [(date, stock_close, bench_close)]  *)
(* triples into [_history_of_aligned].                                  *)
(* ------------------------------------------------------------------ *)

(** Date.t Map of benchmark adjusted_close values, keyed on bar date. *)
let _bench_map_of_bars (benchmark_bars : Types.Daily_price.t list) =
  List.fold benchmark_bars ~init:Date.Map.empty ~f:(fun m b ->
      Map.set m ~key:b.Types.Daily_price.date
        ~data:b.Types.Daily_price.adjusted_close)

(** For a single stock bar, look up the matching benchmark close in [bench_map]
    and emit a [(date, stock_close, bench_close)] triple if found. *)
let _align_one_bar bench_map (bar : Types.Daily_price.t) :
    (Date.t * float * float) option =
  Map.find bench_map bar.Types.Daily_price.date
  |> Option.map ~f:(fun bench_close ->
      ( bar.Types.Daily_price.date,
        bar.Types.Daily_price.adjusted_close,
        bench_close ))

(** Align stock and benchmark bars on date, oldest first. Mirrors
    [Relative_strength._align_bars] expression form so the produced triples are
    bit-identical. *)
let _align_bars_for_wrapper ~stock_bars ~benchmark_bars :
    (Date.t * float * float) list =
  let bench_map = _bench_map_of_bars benchmark_bars in
  List.filter_map stock_bars ~f:(_align_one_bar bench_map)

(** Build a triple of callbacks indexed against [aligned] in chronological
    order: [week_offset:0] returns the newest entry; [week_offset:k] returns [k]
    weeks back; offsets past the array's depth return [None]. *)
let _make_callbacks_from_aligned (aligned : (Date.t * float * float) array) :
    callbacks =
  let n = Array.length aligned in
  let get ~week_offset =
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else Some aligned.(idx)
  in
  {
    get_stock_close =
      (fun ~week_offset ->
        Option.map (get ~week_offset) ~f:(fun (_, sc, _) -> sc));
    get_benchmark_close =
      (fun ~week_offset ->
        Option.map (get ~week_offset) ~f:(fun (_, _, bc) -> bc));
    get_date =
      (fun ~week_offset ->
        Option.map (get ~week_offset) ~f:(fun (d, _, _) -> d));
  }

let callbacks_from_bars ~stock_bars ~benchmark_bars : callbacks =
  let aligned = _align_bars_for_wrapper ~stock_bars ~benchmark_bars in
  let aligned_arr = Array.of_list aligned in
  _make_callbacks_from_aligned aligned_arr

let analyze ~config ~stock_bars ~benchmark_bars : result option =
  let { get_stock_close; get_benchmark_close; get_date } =
    callbacks_from_bars ~stock_bars ~benchmark_bars
  in
  analyze_with_callbacks ~config ~get_stock_close ~get_benchmark_close ~get_date
