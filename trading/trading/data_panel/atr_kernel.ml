module BA2 = Bigarray.Array2

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) BA2.t

let warmup ~period = period

let _check_args ~(high : panel) ~(low : panel) ~(close : panel)
    ~(output : panel) ~period ~t =
  if period < 1 then
    invalid_arg
      (Printf.sprintf "Atr_kernel.advance: period must be >= 1, got %d" period);
  let n_rows = Bigarray.Array2.dim1 high in
  let n_cols = Bigarray.Array2.dim2 high in
  let same_shape (p : panel) = BA2.dim1 p = n_rows && BA2.dim2 p = n_cols in
  if not (same_shape low && same_shape close && same_shape output) then
    invalid_arg
      (Printf.sprintf
         "Atr_kernel.advance: shape mismatch (expected %dx%d for all four \
          panels)"
         n_rows n_cols);
  if t < 0 || t >= n_cols then
    invalid_arg
      (Printf.sprintf "Atr_kernel.advance: t %d out of range [0, %d)" t n_cols)

let _fill_nan ~(output : panel) ~t =
  let n_rows = BA2.dim1 output in
  for r = 0 to n_rows - 1 do
    BA2.unsafe_set output r t Float.nan
  done

(* True Range for a single (row, col) pair. Reads bound to named locals to
   preserve bit-exactness across compilation schedules (Stage 0 lesson). *)
let _tr ~(high : panel) ~(low : panel) ~(close : panel) ~r ~t =
  let h = BA2.unsafe_get high r t in
  let l = BA2.unsafe_get low r t in
  let pc = BA2.unsafe_get close r (t - 1) in
  let range = h -. l in
  let gap_up = Float.abs (h -. pc) in
  let gap_down = Float.abs (l -. pc) in
  Float.max range (Float.max gap_up gap_down)

(* Seed at [t = period]: simple average of TR over the [period]-tick window
   [1..period] (TR is undefined at t=0 with no prior close). Left-to-right
   summation, [acc := !acc +. tr]. *)
let _seed_warmup ~high ~low ~close ~(output : panel) ~period ~t =
  let n_rows = BA2.dim1 output in
  let period_f = Float.of_int period in
  for r = 0 to n_rows - 1 do
    let acc = ref 0.0 in
    for k = 1 to period do
      let tr = _tr ~high ~low ~close ~r ~t:k in
      acc := !acc +. tr
    done;
    BA2.unsafe_set output r t (!acc /. period_f)
  done

(* Wilder recurrence at [t > period]: ATR_t = (ATR_{t-1} * (P-1) + TR_t) / P. *)
let _step_recurrence ~high ~low ~close ~(output : panel) ~period ~t =
  let n_rows = BA2.dim1 output in
  let period_f = Float.of_int period in
  let pm1 = Float.of_int (period - 1) in
  for r = 0 to n_rows - 1 do
    let prev = BA2.unsafe_get output r (t - 1) in
    let tr = _tr ~high ~low ~close ~r ~t in
    let new_v = ((prev *. pm1) +. tr) /. period_f in
    BA2.unsafe_set output r t new_v
  done

let advance ~high ~low ~close ~output ~period ~t =
  _check_args ~high ~low ~close ~output ~period ~t;
  let w = warmup ~period in
  if t < w then _fill_nan ~output ~t
  else if t = w then _seed_warmup ~high ~low ~close ~output ~period ~t
  else _step_recurrence ~high ~low ~close ~output ~period ~t
