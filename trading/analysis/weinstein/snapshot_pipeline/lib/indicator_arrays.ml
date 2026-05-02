open Core

(* Bit-identity: every recurrence below uses the same expression form and the
   same accumulation order as the prior recompute-from-zero implementations
   in [Pipeline]'s history. The hand-pinned indicator tests in [test/] verify
   this. The forms mirror the kernels in [trading/data_panel/{ema,sma,atr,rsi}_kernel.ml]
   without the panel scaffolding (one symbol, scalar state). *)

let sma ~closes ~period =
  let n = Array.length closes in
  let out = Array.create ~len:n Float.nan in
  let period_f = Float.of_int period in
  for i = period - 1 to n - 1 do
    let acc = ref 0.0 in
    for k = 0 to period - 1 do
      let v = closes.(i - k) in
      acc := !acc +. v
    done;
    out.(i) <- !acc /. period_f
  done;
  out

let ema ~closes ~period =
  let n = Array.length closes in
  let out = Array.create ~len:n Float.nan in
  if n < period then out
  else
    let alpha = 2.0 /. (Float.of_int period +. 1.0) in
    let one_minus_a = 1.0 -. alpha in
    let warmup_sum = ref 0.0 in
    for k = 0 to period - 1 do
      warmup_sum := !warmup_sum +. closes.(k)
    done;
    let seed = !warmup_sum /. Float.of_int period in
    out.(period - 1) <- seed;
    let prev = ref seed in
    for t = period to n - 1 do
      let new_v = closes.(t) in
      let p = !prev in
      let v = (alpha *. new_v) +. (one_minus_a *. p) in
      out.(t) <- v;
      prev := v
    done;
    out

let _true_range ~highs ~lows ~closes ~t =
  let h = highs.(t) in
  let l = lows.(t) in
  let prev_c = closes.(t - 1) in
  let r1 = h -. l in
  let r2 = Float.abs (h -. prev_c) in
  let r3 = Float.abs (l -. prev_c) in
  Float.max r1 (Float.max r2 r3)

let atr ~highs ~lows ~closes ~period =
  let n = Array.length closes in
  let out = Array.create ~len:n Float.nan in
  if n <= period then out
  else
    let p_minus = Float.of_int (period - 1) in
    let p_f = Float.of_int period in
    let seed_sum = ref 0.0 in
    for k = 1 to period do
      seed_sum := !seed_sum +. _true_range ~highs ~lows ~closes ~t:k
    done;
    let seed = !seed_sum /. p_f in
    out.(period) <- seed;
    let prev = ref seed in
    for t = period + 1 to n - 1 do
      let tr = _true_range ~highs ~lows ~closes ~t in
      let v = ((!prev *. p_minus) +. tr) /. p_f in
      out.(t) <- v;
      prev := v
    done;
    out

let _rsi_from_avgs ~avg_gain ~avg_loss =
  let rs = avg_gain /. avg_loss in
  if not (Float.is_finite rs) then 100.0 else 100.0 -. (100.0 /. (1.0 +. rs))

let rsi ~closes ~period =
  let n = Array.length closes in
  let out = Array.create ~len:n Float.nan in
  if n <= period then out
  else
    let p_minus = Float.of_int (period - 1) in
    let p_f = Float.of_int period in
    let avg_gain = ref 0.0 in
    let avg_loss = ref 0.0 in
    for k = 1 to period do
      let diff = closes.(k) -. closes.(k - 1) in
      let g = Float.max diff 0.0 in
      let l = Float.max (Float.neg diff) 0.0 in
      avg_gain := !avg_gain +. g;
      avg_loss := !avg_loss +. l
    done;
    avg_gain := !avg_gain /. p_f;
    avg_loss := !avg_loss /. p_f;
    out.(period) <- _rsi_from_avgs ~avg_gain:!avg_gain ~avg_loss:!avg_loss;
    for t = period + 1 to n - 1 do
      let diff = closes.(t) -. closes.(t - 1) in
      let g = Float.max diff 0.0 in
      let l = Float.max (Float.neg diff) 0.0 in
      avg_gain := ((!avg_gain *. p_minus) +. g) /. p_f;
      avg_loss := ((!avg_loss *. p_minus) +. l) /. p_f;
      out.(t) <- _rsi_from_avgs ~avg_gain:!avg_gain ~avg_loss:!avg_loss
    done;
    out
