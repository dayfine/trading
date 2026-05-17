open Core
module CI = Composition_inputs
module BR = Composition_bar_reader

(* Defaults documented in [build_from_individuals.mli]. *)
let _default_trailing_window_days = 60
let _default_min_window_bars = 30

(* Forward window for the aggregate-return calculation (calendar days). *)
let _forward_window_days = 365

(* ------------------------------------------------------------------ *)
(* Config                                                              *)
(* ------------------------------------------------------------------ *)

type config = {
  size : int;
  trailing_window_days : int;
  min_window_bars : int;
  bars_root : string;
  symbol_types_path : string;
  sectors_csv_path : string;
  inventory_path : string;
}
[@@deriving sexp]

let default_config ~size ~bars_root ~symbol_types_path ~sectors_csv_path
    ~inventory_path =
  {
    size;
    trailing_window_days = _default_trailing_window_days;
    min_window_bars = _default_min_window_bars;
    bars_root;
    symbol_types_path;
    sectors_csv_path;
    inventory_path;
  }

(* ------------------------------------------------------------------ *)
(* Activity + equity-like filtering                                    *)
(* ------------------------------------------------------------------ *)

let _trailing_window_start ~date ~config =
  Date.add_days date (-config.trailing_window_days)

let _is_active ~date ~required_start (entry : CI.inventory_entry) =
  Date.( <= ) entry.data_start_date required_start
  && Date.( >= ) entry.data_end_date date

let _active_symbols ~date ~config (inventory : CI.inventory) =
  let required_start = _trailing_window_start ~date ~config in
  List.filter_map inventory.symbols ~f:(fun e ->
      if _is_active ~date ~required_start e then Some e.symbol else None)

let _filter_by_equity_like ~equity_like_lookup symbols =
  List.filter symbols ~f:(fun s ->
      match Hashtbl.find equity_like_lookup s with
      | Some true -> true
      | _ -> false)

(* ------------------------------------------------------------------ *)
(* Dollar-volume scoring                                               *)
(* ------------------------------------------------------------------ *)

let _in_trailing_window ~date ~config (b : BR.bar) =
  let start_d = _trailing_window_start ~date ~config in
  Date.( >= ) b.date start_d && Date.( <= ) b.date date

let _dollar_volume_score ~date ~config bars =
  let window =
    List.filter bars ~f:(fun b -> _in_trailing_window ~date ~config b)
  in
  let n = List.length window in
  if n < config.min_window_bars then None
  else
    let total =
      List.fold window ~init:0.0 ~f:(fun acc (b : BR.bar) ->
          acc +. (b.close *. b.volume))
    in
    Some (total /. Float.of_int n)

(* ------------------------------------------------------------------ *)
(* Forward-return calculation                                          *)
(* ------------------------------------------------------------------ *)

let _forward_window_end ~date = Date.add_days date _forward_window_days

let _first_on_or_after ~date bars =
  List.find bars ~f:(fun (b : BR.bar) -> Date.( >= ) b.date date)

let _last_on_or_before ~date bars =
  List.fold bars ~init:None ~f:(fun acc (b : BR.bar) ->
      if Date.( <= ) b.date date then Some b else acc)

let _forward_return ~date bars =
  let end_date = _forward_window_end ~date in
  match
    (_first_on_or_after ~date bars, _last_on_or_before ~date:end_date bars)
  with
  | Some (p_start : BR.bar), Some (p_end : BR.bar)
    when Float.(p_start.adjusted_close > 0.0)
         && Date.( > ) p_end.date p_start.date ->
      Some ((p_end.adjusted_close /. p_start.adjusted_close) -. 1.0)
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Build pipeline                                                      *)
(* ------------------------------------------------------------------ *)

(* Per-symbol scoring result. [forward_return] is computed eagerly at
   scoring time so [bars] can be dropped immediately — the prior shape
   retained [bars : BR.bar list] across every candidate symbol (post-filter
   ~5-7k symbols × ~1k bars × ~50 bytes ≈ 250 MB at the broad-universe
   scale), which OOMed multi-year × multi-size runner invocations. Both
   the dollar-volume score (trailing window) and the forward-return
   (forward window) read disjoint slices of the same [bars] list, so the
   bars only need to be live for the duration of one
   [_dollar_volume_score] + [_forward_return] call pair, not until the
   downstream rank + take + aggregate steps. *)
type _scored = { symbol : string; score : float; forward_return : float option }

let _score_symbol ~date ~config symbol : _scored option =
  match BR.read_bars ~bars_root:config.bars_root symbol with
  | None -> None
  | Some bars -> (
      match _dollar_volume_score ~date ~config bars with
      | None -> None
      | Some score ->
          let forward_return = _forward_return ~date bars in
          Some { symbol; score; forward_return })

let _score_all ~date ~config symbols : _scored list =
  List.filter_map symbols ~f:(_score_symbol ~date ~config)

let _rank_desc scored =
  List.sort scored ~compare:(fun a b -> Float.compare b.score a.score)

let _sector_for ~sector_lookup symbol =
  match Hashtbl.find sector_lookup symbol with Some s -> s | None -> ""

let _make_entry ~sector_lookup ~uniform_weight scored : Snapshot.entry =
  {
    symbol = scored.symbol;
    weight = uniform_weight;
    sector = _sector_for ~sector_lookup scored.symbol;
    synthetic = false;
  }

let _aggregate_period_return scored_kept =
  let per_symbol_returns =
    List.filter_map scored_kept ~f:(fun s -> s.forward_return)
  in
  match per_symbol_returns with
  | [] -> 0.0
  | rs ->
      let sum = List.fold rs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length rs)

let _validate_size size =
  if size <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "build_from_individuals: size must be > 0 (got %d)" size)
  else Ok ()

let _insufficient_signal_error ~survived ~required =
  Status.error_invalid_argument
    (Printf.sprintf
       "build_from_individuals: only %d symbols survived ranking, need %d \
        (insufficient signal at this date)"
       survived required)

let _take_top_n_or_error ~size scored : _scored list Status.status_or =
  let n = List.length scored in
  if n < size then _insufficient_signal_error ~survived:n ~required:size
  else Ok (List.take scored size)

let _composition_method : Snapshot.method_ = Composition_from_individuals

let _make_snapshot ~date ~config ~entries ~aggregate_period_return : Snapshot.t
    =
  {
    date;
    method_ = _composition_method;
    size = config.size;
    entries;
    aggregate_period_return;
  }

let _build_validated ~date ~config ~inventory ~equity_like_lookup ~sector_lookup
    =
  let active = _active_symbols ~date ~config inventory in
  let equity_like = _filter_by_equity_like ~equity_like_lookup active in
  let scored = _score_all ~date ~config equity_like in
  let ranked = _rank_desc scored in
  let%bind.Result kept = _take_top_n_or_error ~size:config.size ranked in
  let uniform_weight = 1.0 /. Float.of_int config.size in
  let entries = List.map kept ~f:(_make_entry ~sector_lookup ~uniform_weight) in
  let aggregate_period_return = _aggregate_period_return kept in
  Ok (_make_snapshot ~date ~config ~entries ~aggregate_period_return)

let build ~date ~config =
  let open Result.Let_syntax in
  let%bind () = _validate_size config.size in
  let%bind inventory = CI.load_inventory config.inventory_path in
  let%bind equity_like_lookup =
    CI.load_equity_like_lookup config.symbol_types_path
  in
  let%bind sector_lookup = CI.load_sectors config.sectors_csv_path in
  _build_validated ~date ~config ~inventory ~equity_like_lookup ~sector_lookup
