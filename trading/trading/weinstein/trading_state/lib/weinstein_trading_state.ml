open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Trade log entry                                                      *)
(* ------------------------------------------------------------------ *)

type trade_log_entry = {
  date : Date.t;
  ticker : string;
  action : [ `Buy | `Sell | `Short | `Cover ];
  shares : int;
  price : float;
  grade : grade option;
  reason : string;
}
[@@deriving show, eq]

(* ------------------------------------------------------------------ *)
(* State                                                                *)
(* ------------------------------------------------------------------ *)

type t = {
  portfolio : Trading_portfolio.Portfolio.t;
  stop_states : (string * Weinstein_stops.stop_state) list;
  prior_stages : (string * stage) list;
  trade_log : trade_log_entry list;
  last_scan_date : Date.t option;
}
[@@deriving show]

let empty ~initial_cash =
  {
    portfolio = Trading_portfolio.Portfolio.create ~initial_cash ();
    stop_states = [];
    prior_stages = [];
    trade_log = [];
    last_scan_date = None;
  }

(* ------------------------------------------------------------------ *)
(* State update helpers                                                 *)
(* ------------------------------------------------------------------ *)

let add_log_entry state entry =
  { state with trade_log = state.trade_log @ [ entry ] }

let set_stop_state state ~ticker stop_state =
  let stops =
    List.filter state.stop_states ~f:(fun (t, _) -> not String.(t = ticker))
  in
  { state with stop_states = stops @ [ (ticker, stop_state) ] }

let get_stop_state state ~ticker =
  List.Assoc.find state.stop_states ticker ~equal:String.equal

let remove_stop_state state ~ticker =
  let stops =
    List.filter state.stop_states ~f:(fun (t, _) -> not String.(t = ticker))
  in
  { state with stop_states = stops }

let set_prior_stage state ~ticker stage =
  let stages =
    List.filter state.prior_stages ~f:(fun (t, _) -> not String.(t = ticker))
  in
  { state with prior_stages = stages @ [ (ticker, stage) ] }

let get_prior_stage state ~ticker =
  List.Assoc.find state.prior_stages ticker ~equal:String.equal

(* ------------------------------------------------------------------ *)
(* JSON serialisation helpers                                           *)
(* ------------------------------------------------------------------ *)

let _action_to_string = function
  | `Buy -> "buy"
  | `Sell -> "sell"
  | `Short -> "short"
  | `Cover -> "cover"

let _action_of_string = function
  | "buy" -> `Buy
  | "sell" -> `Sell
  | "short" -> `Short
  | "cover" -> `Cover
  | other -> failwith (Printf.sprintf "Unknown trade action: %s" other)

let _grade_to_string g = show_grade g

let _grade_of_string_opt = function
  | "A_plus" -> Some A_plus
  | "A" -> Some A
  | "B" -> Some B
  | "C" -> Some C
  | "D" -> Some D
  | "F" -> Some F
  | _ -> None

