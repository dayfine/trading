open Core

type config = {
  target_length_days : int;
  mean_block_length : int;
  seed : int;
  start_date : Date.t;
  start_price : float;
}

(* OHLC + volume "shape" of a source bar, expressed as ratios to the close
   price plus the absolute volume and adj_close ratio. Replaying these
   ratios on top of any close price yields a well-formed bar with the same
   intra-day structure as the source bar. *)
type _bar_shape = {
  open_ratio : float;
  high_ratio : float;
  low_ratio : float;
  adj_close_ratio : float;
  volume : int;
}

let _identity_shape volume =
  {
    open_ratio = 1.0;
    high_ratio = 1.0;
    low_ratio = 1.0;
    adj_close_ratio = 1.0;
    volume;
  }

let _shape_of (b : Types.Daily_price.t) : _bar_shape =
  let c = b.close_price in
  if Float.(c <= 0.0) then _identity_shape b.volume
  else
    {
      open_ratio = b.open_price /. c;
      high_ratio = b.high_price /. c;
      low_ratio = b.low_price /. c;
      adj_close_ratio = b.adjusted_close /. c;
      volume = b.volume;
    }

let _apply_shape ~(shape : _bar_shape) ~close ~date : Types.Daily_price.t =
  {
    date;
    open_price = close *. shape.open_ratio;
    high_price = close *. shape.high_ratio;
    low_price = close *. shape.low_ratio;
    close_price = close;
    adjusted_close = close *. shape.adj_close_ratio;
    volume = shape.volume;
  }

(* ---------------------------------------------------------------------- *)
(* Validation                                                             *)
(* ---------------------------------------------------------------------- *)

let _check_source_length n =
  if n < 2 then
    Status.error_invalid_argument
      (Printf.sprintf "source must have at least 2 bars (got %d)" n)
  else Ok ()

let _check_target_days n =
  if n <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "target_length_days must be positive: %d" n)
  else Ok ()

let _check_mean_block_length n =
  if n <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "mean_block_length must be positive: %d" n)
  else Ok ()

let _check_start_price p =
  if Float.(p <= 0.0) then
    Status.error_invalid_argument
      (Printf.sprintf "start_price must be positive: %.4f" p)
  else Ok ()

let _check_source_vs_block ~source_n ~mean_block_length =
  if source_n >= 2 && source_n < mean_block_length then
    Status.error_invalid_argument
      (Printf.sprintf
         "source length (%d) must be >= mean_block_length (%d) for a \
          non-degenerate bootstrap"
         source_n mean_block_length)
  else Ok ()

let _validate ~source ~config =
  let n = List.length source in
  Status.combine_status_list
    [
      _check_source_length n;
      _check_target_days config.target_length_days;
      _check_mean_block_length config.mean_block_length;
      _check_start_price config.start_price;
      _check_source_vs_block ~source_n:n
        ~mean_block_length:config.mean_block_length;
    ]

(* ---------------------------------------------------------------------- *)
(* Sampling                                                               *)
(* ---------------------------------------------------------------------- *)

(* Inversion sampling for Geom(p): L = floor(log(1-u) / log(1-p)) + 1, with
   the +1 to ensure L >= 1 (geometric on positive integers has support
   {1, 2, ...}). [_geom_sample] is a pure helper; the caller has already
   validated p in (0, 1). *)
let _geom_sample ~one_minus_u ~one_minus_p =
  let l = Float.log one_minus_u /. Float.log one_minus_p in
  Int.max 1 (Int.of_float (Float.round_down l) + 1)

(* Compute the geometric distribution's [1 - p] parameter for a given mean.
   Returns [None] when the mean is degenerate (≤ 1.0) or when [1 - 1/mean]
   collapses to a non-positive value, so the caller can short-circuit to
   the [L = 1] fallback. *)
let _geom_one_minus_p ~mean_block_length =
  let mean = Float.of_int mean_block_length in
  let one_minus_p = if Float.(mean <= 1.0) then 0.0 else 1.0 -. (1.0 /. mean) in
  if Float.(one_minus_p <= 0.0) then None else Some one_minus_p

