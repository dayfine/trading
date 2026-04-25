module BA2 = Bigarray.Array2

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) BA2.t

let warmup ~period = period - 1
let alpha ~period = 2.0 /. (Float.of_int period +. 1.0)

let _check_args ~(input : panel) ~(output : panel) ~period ~t =
  if period < 1 then
    invalid_arg
      (Printf.sprintf "Ema_kernel.advance: period must be >= 1, got %d" period);
  let n_rows_in = BA2.dim1 input in
  let n_cols_in = BA2.dim2 input in
  let n_rows_out = BA2.dim1 output in
  let n_cols_out = BA2.dim2 output in
  if n_rows_in <> n_rows_out || n_cols_in <> n_cols_out then
    invalid_arg
      (Printf.sprintf
         "Ema_kernel.advance: shape mismatch input=%dx%d output=%dx%d" n_rows_in
         n_cols_in n_rows_out n_cols_out);
  if t < 0 || t >= n_cols_out then
    invalid_arg
      (Printf.sprintf "Ema_kernel.advance: t %d out of range [0, %d)" t
         n_cols_out)

let _fill_nan ~(output : panel) ~t =
  let n_rows = BA2.dim1 output in
  for r = 0 to n_rows - 1 do
    BA2.unsafe_set output r t Float.nan
  done

let _seed_warmup ~(input : panel) ~(output : panel) ~period ~t =
  (* Simple average of input[r, 0..period-1], left-to-right summation, then
     divide by period. Matches the standard EMA seed used by TA-Lib's
     ta_ema and by hand-rolled scalar EMAs. *)
  let n_rows = BA2.dim1 input in
  let period_f = Float.of_int period in
  for r = 0 to n_rows - 1 do
    let acc = ref 0.0 in
    for k = 0 to period - 1 do
      acc := !acc +. BA2.unsafe_get input r k
    done;
    BA2.unsafe_set output r t (!acc /. period_f)
  done

let _step_recurrence ~(input : panel) ~(output : panel) ~period ~t =
  let n_rows = BA2.dim1 input in
  let a = alpha ~period in
  let one_minus_a = 1.0 -. a in
  for r = 0 to n_rows - 1 do
    let new_v = BA2.unsafe_get input r t in
    let prev = BA2.unsafe_get output r (t - 1) in
    BA2.unsafe_set output r t ((a *. new_v) +. (one_minus_a *. prev))
  done

let advance ~input ~output ~period ~t =
  _check_args ~input ~output ~period ~t;
  let w = warmup ~period in
  if t < w then _fill_nan ~output ~t
  else if t = w then _seed_warmup ~input ~output ~period ~t
  else _step_recurrence ~input ~output ~period ~t