let _entry_to_json (e : trade_log_entry) : Yojson.Basic.t =
  `Assoc
    [
      ("date", `String (Date.to_string e.date));
      ("ticker", `String e.ticker);
      ("action", `String (_action_to_string e.action));
      ("shares", `Int e.shares);
      ("price", `Float e.price);
      ( "grade",
        match e.grade with
        | None -> `Null
        | Some g -> `String (_grade_to_string g) );
      ("reason", `String e.reason);
    ]

let _entry_of_json (j : Yojson.Basic.t) : trade_log_entry =
  let open Yojson.Basic.Util in
  {
    date = Date.of_string (j |> member "date" |> to_string);
    ticker = j |> member "ticker" |> to_string;
    action = _action_of_string (j |> member "action" |> to_string);
    shares = j |> member "shares" |> to_int;
    price = j |> member "price" |> to_float;
    grade =
      (match j |> member "grade" with
      | `Null -> None
      | `String s -> _grade_of_string_opt s
      | _ -> None);
    reason = j |> member "reason" |> to_string;
  }

(** Serialise stop_state as its show-derived string. Deserialisation is
    intentionally skipped (see note below). *)
let _stop_state_to_json (s : Weinstein_stops.stop_state) : Yojson.Basic.t =
  `String (Weinstein_stops.show_stop_state s)

(** Deserialise a stop_state. Currently returns [None] for all inputs — stop
    states are rebuilt from bar history on the next scan rather than
    round-tripped through JSON. The serialised string is retained in the file
    for human inspection. *)
let _stop_state_of_json_string (_s : string) : Weinstein_stops.stop_state option
    =
  None

let _stage_to_json (s : stage) : Yojson.Basic.t = `String (show_stage s)

let _stage_of_json_string (s : string) : stage option =
  (* ppx_deriving.show format (no spaces around braces, no trailing semicolon):
     "Weinstein_types.StageN {field = value; ...}" *)
  try
    Scanf.sscanf s "Weinstein_types.Stage1 {weeks_in_base = %d}" (fun n ->
        Some (Stage1 { weeks_in_base = n }))
  with _ -> (
    try
      Scanf.sscanf s "Weinstein_types.Stage2 {weeks_advancing = %d; late = %B}"
        (fun w l -> Some (Stage2 { weeks_advancing = w; late = l }))
    with _ -> (
      try
        Scanf.sscanf s "Weinstein_types.Stage3 {weeks_topping = %d}" (fun n ->
            Some (Stage3 { weeks_topping = n }))
      with _ -> (
        try
          Scanf.sscanf s "Weinstein_types.Stage4 {weeks_declining = %d}"
            (fun n -> Some (Stage4 { weeks_declining = n }))
        with _ -> None)))

(** Serialise portfolio as cash + list of (symbol, total_qty,
    avg_cost_per_share). We compute total_qty and avg_cost from the lot
    structure. *)
let _portfolio_to_json (p : Trading_portfolio.Portfolio.t) : Yojson.Basic.t =
  let positions =
    List.filter_map p.positions ~f:(fun pos ->
        let symbol = pos.Trading_portfolio.Types.symbol in
        let total_qty =
          List.sum (module Float) pos.lots ~f:(fun lot -> lot.quantity)
        in
        let total_cost =
          List.sum (module Float) pos.lots ~f:(fun lot -> lot.cost_basis)
        in
        if Float.(total_qty = 0.0) then None
        else
          let avg_cost =
            if Float.(Float.abs total_qty > 0.0) then
              total_cost /. Float.abs total_qty
            else 0.0
          in
          Some
            ( symbol,
              `Assoc
                [
                  ("quantity", `Float total_qty); ("avg_cost", `Float avg_cost);
                ] ))
  in
  `Assoc [ ("cash", `Float p.current_cash); ("positions", `Assoc positions) ]

let _portfolio_of_json (j : Yojson.Basic.t) : Trading_portfolio.Portfolio.t =
  let open Yojson.Basic.Util in
  let cash = j |> member "cash" |> to_float in
  let pos_json = j |> member "positions" |> to_assoc in
  let p0 = Trading_portfolio.Portfolio.create ~initial_cash:cash () in
  (* Replay each position as a synthetic buy trade *)
  List.fold pos_json ~init:p0 ~f:(fun p (symbol, v) ->
      let qty = v |> member "quantity" |> to_float in
      let avg_cost = v |> member "avg_cost" |> to_float in
      if Float.(qty = 0.0) then p
      else
        let trade =
          {
            Trading_base.Types.id = symbol ^ "-restore";
            order_id = symbol ^ "-order";
            symbol;
            side = Trading_base.Types.Buy;
            quantity = Float.abs qty;
            price = avg_cost;
            commission = 0.0;
            timestamp = Time_ns_unix.now ();
          }
        in
        match Trading_portfolio.Portfolio.apply_trades p [ trade ] with
        | Ok p' -> p'
        | Error _ -> p)

(* ------------------------------------------------------------------ *)
(* Top-level JSON serialisation                                         *)
(* ------------------------------------------------------------------ *)

let _to_json (state : t) : Yojson.Basic.t =
  let stop_states_json =
    List.map state.stop_states ~f:(fun (ticker, ss) ->
        `Assoc [ ("ticker", `String ticker); ("state", _stop_state_to_json ss) ])
  in
  let prior_stages_json =
    List.map state.prior_stages ~f:(fun (ticker, stage) ->
        `Assoc [ ("ticker", `String ticker); ("stage", _stage_to_json stage) ])
  in
  `Assoc
    [
      ("portfolio", _portfolio_to_json state.portfolio);
      ("stop_states", `List stop_states_json);
      ("prior_stages", `List prior_stages_json);
      ("trade_log", `List (List.map state.trade_log ~f:_entry_to_json));
      ( "last_scan_date",
        match state.last_scan_date with
        | None -> `Null
        | Some d -> `String (Date.to_string d) );
    ]

let _of_json (j : Yojson.Basic.t) : t =
  let open Yojson.Basic.Util in
  let portfolio = _portfolio_of_json (j |> member "portfolio") in
  let stop_states =
    j |> member "stop_states" |> to_list
    |> List.filter_map ~f:(fun item ->
        let ticker = item |> member "ticker" |> to_string in
        let state_str = item |> member "state" |> to_string in
        match _stop_state_of_json_string state_str with
        | None -> None
        | Some ss -> Some (ticker, ss))
  in
  let prior_stages =
    j |> member "prior_stages" |> to_list
    |> List.filter_map ~f:(fun item ->
        let ticker = item |> member "ticker" |> to_string in
        let stage_str = item |> member "stage" |> to_string in
        match _stage_of_json_string stage_str with
        | None -> None
        | Some s -> Some (ticker, s))
  in
  let trade_log =
    j |> member "trade_log" |> to_list |> List.map ~f:_entry_of_json
  in
  let last_scan_date =
    match j |> member "last_scan_date" with
    | `Null -> None
    | `String s -> ( try Some (Date.of_string s) with _ -> None)
    | _ -> None
  in
  { portfolio; stop_states; prior_stages; trade_log; last_scan_date }

(* ------------------------------------------------------------------ *)
(* Persistence                                                          *)
(* ------------------------------------------------------------------ *)

let save state ~path =
  try
    let json = _to_json state in
    let tmp = path ^ ".tmp" in
    let content = Yojson.Basic.pretty_to_string json in
    Out_channel.write_all tmp ~data:content;
    Stdlib.Sys.rename tmp path;
    Ok ()
  with exn ->
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "Failed to save state to %s: %s" path
            (Exn.to_string exn)))

let load ~path =
  try
    let content = In_channel.read_all path in
    let json = Yojson.Basic.from_string content in
    Ok (_of_json json)
  with exn ->
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "Failed to load state from %s: %s" path
            (Exn.to_string exn)))
