open Core

module Config = struct
  let _default_min_ratio = 0.4
  let _default_max_ratio = 2.5

  type t = {
    enabled : bool; [@sexp.default false]
    min_ratio : float; [@sexp.default _default_min_ratio]
    max_ratio : float; [@sexp.default _default_max_ratio]
    skip_split_days : bool; [@sexp.default true]
  }
  [@@deriving sexp, equal]

  let default =
    {
      enabled = false;
      min_ratio = _default_min_ratio;
      max_ratio = _default_max_ratio;
      skip_split_days = true;
    }
end

type series = { symbol : string; bars : Types.Daily_price.t array }

type finding = {
  symbol : string;
  date : Date.t;
  prev_adj_close : float;
  adj_close : float;
  ratio : float;
  prev_volume : int;
  volume : int;
}
[@@deriving sexp_of, equal]

type report = { config : Config.t; findings : finding list }
[@@deriving sexp_of]

(* A non-positive prior close has no meaningful ratio. That is a data defect of
   its own kind, not the ticker-reuse one this module names, so it is passed
   over rather than reported here. *)
let _ratio ~(prev : Types.Daily_price.t) ~(curr : Types.Daily_price.t) =
  if Float.( <= ) prev.adjusted_close 0.0 then None
  else Some (curr.adjusted_close /. prev.adjusted_close)

let _outside (c : Config.t) ratio =
  Float.( < ) ratio c.min_ratio || Float.( > ) ratio c.max_ratio

(* A correctly adjusted split never reaches here (its adjusted ratio is ~1.0).
   This only excuses a feed whose ADJUSTED series carries the corporate action
   un-back-rolled, where the raw-vs-adjusted divergence still snaps to a small
   rational and so is recoverable as a split rather than a splice. *)
let _explained_by_split (c : Config.t) ~prev ~curr =
  c.skip_split_days
  && Option.is_some (Types.Split_detector.detect_split ~prev ~curr ())

let _finding symbol ~(prev : Types.Daily_price.t) ~(curr : Types.Daily_price.t)
    ratio =
  {
    symbol;
    date = curr.date;
    prev_adj_close = prev.adjusted_close;
    adj_close = curr.adjusted_close;
    ratio;
    prev_volume = prev.volume;
    volume = curr.volume;
  }

let _scan_pair (c : Config.t) symbol ~prev ~curr =
  match _ratio ~prev ~curr with
  | Some ratio when _outside c ratio && not (_explained_by_split c ~prev ~curr)
    ->
      Some (_finding symbol ~prev ~curr ratio)
  | _ -> None

let _scan_series (c : Config.t) (s : series) =
  Array.foldi s.bars ~init:[] ~f:(fun i acc curr ->
      if i = 0 then acc
      else
        match _scan_pair c s.symbol ~prev:s.bars.(i - 1) ~curr with
        | Some f -> f :: acc
        | None -> acc)
  |> List.rev

let _by_symbol_then_date a b =
  match String.compare a.symbol b.symbol with
  | 0 -> Date.compare a.date b.date
  | n -> n

let detect (config : Config.t) series =
  if not config.enabled then { config; findings = [] }
  else
    let findings = List.concat_map series ~f:(_scan_series config) in
    { config; findings = List.sort findings ~compare:_by_symbol_then_date }

(* Same columns + precision as the committed #2646 scan CSV, so a build's
   sidecar diffs against it directly. *)
let _csv_header =
  "symbol,date,prev_adj_close,adj_close,ratio,prev_volume,volume"

let _csv_row f =
  sprintf "%s,%s,%.4f,%.4f,%.3f,%d,%d" f.symbol (Date.to_string f.date)
    f.prev_adj_close f.adj_close f.ratio f.prev_volume f.volume

let to_csv report =
  String.concat ~sep:"\n" (_csv_header :: List.map report.findings ~f:_csv_row)
  ^ "\n"

let summary report =
  let symbols =
    List.map report.findings ~f:(fun f -> f.symbol)
    |> List.dedup_and_sort ~compare:String.compare
  in
  sprintf "splice detector: %d splice(s) across %d symbol(s)"
    (List.length report.findings)
    (List.length symbols)
