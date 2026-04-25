module BA2 = Bigarray.Array2

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) BA2.t

let warmup ~period = period - 1

let _check_args ~(input : panel) ~(output : panel) ~period ~t =
  if period < 1 then
    invalid_arg
      (Printf.sprintf "Sma_kernel.advance: period must be >= 1, got %d" period);
  let n_rows_in = BA2.dim1 input in
  let n_cols_in = BA2.dim2 input in
  let n_rows_out = BA2.dim1 output in
  let n_cols_out = BA2.dim2 output in
  if n_rows_in <> n_rows_out || n_cols_in <> n_cols_out then
    invalid_arg
      (Printf.sprintf
         "Sma_kernel.advance: shape mismatch input=%dx%d output=%dx%d" n_rows_in
         n_cols_in n_rows_out n_cols_out);
  if t < 0 || t >= n_cols_out then
    invalid_arg
      (Printf.sprintf "Sma_kernel.advance: t %d out of range [0, %d)" t
         n_cols_out)

let _fill_nan ~(output : panel) ~t =
  let n_rows = BA2.dim1 output in
  for r = 0 to n_rows - 1 do
    BA2.unsafe_set output r t Float.nan
  done

(* Window mean: left-to-right summation of [input] columns [t - period + 1 .. t]
   bound to a local [v] before the accumulate, mirroring [Ema_kernel]'s warmup
   so a scalar reference written with the same expression form produces
   bit-identical output. *)
let _step_window ~(input : panel) ~(output : panel) ~period ~t =
  let n_rows = BA2.dim1 input in
  let period_f = Float.of_int period in
  let start_col = t - period + 1 in
  for r = 0 to n_rows - 1 do
    let acc = ref 0.0 in
    for k = 0 to period - 1 do
      let v = BA2.unsafe_get input r (start_col + k) in
      acc := !acc +. v
    done;
    BA2.unsafe_set output r t (!acc /. period_f)
  done

let advance ~input ~output ~period ~t =
  _check_args ~input ~output ~period ~t;
  let w = warmup ~period in
  if t < w then _fill_nan ~output ~t else _step_window ~input ~output ~period ~t
