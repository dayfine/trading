(* Extension-episode counterfactual screen (P0, 2026-07-11).

   For every held LONG episode of a backtest run (closed trades + still-open
   positions), find the weeks where the weekly close is extended >= K x the
   30-week WMA (the stage classifier's own MA basis), and replay the episode
   under a counterfactual "extension stop": once extension >= K, exit at the
   first weekly close that drops trail% below the post-trigger running peak
   close. Emits one CSV row per (episode x threshold x trail) so the
   distributions (not means) can be aggregated downstream.

   Estimand note (screen-rigor): the counterfactual changes ONLY the episode's
   exit; it cannot model the strategy's re-entry after a trail exit, nor the
   portfolio-level redeployment of freed cash. Both gaps UNDERSTATE the
   mechanism's benefit; the missing give-back tail of monsters that kept
   running OVERSTATES it. Name both when reporting. *)

open Core

type episode = {
  symbol : string;
  entry_date : Date.t;
  end_date : Date.t; (* exit date for closed trades, run end for open *)
  entry_price : float;
  actual_end_price : float; (* exit price, or terminal weekly close if open *)
  quantity : float;
  is_open : bool;
}

let _ma_period = 30 (* Stage.default_config.ma_period, WMA basis *)
let _split_csv_line line = String.split line ~on:','

let _make_episode ~symbol ~entry_d ~end_d ~entry_p ~end_p ~qty ~is_open =
  {
    symbol;
    entry_date = Date.of_string entry_d;
    end_date = end_d;
    entry_price = Float.of_string entry_p;
    actual_end_price = end_p;
    quantity = Float.of_string qty;
    is_open;
  }

(* trades.csv columns: 0 symbol, 1 side, 2 entry_date, 3 exit_date,
   5 entry_price, 6 exit_price, 7 quantity. LONG rows only. *)
let _closed_episode_of_line line =
  match _split_csv_line line with
  | symbol :: "LONG" :: entry_d :: exit_d :: _days :: entry_p :: exit_p :: qty
    :: _ ->
      Some
        (_make_episode ~symbol ~entry_d ~end_d:(Date.of_string exit_d) ~entry_p
           ~end_p:(Float.of_string exit_p) ~qty ~is_open:false)
  | _ -> None

(* open_positions.csv columns: symbol, side, entry_date, entry_price,
   quantity. actual_end_price is patched from bars later. *)
let _open_episode_of_line line ~run_end =
  match _split_csv_line line with
  | [ symbol; "LONG"; entry_d; entry_p; qty ] ->
      Some
        (_make_episode ~symbol ~entry_d ~end_d:run_end ~entry_p ~end_p:Float.nan
           ~qty ~is_open:true)
  | _ -> None

let _parse_trades_csv path =
  In_channel.read_lines path |> List.tl_exn
  |> List.filter_map ~f:_closed_episode_of_line

let _parse_open_csv path ~run_end =
  In_channel.read_lines path |> List.tl_exn
  |> List.filter_map ~f:(_open_episode_of_line ~run_end)

(* Weekly (date, adjusted_close, wma30) arrays for one symbol; wma is NaN
   until the window fills. Same MA basis as Stage._compute_ma with the
   default Wma / 30 config. *)
let _indicator_point (b : Types.Daily_price.t) =
  Indicator_types.{ date = b.date; value = b.adjusted_close }

(* WMA-30 value per weekly date; NaN until the window fills. *)
let _wma_by_date weekly =
  let ma_by_date = Date.Table.create () in
  Sma.calculate_weighted_ma (List.map weekly ~f:_indicator_point) _ma_period
  |> List.iter ~f:(fun iv ->
      Hashtbl.set ma_by_date ~key:iv.Indicator_types.date
        ~data:iv.Indicator_types.value);
  ma_by_date

let _load_weekly_series ~data_dir ~symbol ~end_date =
  let open Result.Let_syntax in
  let%bind storage =
    Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol
  in
  let%map daily = Csv.Csv_storage.get storage ~end_date () in
  let weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily
  in
  let dates = Array.of_list_map weekly ~f:(fun b -> b.Types.Daily_price.date) in
  let closes =
    Array.of_list_map weekly ~f:(fun b -> b.Types.Daily_price.adjusted_close)
  in
  let ma_by_date = _wma_by_date weekly in
  let mas =
    Array.map dates ~f:(fun d ->
        Option.value (Hashtbl.find ma_by_date d) ~default:Float.nan)
  in
  (dates, closes, mas)

(* Indices of the weekly bars inside [entry_date, end_date]. *)
let _episode_range dates ~entry_date ~end_date =
  let n = Array.length dates in
  let in_range i =
    Date.( >= ) dates.(i) entry_date && Date.( <= ) dates.(i) end_date
  in
  let idxs = List.filter (List.init n ~f:Fn.id) ~f:in_range in
  match (List.hd idxs, List.last idxs) with
  | Some lo, Some hi -> Some (lo, hi)
  | _ -> None

(* First episode week where close/ma >= threshold (ma must be filled). *)
let _first_trigger closes mas ~lo ~hi ~threshold =
  List.range lo (hi + 1)
  |> List.find ~f:(fun i ->
      Float.is_finite mas.(i)
      && Float.( > ) mas.(i) 0.0
      && Float.( >= ) (closes.(i) /. mas.(i)) threshold)

let _max_ratio closes mas ~lo ~hi =
  List.range lo (hi + 1)
  |> List.filter_map ~f:(fun i ->
      if Float.is_finite mas.(i) && Float.( > ) mas.(i) 0.0 then
        Some (closes.(i) /. mas.(i))
      else None)
  |> List.max_elt ~compare:Float.compare

(* Walk forward from the trigger week; fire at the first weekly close that is
   trail below the running peak close (peak seeded at the trigger week).
   Returns (fire_index option). Fire-check precedes the peak update so a new
   high can never fire. *)
let _trail_fire closes ~trigger ~hi ~trail =
  let peak = ref closes.(trigger) in
  List.range (trigger + 1) (hi + 1)
  |> List.find ~f:(fun i ->
      let fired = Float.( <= ) closes.(i) (!peak *. (1.0 -. trail)) in
      if not fired then peak := Float.max !peak closes.(i);
      fired)

let _row ~run_label ~ep ~threshold ~trail ~max_ratio ~cf ~(dates : Date.t array)
    =
  let cf_fired, cf_date, cf_price =
    match cf with
    | Some (i, px) -> (true, Date.to_string dates.(i), px)
    | None -> (false, "", ep.actual_end_price)
  in
  let delta = cf_price -. ep.actual_end_price in
  sprintf "%s,%s,%s,%s,%b,%.0f,%.4f,%.4f,%.2f,%.2f,%.4f,%b,%s,%.4f,%.4f,%.2f"
    run_label ep.symbol
    (Date.to_string ep.entry_date)
    (Date.to_string ep.end_date)
    ep.is_open ep.quantity ep.entry_price ep.actual_end_price threshold trail
    max_ratio cf_fired cf_date cf_price
    (100.0 *. delta /. ep.entry_price)
    (ep.quantity *. delta)

(* Guard against price-basis mismatch between the run's trades.csv (engine
   basis at run time) and the CSV store's adjusted_close (rebased by any
   split/dividend that happened AFTER the run's fetch — e.g. GME's 2022 4:1
   split makes its 2020 adjusted closes 4x smaller than the run's prices).
   The entry-week close must be within [0.66, 1.5] of the entry fill. *)
