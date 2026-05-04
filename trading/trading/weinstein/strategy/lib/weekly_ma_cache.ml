(** See [weekly_ma_cache.mli]. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

(* Local mirror of [Stage.ma_type] so the cache key can derive [hash]
   without modifying the [Stage] module's preprocess attributes. The
   conversion is total and used at every cache lookup. *)
type ma_type_tag = Tag_sma | Tag_wma | Tag_ema
[@@deriving sexp, hash, compare, equal]

let _tag_of_stage_ma_type : Stage.ma_type -> ma_type_tag = function
  | Stage.Sma -> Tag_sma
  | Stage.Wma -> Tag_wma
  | Stage.Ema -> Tag_ema

(* Cache key — symbol + ma_type tag + period. Using a [Hashtbl.S] from a
   [Hashable.S] inline so we don't have to expose the key as a public type. *)
module Key = struct
  module T = struct
    type t = { symbol : string; ma_type : ma_type_tag; period : int }
    [@@deriving sexp, hash, compare, equal]
  end

  include T
  include Hashable.Make (T)
end

type cached_ma = { values : float array; dates : Date.t array }

(* Phase F.3.b-1: backing-agnostic representation. [weekly_history_fn] is
   the single seam — both [create] (panels) and [of_snapshot_views]
   (snapshot) produce a closure of this shape that returns the symbol's
   full weekly history (closes + dates, oldest first). The cache table
   then memoises MA computations over those arrays, identically for both
   backings. *)
type t = {
  weekly_history_fn : string -> float array * Date.t array;
  table : cached_ma Key.Table.t;
}

(* Compute the MA series via the same kernels [Stage._compute_ma] uses.
   Replicating the kernel selection here keeps the cache co-located with
   {!Panel_callbacks._ma_values_of_closes}'s implementation, so any change
   to the kernel choice happens in one place per layer. *)
let _compute_ma_array ~(ma_type : Stage.ma_type) ~(period : int)
    ~(closes : float array) ~(dates : Date.t array) : float array * Date.t array
    =
  let n = Array.length closes in
  if n < period then ([||], [||])
  else
    let series =
      Array.to_list closes
      |> List.mapi ~f:(fun i v ->
          Indicator_types.{ date = dates.(i); value = v })
    in
    let result =
      match ma_type with
      | Stage.Sma -> Sma.calculate_sma series period
      | Stage.Wma -> Sma.calculate_weighted_ma series period
      | Stage.Ema -> Ema.calculate_ema series period
    in
    let len = List.length result in
    let values = Array.create ~len Float.nan in
    let date_arr = Array.create ~len dates.(0) in
    List.iteri result ~f:(fun i iv ->
        values.(i) <- iv.Indicator_types.value;
        date_arr.(i) <- iv.Indicator_types.date);
    (values, date_arr)

(* Read the symbol's full weekly history from [panels] using the largest
   available [as_of_day] (the last column of the panel's calendar). Returns
   the chronological closes + dates arrays (oldest first). Empty arrays
   when the symbol has no resident bars or the panel has zero days. *)
let _panels_weekly_history (panels : Bar_panels.t) (symbol : string) :
    float array * Date.t array =
  let n_days = Bar_panels.n_days panels in
  if n_days = 0 then ([||], [||])
  else
    let view =
      Bar_panels.weekly_view_for panels ~symbol ~n:Int.max_value
        ~as_of_day:(n_days - 1)
    in
    (view.closes, view.dates)

(* Read the symbol's full weekly history via [Snapshot_bar_views] over a
   [Snapshot_callbacks.t]. The semantics match the panel reader's: chronological
   (oldest first), close = adjusted close of the last trading day in each
   ISO-week bucket. We fetch every available weekly bucket ending on or before
   [max_as_of] via {!Snapshot_bar_views.weekly_bars_for} with
   [n = Int.max_value]; that helper walks back a fixed 10-year calendar
   window (matching {!Snapshot_bar_views.daily_bars_for}'s convention),
   wide enough for any realistic backtest horizon, and short-circuits the
   trailing truncation when [n] exceeds the available count.

   ([Snapshot_bar_views.weekly_view_for] would compute the calendar span from
   [n] via [(n * 8) + 7], which overflows for [n = Int.max_value]; the
   [weekly_bars_for] entrypoint sidesteps that overflow by using a fixed
   window.) *)
let _snapshot_weekly_history (cb : Snapshot_callbacks.t) ~(max_as_of : Date.t)
    (symbol : string) : float array * Date.t array =
  let weekly =
    Snapshot_bar_views.weekly_bars_for cb ~symbol ~n:Int.max_value
      ~as_of:max_as_of
  in
  if List.is_empty weekly then ([||], [||])
  else
    let closes =
      Array.of_list
        (List.map weekly ~f:(fun b -> b.Types.Daily_price.adjusted_close))
    in
    let dates =
      Array.of_list (List.map weekly ~f:(fun b -> b.Types.Daily_price.date))
    in
    (closes, dates)

let create panels =
  {
    weekly_history_fn = _panels_weekly_history panels;
    table = Key.Table.create ();
  }

let of_snapshot_views cb ~max_as_of =
  {
    weekly_history_fn = _snapshot_weekly_history cb ~max_as_of;
    table = Key.Table.create ();
  }

let _build_entry weekly_history_fn (ma_type : Stage.ma_type) (key : Key.t) :
    cached_ma =
  let closes, dates = weekly_history_fn key.symbol in
  let values, ma_dates =
    _compute_ma_array ~ma_type ~period:key.period ~closes ~dates
  in
  { values; dates = ma_dates }

let ma_values_for t ~symbol ~(ma_type : Stage.ma_type) ~period =
  let tag = _tag_of_stage_ma_type ma_type in
  let key : Key.t = { symbol; ma_type = tag; period } in
  let entry =
    Hashtbl.find_or_add t.table key ~default:(fun () ->
        _build_entry t.weekly_history_fn ma_type key)
  in
  (entry.values, entry.dates)

(* Linear scan from the end. The strategy's hot path looks up the view's
   newest date, which is almost always at the tail of the cached dates
   array (the cache stores up to [n_days - 1]; views are positioned at
   the current Friday, monotonically advancing). *)
let locate_date (dates : Date.t array) (target : Date.t) : int option =
  let n = Array.length dates in
  let rec walk i =
    if i < 0 then None
    else if Date.equal dates.(i) target then Some i
    else walk (i - 1)
  in
  walk (n - 1)
