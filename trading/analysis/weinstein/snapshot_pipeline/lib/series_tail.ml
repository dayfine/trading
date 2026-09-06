open Core

module Config = struct
  type stub = {
    truncate : bool;
    ratio : float;
    max_bars : int;
    max_price : float;
    misscale_close : float;
  }

  type stray = { drop : bool; gap_days : int; max_bars : int }
  type t = { stub : stub; stray : stray }

  let default_stub =
    {
      truncate = true;
      ratio = 0.05;
      max_bars = 60;
      max_price = 1.0;
      misscale_close = 1000.0;
    }

  let default_stray = { drop = true; gap_days = 365; max_bars = 5 }
  let default = { stub = default_stub; stray = default_stray }
end

module Exceptions = struct
  type t = Set.M(String).t
  type file = { keep_tail : string list } [@@deriving sexp]

  let empty = Set.empty (module String)
  let of_symbols syms = Set.of_list (module String) syms
  let of_file (f : file) = of_symbols f.keep_tail
  let mem t ~symbol = Set.mem t symbol
end

module Class = struct
  type t =
    | Stub_tail
    | Prefix_misscale
    | Long_low_tail
    | High_price_tail
    | Stray_bar
  [@@deriving sexp_of, compare, equal]

  let to_string = function
    | Stub_tail -> "stub_tail"
    | Prefix_misscale -> "prefix_misscale"
    | Long_low_tail -> "long_low_tail"
    | High_price_tail -> "high_price_tail"
    | Stray_bar -> "stray_bar"
end

module Action = struct
  type t = Truncated | Stray_dropped | Kept | Kept_by_exception
  [@@deriving sexp_of, compare, equal]

  let to_string = function
    | Truncated -> "truncated"
    | Stray_dropped -> "stray_dropped"
    | Kept -> "kept"
    | Kept_by_exception -> "kept_by_exception"
end

type finding = {
  symbol : string;
  klass : Class.t;
  cut_after : Date.t;
  last_real_close : float;
  n_stub : int;
  first_stub_date : Date.t;
  first_stub_close : float;
  last_date : Date.t;
  last_close : float;
  action : Action.t;
}
[@@deriving sexp_of, compare, equal]

(* A NaN close is treated as unboundedly high so a stub run never spans one:
   the run test asks whether every close from [k] on is BELOW the reference. *)
let _close (b : Types.Daily_price.t) =
  if Float.is_nan b.close_price then Float.infinity else b.close_price