let _basis_consistent ~closes ~lo ~entry_price =
  let r = closes.(lo) /. entry_price in
  Float.( >= ) r 0.66 && Float.( <= ) r 1.5

let _trail_row ~run_label ~ep ~dates ~closes ~threshold ~max_ratio ~trigger ~hi
    trail =
  let cf =
    _trail_fire closes ~trigger ~hi ~trail
    |> Option.map ~f:(fun i -> (i, closes.(i)))
  in
  _row ~run_label ~ep ~threshold ~trail ~max_ratio ~cf ~dates

let _rows_at_trigger ~run_label ~ep ~dates ~closes ~threshold ~max_ratio ~hi
    ~trails trigger =
  List.map trails
    ~f:
      (_trail_row ~run_label ~ep ~dates ~closes ~threshold ~max_ratio ~trigger
         ~hi)

let _threshold_rows ~run_label ~ep ~dates ~closes ~mas ~lo ~hi ~max_ratio
    ~trails threshold =
  match _first_trigger closes mas ~lo ~hi ~threshold with
  | None -> []
  | Some trigger ->
      _rows_at_trigger ~run_label ~ep ~dates ~closes ~threshold ~max_ratio ~hi
        ~trails trigger

(* All (threshold x trail) rows for one basis-consistent episode. *)
let _all_threshold_rows ~run_label ~ep ~dates ~closes ~mas ~lo ~hi ~thresholds
    ~trails =
  let max_ratio =
    Option.value (_max_ratio closes mas ~lo ~hi) ~default:Float.nan
  in
  let ep =
    if ep.is_open then { ep with actual_end_price = closes.(hi) } else ep
  in
  List.concat_map thresholds
    ~f:
      (_threshold_rows ~run_label ~ep ~dates ~closes ~mas ~lo ~hi ~max_ratio
         ~trails)

