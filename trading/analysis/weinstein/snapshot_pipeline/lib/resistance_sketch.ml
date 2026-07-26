open Core
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

type t = {
  max_high_130w : float array;
  max_high_260w : float array;
  max_high_520w : float array;
  bars_seen : float array;
  hist : float array array;
}

(* Horizon constants are locked to the schema-field naming
   ([Res_max_high_130w] etc.) so any drift between schema and sketch is
   loud — same discipline as [Pipeline]'s [_ema_period]. *)
let _horizon_130_weeks = 130
let _horizon_260_weeks = 260
let _horizon_520_weeks = 520

(* Age-banded histogram (lever f): the histogram now looks back the full 520
   weekly bars, split into four age bands by a weekly bar's age relative to the
   row (the partial current week is age 0, the most recent finalized week age 1,
   ...). Band boundaries are half-open: [0,26) / [26,78) / [78,130) / [130,520).
   The three 0-130w bands union to the pre-lever-f trailing-130w window, so
   summing them reproduces the old age-blind histogram exactly. *)
let _hist_lookback_weeks = 520
let _age_break_26_weeks = 26
let _age_break_78_weeks = 78
let _age_break_130_weeks = 130
let _bars_seen_cap = 520
let _ln2 = Float.log 2.0

(* Age band index (0..n_age_bands-1) for a weekly bar of [age] weeks. *)
let _age_band_of ~age =
  if age < _age_break_26_weeks then 0
  else if age < _age_break_78_weeks then 1
  else if age < _age_break_130_weeks then 2
  else 3

(* Column index of price bucket [bucket] within age band [band] in the
   band-major [Res_hist] layout (matches [Snapshot_schema] cell ordering). *)
let _cell_index ~band ~bucket = (band * Snapshot_schema.n_hist_buckets) + bucket

(* Pop deque entries whose high is <= the incoming one, then push [j].
   Keeps [dq] a decreasing-highs monotonic deque of finalized indices. *)
let _push_monotonic dq (highs : float array) j =
  while
    (not (Deque.is_empty dq))
    && Float.(highs.(Deque.peek_back_exn dq) <= highs.(j))
  do
    ignore (Deque.dequeue_back_exn dq : int)
  done;
  Deque.enqueue_back dq j

(** Sliding max of the finalized weekly highs over the trailing
    [horizon_weeks - 1] finalized bars, folded with the day's partial-week high
    — i.e. the max over the trailing [horizon_weeks] weekly bars including the
    partial week. Amortized O(1) per day. *)
let _rolling_max_column ~(finalized_highs : float array)
    ~(fc_at_day : int array) ~(partial_highs : float array) ~horizon_weeks =
  let n = Array.length fc_at_day in
  let out = Array.create ~len:n Float.nan in
  let win = horizon_weeks - 1 in
  let dq = Deque.create () in
  let pushed = ref 0 in
  for i = 0 to n - 1 do
    let fc = fc_at_day.(i) in
    while !pushed < fc do
      _push_monotonic dq finalized_highs !pushed;
      incr pushed
    done;
    while (not (Deque.is_empty dq)) && Deque.peek_front_exn dq < fc - win do
      ignore (Deque.dequeue_front_exn dq : int)
    done;
    let fin_max =
      if Deque.is_empty dq then Float.neg_infinity
      else finalized_highs.(Deque.peek_front_exn dq)
    in
    out.(i) <- Float.max fin_max partial_highs.(i)
  done;
  out

(* Bucket index for a weekly bar's mid-price in the log grid anchored at
   [anchor]: k = floor(n_hist_buckets * log2(mid / anchor)), so the grid
   spans [anchor, 2 * anchor) regardless of bucket count. [None] when the
   ratio is degenerate (non-finite result). *)
let _bucket_of ~anchor ~mid =
  let k =
    Float.round_down
      (Float.of_int Snapshot_schema.n_hist_buckets
      *. Float.log (mid /. anchor)
      /. _ln2)
  in
  if Float.is_finite k then Some (Int.of_float k) else None

(* Count one weekly bar of age [band] into [hist] at day [i] when it sits above
   [anchor] and its mid lands in a canonical bucket. Mirrors the v1 mapper's
   accumulation rule: [high > breakout] gates, the mid-price buckets; the age
   band selects which of the four band-major column groups the count lands in. *)
let _accumulate_hist ~hist ~i ~band ~anchor ~weekly_high ~weekly_low =
  if Float.(weekly_high > anchor) then
    let mid = (weekly_high +. weekly_low) /. 2.0 in
    match _bucket_of ~anchor ~mid with
    | Some bucket when bucket >= 0 && bucket < Snapshot_schema.n_hist_buckets ->
        let cell = _cell_index ~band ~bucket in
        hist.(cell).(i) <- hist.(cell).(i) +. 1.0
    | _ -> ()

let _hist_for_day ~hist ~(weekly_prefix : Weekly_prefix.t) ~i ~anchor =
  let fin = weekly_prefix.finalized in
  let fc = weekly_prefix.finalized_count_at_day.(i) in
  let m_fin = Int.min (_hist_lookback_weeks - 1) fc in
  for j = fc - m_fin to fc - 1 do
    (* Finalized week [j] is [fc - j] weeks before the current partial week. *)
    let band = _age_band_of ~age:(fc - j) in
    _accumulate_hist ~hist ~i ~band ~anchor
      ~weekly_high:fin.(j).Types.Daily_price.high_price
      ~weekly_low:fin.(j).Types.Daily_price.low_price
  done;
  (* The partial (current) week is age 0 -> youngest band. *)
  let p = weekly_prefix.partial_per_day.(i) in
  _accumulate_hist ~hist ~i ~band:0 ~anchor
    ~weekly_high:p.Types.Daily_price.high_price
    ~weekly_low:p.Types.Daily_price.low_price

(* Corrupt-anchor day: every sketch cell for day [i] degrades to NaN. *)
let _nan_day t ~i =
  t.max_high_130w.(i) <- Float.nan;
  t.max_high_260w.(i) <- Float.nan;
  t.max_high_520w.(i) <- Float.nan;
  t.bars_seen.(i) <- Float.nan;
  Array.iter t.hist ~f:(fun row -> row.(i) <- Float.nan)

(* Histogram per day, anchored at the day's raw close; corrupt anchors
   degrade the whole sketch row to NaN. *)
let _fill_histograms t ~weekly_prefix ~bars_arr =
  Array.iteri bars_arr ~f:(fun i (b : Types.Daily_price.t) ->
      let anchor = b.close_price in
      if Float.is_finite anchor && Float.(anchor > 0.0) then
        _hist_for_day ~hist:t.hist ~weekly_prefix ~i ~anchor
      else _nan_day t ~i)

let _highs_of bars = Array.map bars ~f:(fun b -> b.Types.Daily_price.high_price)

let _bars_seen_column ~fc_at_day =
  Array.map fc_at_day ~f:(fun fc ->
      Float.of_int (Int.min (fc + 1) _bars_seen_cap))

let _empty_hist ~n =
  Array.init Snapshot_schema.n_hist_cells ~f:(fun _ -> Array.create ~len:n 0.0)

let compute ~(weekly_prefix : Weekly_prefix.t)
    ~(bars_arr : Types.Daily_price.t array) =
  let finalized_highs = _highs_of weekly_prefix.finalized in
  let partial_highs = _highs_of weekly_prefix.partial_per_day in
  let fc_at_day = weekly_prefix.finalized_count_at_day in
  let rolling_max horizon_weeks =
    _rolling_max_column ~finalized_highs ~fc_at_day ~partial_highs
      ~horizon_weeks
  in
  let t =
    {
      max_high_130w = rolling_max _horizon_130_weeks;
      max_high_260w = rolling_max _horizon_260_weeks;
      max_high_520w = rolling_max _horizon_520_weeks;
      bars_seen = _bars_seen_column ~fc_at_day;
      hist = _empty_hist ~n:(Array.length bars_arr);
    }
  in
  _fill_histograms t ~weekly_prefix ~bars_arr;
  t

(* Take the trailing [len] days of every sketch column, dropping the leading
   [offset] deep-history days so the result aligns to the window bars. *)
let _slice_to_window (full : t) ~offset ~len =
  let slice arr = Array.sub arr ~pos:offset ~len in
  {
    max_high_130w = slice full.max_high_130w;
    max_high_260w = slice full.max_high_260w;
    max_high_520w = slice full.max_high_520w;
    bars_seen = slice full.bars_seen;
    hist = Array.map full.hist ~f:slice;
  }

let compute_windowed ~(deep_bars : Types.Daily_price.t array)
    ~(bars_arr : Types.Daily_price.t array) =
  if Array.is_empty deep_bars then
    compute ~weekly_prefix:(Weekly_prefix.build bars_arr) ~bars_arr
  else
    let combined = Array.append deep_bars bars_arr in
    let full =
      compute ~weekly_prefix:(Weekly_prefix.build combined) ~bars_arr:combined
    in
    _slice_to_window full ~offset:(Array.length deep_bars)
      ~len:(Array.length bars_arr)