(* Running maximum of [closes.(i .. n-1)], so "is every bar from k to the end a
   stub" is O(1) per candidate and the whole scan is O(n). *)
let _suffix_maxima (closes : float array) : float array =
  let n = Array.length closes in
  let maxima = Array.create ~len:n Float.neg_infinity in
  for i = n - 1 downto 0 do
    let rest = if i = n - 1 then Float.neg_infinity else maxima.(i + 1) in
    maxima.(i) <- Float.max closes.(i) rest
  done;
  maxima

(* Smallest [k >= 1] such that every close in [k .. n-1] is below [ratio] of
   [closes.(k-1)]. Smallest = longest run; the test itself rules out any run
   whose interior recovers, so a mid-series collapse that recovers never
   matches. Same shape as the runtime guard, deliberately: only the gates
   around it (length, price, mis-scale) differ. *)
let _stub_run_start ~ratio (closes : float array) : int option =
  let n = Array.length closes in
  let maxima = _suffix_maxima closes in
  let rec scan k =
    if k >= n then None
    else if
      Float.( > ) closes.(k - 1) 0.0
      && Float.( < ) maxima.(k) (ratio *. closes.(k - 1))
    then Some k
    else scan (k + 1)
  in
  if n < 2 || Float.( <= ) ratio 0.0 then None else scan 1

let _classify_run (cfg : Config.stub) ~last_real_close ~n_stub ~first_stub_close
    =
  if Float.( >= ) last_real_close cfg.misscale_close then Class.Prefix_misscale
  else if n_stub > cfg.max_bars then Class.Long_low_tail
  else if Float.( >= ) first_stub_close cfg.max_price then Class.High_price_tail
  else Class.Stub_tail

(* Reported action: an ineligible class or a disabled edit is [Kept]; an
   eligible run on an excepted symbol is [Kept_by_exception]. *)
let _action ~eligible ~enabled ~excepted ~edited =
  if (not eligible) || not enabled then Action.Kept
  else if excepted then Action.Kept_by_exception
  else edited

let _finding ~symbol ~klass ~action (bars : Types.Daily_price.t array) ~start =
  let prev = bars.(start - 1) in
  let first = bars.(start) in
  let last = bars.(Array.length bars - 1) in
  {
    symbol;
    klass;
    cut_after = prev.date;
    last_real_close = prev.close_price;
    n_stub = Array.length bars - start;
    first_stub_date = first.date;
    first_stub_close = first.close_price;
    last_date = last.date;
    last_close = last.close_price;
    action;
  }

let _keep_prefix (bars : Types.Daily_price.t array) ~start =
  Array.sub bars ~pos:0 ~len:start |> Array.to_list

(* Terminal run of closes below [ratio] of the close preceding it. Detected
   whatever the gates say (the report lists every one); truncated only when the
   class is [Stub_tail], the edit is enabled, and the symbol is not excepted. *)
let _apply_stub (cfg : Config.stub) ~excepted ~symbol
    (bars : Types.Daily_price.t list) =
  let arr = Array.of_list bars in
  match _stub_run_start ~ratio:cfg.ratio (Array.map arr ~f:_close) with
  | None -> (bars, None)
  | Some start ->
      let klass =
        _classify_run cfg ~last_real_close:arr.(start - 1).close_price
          ~n_stub:(Array.length arr - start)
          ~first_stub_close:arr.(start).close_price
      in
      let action =
        _action
          ~eligible:(Class.equal klass Stub_tail)
          ~enabled:cfg.truncate ~excepted ~edited:Action.Truncated
      in
      let kept =
        match action with
        | Action.Truncated -> _keep_prefix arr ~start
        | _ -> bars
      in
      (kept, Some (_finding ~symbol ~klass ~action arr ~start))

(* First index of a droppable stray suffix: the earliest bar within the last
   [max_bars] whose gap to its predecessor is at least [gap_days]. Earliest =
   the largest suffix the cap allows. *)
let _stray_start (cfg : Config.stray) (arr : Types.Daily_price.t array) =
  let n = Array.length arr in
  let rec scan k =
    if k >= n then None
    else if Date.diff arr.(k).date arr.(k - 1).date >= cfg.gap_days then Some k
    else scan (k + 1)
  in
  if n < 2 || cfg.gap_days <= 0 || cfg.max_bars <= 0 then None
  else scan (Int.max 1 (n - cfg.max_bars))

let _apply_stray (cfg : Config.stray) ~excepted ~symbol
    (bars : Types.Daily_price.t list) =
  let arr = Array.of_list bars in
  match _stray_start cfg arr with
  | None -> (bars, None)
  | Some start ->
      let action =
        _action ~eligible:true ~enabled:cfg.drop ~excepted
          ~edited:Action.Stray_dropped
      in
      let kept =
        match action with
        | Action.Stray_dropped -> _keep_prefix arr ~start
        | _ -> bars
      in
      (kept, Some (_finding ~symbol ~klass:Class.Stray_bar ~action arr ~start))

let apply (config : Config.t) ~exceptions ~symbol bars =
  let excepted = Exceptions.mem exceptions ~symbol in
  let after_stub, stub_finding =
    _apply_stub config.stub ~excepted ~symbol bars
  in
  let after_stray, stray_finding =
    _apply_stray config.stray ~excepted ~symbol after_stub
  in
  (after_stray, List.filter_opt [ stub_finding; stray_finding ])

let classify config ~symbol bars =
  snd (apply config ~exceptions:Exceptions.empty ~symbol bars)

let csv_header =
  "symbol,class,cut_after,last_real_close,n_stub,first_stub_date,first_stub_close,last_date,last_close,action"

let _fmt_price v = Printf.sprintf "%.4f" v

let _csv_row f =
  String.concat ~sep:","
    [
      f.symbol;
      Class.to_string f.klass;
      Date.to_string f.cut_after;
      _fmt_price f.last_real_close;
      Int.to_string f.n_stub;
      Date.to_string f.first_stub_date;
      _fmt_price f.first_stub_close;
      Date.to_string f.last_date;
      _fmt_price f.last_close;
      Action.to_string f.action;
    ]

let to_csv findings =
  String.concat ~sep:"\n" (csv_header :: List.map findings ~f:_csv_row) ^ "\n"

let _count findings ~action =
  List.count findings ~f:(fun f -> Action.equal f.action action)

let summary findings =
  Printf.sprintf
    "series_tail: %d findings (%d truncated, %d stray_dropped, %d kept, %d \
     kept_by_exception)"
    (List.length findings)
    (_count findings ~action:Action.Truncated)
    (_count findings ~action:Action.Stray_dropped)
    (_count findings ~action:Action.Kept)
    (_count findings ~action:Action.Kept_by_exception)