let _episode_rows ~run_label ~ep ~dates ~closes ~mas ~thresholds ~trails
    ~basis_skipped =
  match
    _episode_range dates ~entry_date:ep.entry_date ~end_date:ep.end_date
  with
  | None -> []
  | Some (lo, _)
    when not (_basis_consistent ~closes ~lo ~entry_price:ep.entry_price) ->
      incr basis_skipped;
      []
  | Some (lo, hi) ->
      _all_threshold_rows ~run_label ~ep ~dates ~closes ~mas ~lo ~hi ~thresholds
        ~trails

let _header =
  "run,symbol,entry_date,end_date,is_open,quantity,entry_price,actual_end_price,threshold,trail,max_ratio,cf_fired,cf_date,cf_price,delta_pct_of_entry,delta_dollars"

let _floats_flag s = String.split s ~on:',' |> List.map ~f:Float.of_string

let _run ~run_label ~trades_csv ~open_csv ~data_dir ~run_end ~thresholds ~trails
    ~out =
  let run_end = Date.of_string run_end in
  let episodes =
    _parse_trades_csv trades_csv
    @ match open_csv with Some p -> _parse_open_csv p ~run_end | None -> []
  in
  let cache = Hashtbl.create (module String) in
  let skipped = ref 0 in
  let basis_skipped = ref 0 in
  let cached_series ep =
    Hashtbl.find_or_add cache ep.symbol ~default:(fun () ->
        _load_weekly_series ~data_dir ~symbol:ep.symbol ~end_date:run_end
        |> Result.ok)
  in
  let rows_for_episode ep =
    match cached_series ep with
    | None ->
        incr skipped;
        []
    | Some (dates, closes, mas) ->
        _episode_rows ~run_label ~ep ~dates ~closes ~mas
          ~thresholds:(_floats_flag thresholds) ~trails:(_floats_flag trails)
          ~basis_skipped
  in
  let rows = List.concat_map episodes ~f:rows_for_episode in
  Out_channel.write_lines out (_header :: rows);
  printf
    "%s: %d episodes (%d skipped: no bars; %d skipped: price-basis mismatch), \
     %d rows -> %s\n"
    run_label (List.length episodes) !skipped !basis_skipped (List.length rows)
    out

let command =
  Command.basic ~summary:"Extension-episode counterfactual trail-stop screen"
    (let%map_open.Command run_label =
       flag "-run-label" (required string) ~doc:"LABEL tag for output rows"
     and trades_csv =
       flag "-trades-csv" (required string) ~doc:"PATH run trades.csv"
     and open_csv =
       flag "-open-csv" (optional string) ~doc:"PATH run open_positions.csv"
     and data_dir =
       flag "-data-dir" (required string) ~doc:"PATH per-symbol CSV store"
     and run_end =
       flag "-run-end" (required string) ~doc:"DATE run end (YYYY-MM-DD)"
     and thresholds =
       flag "-thresholds"
         (optional_with_default "2.0,2.5,3.0" string)
         ~doc:"LIST close/MA trigger ratios"
     and trails =
       flag "-trails"
         (optional_with_default "0.10,0.15,0.20,0.25" string)
         ~doc:"LIST trail fractions below post-trigger peak"
     and out = flag "-out" (required string) ~doc:"PATH output CSV" in
     fun () ->
       _run ~run_label ~trades_csv ~open_csv ~data_dir ~run_end ~thresholds
         ~trails ~out)

let () = Command_unix.run command
