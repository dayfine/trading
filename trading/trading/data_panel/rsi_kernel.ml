module BA2 = Bigarray.Array2

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) BA2.t

let warmup ~period = period

let _check_args ~(close : panel) ~(avg_gain : panel) ~(avg_loss : panel)
    ~(output : panel) ~period ~t =
  if period < 1 then
    invalid_arg
      (Printf.sprintf "Rsi_kernel.advance: period must be >= 1, got %d" period);
  let n_rows = BA2.dim1 close in
  let n_cols = BA2.dim2 close in
  let same_shape (p : panel) = BA2.dim1 p = n_rows && BA2.dim2 p = n_cols in
  if not (same_shape avg_gain && same_shape avg_loss && same_shape output) then
    invalid_arg
      (Printf.sprintf
         "Rsi_kernel.advance: shape mismatch (expected %dx%d for all four \
          panels)"
         n_rows n_cols);
  if t < 0 || t >= n_cols then
    invalid_arg
      (Printf.sprintf "Rsi_kernel.advance: t %d out of range [0, %d)" t n_cols)

let _fill_nan_all ~avg_gain ~avg_loss ~(output : panel) ~t =
  let n_rows = BA2.dim1 output in
  for r = 0 to n_rows - 1 do
    BA2.unsafe_set avg_gain r t Float.nan;
    BA2.unsafe_set avg_loss r t Float.nan;
    BA2.unsafe_set output r t Float.nan
  done

(* Per-row [diff = close[t] - close[t-1]], split into gain/loss. Reads bound to
   named locals to preserve bit-exactness across compilation schedules. *)
let _gain_loss ~(close : panel) ~r ~t =
  let c = BA2.unsafe_get close r t in
  let pc = BA2.unsafe_get close r (t - 1) in
  let diff = c -. pc in
  let gain = if diff > 0.0 then diff else 0.0 in
  let loss = if diff < 0.0 then -.diff else 0.0 in
  (gain, loss)

(* RSI from avg_gain / avg_loss. avg_loss = 0 maps to RSI = 100. NaN inputs
   propagate. *)
let _rsi_from_avgs ~avg_gain_v ~avg_loss_v =
  if Float.is_nan avg_gain_v || Float.is_nan avg_loss_v then Float.nan
  else if avg_loss_v = 0.0 then 100.0
  else
    let rs = avg_gain_v /. avg_loss_v in
    100.0 -. (100.0 /. (1.0 +. rs))

(* Seed at [t = period]: simple average of gain/loss over window [1..period]. *)
let _seed_warmup ~close ~(avg_gain : panel) ~(avg_loss : panel)
    ~(output : panel) ~period ~t =
  let n_rows = BA2.dim1 output in
  let period_f = Float.of_int period in
  for r = 0 to n_rows - 1 do
    let acc_g = ref 0.0 in
    let acc_l = ref 0.0 in
    for k = 1 to period do
      let g, l = _gain_loss ~close ~r ~t:k in
      acc_g := !acc_g +. g;
      acc_l := !acc_l +. l
    done;
    let avg_g = !acc_g /. period_f in
    let avg_l = !acc_l /. period_f in
    BA2.unsafe_set avg_gain r t avg_g;
    BA2.unsafe_set avg_loss r t avg_l;
    BA2.unsafe_set output r t
      (_rsi_from_avgs ~avg_gain_v:avg_g ~avg_loss_v:avg_l)
  done

(* Wilder recurrence: avg = (prev_avg * (P-1) + new) / P for both gain & loss. *)
let _step_recurrence ~close ~(avg_gain : panel) ~(avg_loss : panel)
    ~(output : panel) ~period ~t =
  let n_rows = BA2.dim1 output in
  let period_f = Float.of_int period in
  let pm1 = Float.of_int (period - 1) in
  for r = 0 to n_rows - 1 do
    let prev_g = BA2.unsafe_get avg_gain r (t - 1) in
    let prev_l = BA2.unsafe_get avg_loss r (t - 1) in
    let g, l = _gain_loss ~close ~r ~t in
    let new_g = ((prev_g *. pm1) +. g) /. period_f in
    let new_l = ((prev_l *. pm1) +. l) /. period_f in
    BA2.unsafe_set avg_gain r t new_g;
    BA2.unsafe_set avg_loss r t new_l;
    BA2.unsafe_set output r t
      (_rsi_from_avgs ~avg_gain_v:new_g ~avg_loss_v:new_l)
  done

let advance ~close ~avg_gain ~avg_loss ~output ~period ~t =
  _check_args ~close ~avg_gain ~avg_loss ~output ~period ~t;
  let w = warmup ~period in
  if t < w then _fill_nan_all ~avg_gain ~avg_loss ~output ~t
  else if t = w then _seed_warmup ~close ~avg_gain ~avg_loss ~output ~period ~t
  else _step_recurrence ~close ~avg_gain ~avg_loss ~output ~period ~t
