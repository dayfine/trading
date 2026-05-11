open Core

type config = {
  n_symbols : int;
  symbols : string list option;
  market : Synth_v2.config;
  loading_distribution : Factor_model.loading_distribution;
  idio_distribution : Factor_model.idio_distribution;
  start_price : float;
  seed : int;
}

type universe = { symbols : (string * Types.Daily_price.t list) list }

(* ---------------------------------------------------------------------- *)
(* Default naming                                                         *)
(* ---------------------------------------------------------------------- *)

let default_symbol_names ~n =
  if n <= 0 then []
  else
    List.init n ~f:(fun i ->
        if n <= 9999 then Printf.sprintf "SYNTH_%04d" (i + 1)
        else Printf.sprintf "SYNTH_%d" (i + 1))

(* ---------------------------------------------------------------------- *)
(* Default config                                                         *)
(* ---------------------------------------------------------------------- *)

let default_config ~n_symbols ~start_date ~start_price ~target_length_days ~seed
    =
  let market =
    Synth_v2.default_config ~start_date ~start_price ~target_length_days ~seed
  in
  {
    n_symbols;
    symbols = None;
    market;
    loading_distribution = Factor_model.default_loading_distribution;
    idio_distribution = Factor_model.default_idio_distribution;
    start_price;
    seed;
  }

(* ---------------------------------------------------------------------- *)
(* Validation                                                             *)
(* ---------------------------------------------------------------------- *)

let _check_n_symbols n =
  if n <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "synth_v3: n_symbols must be > 0 (got %d)" n)
  else Ok ()

let _check_start_price p =
  if Float.(p <= 0.0) then
    Status.error_invalid_argument
      (Printf.sprintf "synth_v3: start_price must be > 0 (got %.4f)" p)
  else Ok ()

let _check_symbols_length (config : config) =
  match config.symbols with
  | None -> Ok ()
  | Some lst when List.length lst = config.n_symbols -> Ok ()
  | Some lst ->
      Status.error_invalid_argument
        (Printf.sprintf
           "synth_v3: symbols list length %d does not match n_symbols %d"
           (List.length lst) config.n_symbols)

let _validate config =
  Status.combine_status_list
    [
      _check_n_symbols config.n_symbols;
      _check_start_price config.start_price;
      _check_symbols_length config;
      Factor_model.validate_loading_distribution config.loading_distribution;
      Factor_model.validate_idio_distribution config.idio_distribution;
    ]

(* ---------------------------------------------------------------------- *)
(* Seed cascade — see module docstring                                    *)
(* ---------------------------------------------------------------------- *)

let _beta_seed_offset = 100_000
let _idio_param_seed_offset = 200_000
let _idio_stream_seed_base = 1_000_000
let _seed_for_betas seed = seed + _beta_seed_offset
let _seed_for_idio_params seed = seed + _idio_param_seed_offset
let _seed_for_symbol_returns seed i = seed + _idio_stream_seed_base + i

(* ---------------------------------------------------------------------- *)
(* Market-return extraction                                               *)
(* ---------------------------------------------------------------------- *)

(* Step function for the fold below: emit log(close/prev_close), advance the
   prev-close accumulator. *)
let _accumulate_log_return (prev_close, acc) (b : Types.Daily_price.t) =
  let r = Float.log (b.close_price /. prev_close) in
  (b.close_price, r :: acc)

(* Pull log-returns from a sequence of bars: r_t = log(close_t / close_{t-1}).
   Returns a list of length [List.length bars - 1]; the first bar has no
   preceding bar so no return is emitted for it. *)
let _log_returns_from_bars (bars : Types.Daily_price.t list) =
  match bars with
  | [] | [ _ ] -> []
  | first :: rest ->
      let _final_acc, returns =
        List.fold rest ~init:(first.close_price, []) ~f:_accumulate_log_return
      in
      List.rev returns

(* ---------------------------------------------------------------------- *)
(* Bar shape — mirror Synth_v2's intra-day band                           *)
(* ---------------------------------------------------------------------- *)

let _synthetic_volume = 10_000_000

let _build_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close *. 0.999;
    high_price = close *. 1.005;
    low_price = close *. 0.995;
    close_price = close;
    adjusted_close = close;
    volume = _synthetic_volume;
  }

(* Compose a per-symbol bar series from log-returns and a date sequence. *)
let _bars_from_returns ~dates ~start_price ~log_returns =
  let dates_arr = Array.of_list dates in
  let returns_arr = Array.of_list log_returns in
  let n = Array.length dates_arr in
  if n = 0 then []
  else begin
    let bars =
      Array.create ~len:n (_build_bar ~date:dates_arr.(0) ~close:start_price)
    in
    bars.(0) <- _build_bar ~date:dates_arr.(0) ~close:start_price;
    let prev_close = ref start_price in
    for k = 1 to n - 1 do
      (* returns_arr has length n-1; element (k-1) is the log-return from bar
         k-1 to bar k. *)
      let close = !prev_close *. Float.exp returns_arr.(k - 1) in
      bars.(k) <- _build_bar ~date:dates_arr.(k) ~close;
      prev_close := close
    done;
    Array.to_list bars
  end

(* ---------------------------------------------------------------------- *)
(* Symbol naming resolution                                               *)
(* ---------------------------------------------------------------------- *)

let _resolve_symbol_names (config : config) =
  match config.symbols with
  | Some lst -> lst
  | None -> default_symbol_names ~n:config.n_symbols

(* ---------------------------------------------------------------------- *)
(* Universe generation                                                    *)
(* ---------------------------------------------------------------------- *)

let _generate_symbol ~dates ~start_price ~market_returns ~beta ~idio_params
    ~seed name =
  let symbol_returns =
    Factor_model.generate_symbol_returns ~market_returns ~beta ~idio_params
      ~seed
  in
  let bars =
    _bars_from_returns ~dates ~start_price ~log_returns:symbol_returns
  in
  (name, bars)

let _assemble_universe ~dates ~market_returns ~betas ~idio_params ~names
    (config : config) =
  let zipped =
    List.zip_exn names (List.zip_exn betas idio_params)
    |> List.mapi ~f:Tuple2.create
  in
  let bars =
    List.map zipped ~f:(fun (i, (name, (beta, idio_params))) ->
        _generate_symbol ~dates ~start_price:config.start_price ~market_returns
          ~beta ~idio_params
          ~seed:(_seed_for_symbol_returns config.seed i)
          name)
  in
  { symbols = bars }

let _dates_of_bars (bars : Types.Daily_price.t list) =
  List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.date)

let _sample_betas_for_config (config : config) =
  Factor_model.sample_betas config.loading_distribution ~n:config.n_symbols
    ~seed:(_seed_for_betas config.seed)

let _sample_idio_params_for_config (config : config) =
  Factor_model.sample_idio_params config.idio_distribution ~n:config.n_symbols
    ~seed:(_seed_for_idio_params config.seed)

let _build_universe_from_market (config : config)
    (market_bars : Types.Daily_price.t list) =
  let dates = _dates_of_bars market_bars in
  let market_returns = _log_returns_from_bars market_bars in
  let betas = _sample_betas_for_config config in
  let idio_params = _sample_idio_params_for_config config in
  let names = _resolve_symbol_names config in
  _assemble_universe ~dates ~market_returns ~betas ~idio_params ~names config

(* Run after [_validate] has succeeded, so we can rely on input shape. *)
let _generate_validated (config : config) =
  Result.map
    (Synth_v2.generate config.market)
    ~f:(_build_universe_from_market config)

let generate (config : config) =
  Result.bind (_validate config) ~f:(fun () -> _generate_validated config)
