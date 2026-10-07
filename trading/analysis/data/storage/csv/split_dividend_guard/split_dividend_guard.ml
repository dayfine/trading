open Core

type config = { window_bars : int; factor_tolerance : float }
[@@deriving show, eq]

(* Two bars either side covers a vendor ex-date recorded a day or two off the
   bar where the adjusted series steps. *)
let _default_window_bars = 2

(* Ten times the detector's 1e-3 snap tolerance. *)
let _default_factor_tolerance = 0.01

let default_config =
  {
    window_bars = _default_window_bars;
    factor_tolerance = _default_factor_tolerance;
  }

let implied_factor ~prev_close ~amount =
  if Float.(amount > 0.0 && amount < prev_close) then
    Some (prev_close /. (prev_close -. amount))
  else None

let _within_bars ~window_bars ~date other =
  Int.abs (Date.diff_weekdays other date) <= window_bars

let _amount (div : Corporate_actions.dividend) =
  Option.value div.unadjusted_amount ~default:div.adjusted_amount

let _matches_factor ~config ~prev_close ~factor div =
  match implied_factor ~prev_close ~amount:(_amount div) with
  | None -> false
  | Some implied -> Float.(abs (implied -. factor) <= config.factor_tolerance)

let is_dividend_not_split ?(config = default_config) ~date ~prev_close ~factor
    ~dividends ~splits () =
  let near = _within_bars ~window_bars:config.window_bars ~date in
  let vendor_split =
    List.exists splits ~f:(fun (s : Corporate_actions.split) -> near s.date)
  in
  (not vendor_split)
  && List.exists dividends ~f:(fun (d : Corporate_actions.dividend) ->
      near d.ex_date && _matches_factor ~config ~prev_close ~factor d)

type loader = string -> Corporate_actions.dividend list Status.status_or
type split_loader = string -> Corporate_actions.split list Status.status_or
type counts = { rejected : int; no_files : int } [@@deriving show, eq]

type t = {
  config : config;
  load_dividends : loader;
  load_splits : split_loader;
  cache :
    (Corporate_actions.dividend list * Corporate_actions.split list) option
    String.Table.t;
      (* [None] = a file was missing or unreadable for this symbol. *)
  rejected_events : String.Hash_set.t;
}

let create ?(config = default_config) ~load_dividends ~load_splits () =
  {
    config;
    load_dividends;
    load_splits;
    cache = String.Table.create ();
    rejected_events = String.Hash_set.create ();
  }

let of_data_dir ?config ~data_dir () =
  create ?config
    ~load_dividends:(Corporate_actions.read_dividends ~data_dir)
    ~load_splits:(Corporate_actions.read_splits ~data_dir)
    ()

let _load t symbol =
  match (t.load_dividends symbol, t.load_splits symbol) with
  | Ok dividends, Ok splits -> Some (dividends, splits)
  | Error _, _ | _, Error _ -> None

let _actions_for t symbol =
  Hashtbl.find_or_add t.cache symbol ~default:(fun () -> _load t symbol)

let _reject t ~symbol ~date =
  Hash_set.add t.rejected_events (symbol ^ "@" ^ Date.to_string date);
  None

let filter t ~symbol ~date ~prev_close detected =
  match detected with
  | None -> None
  | Some factor -> (
      match _actions_for t symbol with
      | None -> detected
      | Some (dividends, splits) ->
          if
            is_dividend_not_split ~config:t.config ~date ~prev_close ~factor
              ~dividends ~splits ()
          then _reject t ~symbol ~date
          else detected)

let counts t =
  {
    rejected = Hash_set.length t.rejected_events;
    no_files = Hashtbl.count t.cache ~f:Option.is_none;
  }