let _sample_block_length rng ~mean_block_length =
  match _geom_one_minus_p ~mean_block_length with
  | None -> 1
  | Some one_minus_p ->
      let u = Stdlib.Random.State.float rng 1.0 in
      let one_minus_u = Float.max (1.0 -. u) Float.min_positive_normal_value in
      _geom_sample ~one_minus_u ~one_minus_p

(* ---------------------------------------------------------------------- *)
(* Calendar                                                               *)
(* ---------------------------------------------------------------------- *)

let _next_business_day d =
  let next = Date.add_days d 1 in
  match Date.day_of_week next with
  | Sat -> Date.add_days next 2
  | Sun -> Date.add_days next 1
  | _ -> next

let _normalise_start_date d =
  match Date.day_of_week d with
  | Sat -> Date.add_days d 2
  | Sun -> Date.add_days d 1
  | _ -> d

let _business_days ~start_date ~n =
  let normalised_start = _normalise_start_date start_date in
  let rec loop acc d remaining =
    if remaining = 0 then List.rev acc
    else loop (d :: acc) (_next_business_day d) (remaining - 1)
  in
  loop [] normalised_start n

(* ---------------------------------------------------------------------- *)
(* Source returns + index sampling                                        *)
(* ---------------------------------------------------------------------- *)

let _build_returns (source_arr : Types.Daily_price.t array) =
  let n = Array.length source_arr in
  Array.init (n - 1) ~f:(fun i ->
      let prev = source_arr.(i).close_price in
      let curr = source_arr.(i + 1).close_price in
      if Float.(prev <= 0.0) || Float.(curr <= 0.0) then 0.0
      else Float.log (curr /. prev))

(* Sample [n_returns] return-array indices by drawing variable-length blocks
   that wrap around the end of the array. Returns a contiguous int array of
   length [n_returns] suitable for direct iteration. *)
let _sample_return_indices rng ~returns_n ~mean_block_length ~n_returns =
  let out = Array.create ~len:n_returns 0 in
  let written = ref 0 in
  while !written < n_returns do
    let start_idx = Stdlib.Random.State.int rng returns_n in
    let block_len = _sample_block_length rng ~mean_block_length in
    let to_write = Int.min block_len (n_returns - !written) in
    for k = 0 to to_write - 1 do
      out.(!written + k) <- (start_idx + k) mod returns_n
    done;
    written := !written + to_write
  done;
  out

(* ---------------------------------------------------------------------- *)
(* Compose synth bars                                                     *)
(* ---------------------------------------------------------------------- *)

(* Compose synth bars 1..n-1 by compounding sampled log-returns on top of
   the [start_price]. The first bar is built separately by the caller (it
   uses the source's bar-0 shape, not a sampled return). *)
let _compose_tail ~bars ~source_arr ~returns ~return_indices ~dates ~start_price
    =
  let n = Array.length bars in
  let prev_close = ref start_price in
  for k = 1 to n - 1 do
    let ri = return_indices.(k - 1) in
    let r = returns.(ri) in
    (* returns[ri] corresponds to source[ri + 1] *)
    let shape = _shape_of source_arr.(ri + 1) in
    let close = !prev_close *. Float.exp r in
    bars.(k) <- _apply_shape ~shape ~close ~date:dates.(k);
    prev_close := close
  done

let _generate_validated ~source ~config =
  let source_arr = Array.of_list source in
  let returns = _build_returns source_arr in
  let returns_n = Array.length returns in
  let rng = Stdlib.Random.State.make [| config.seed |] in
  let n = config.target_length_days in
  let dates =
    _business_days ~start_date:config.start_date ~n |> Array.of_list
  in
  let bars = Array.create ~len:n source_arr.(0) in
  let first_shape = _shape_of source_arr.(0) in
  bars.(0) <-
    _apply_shape ~shape:first_shape ~close:config.start_price ~date:dates.(0);
  (if n > 1 then
     let return_indices =
       _sample_return_indices rng ~returns_n
         ~mean_block_length:config.mean_block_length ~n_returns:(n - 1)
     in
     _compose_tail ~bars ~source_arr ~returns ~return_indices ~dates
       ~start_price:config.start_price);
  Array.to_list bars

let generate ~source ~config =
  Result.bind (_validate ~source ~config) ~f:(fun () ->
      Ok (_generate_validated ~source ~config))
