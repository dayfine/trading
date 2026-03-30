open Core
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Trade log entry                                                      *)
(* ------------------------------------------------------------------ *)

type trade_action = [ `Buy | `Sell | `Short | `Cover ]
[@@deriving show, eq, sexp]

type trade_log_entry = {
  date : Date.t;
  ticker : string;
  action : trade_action;
  shares : int;
  price : float;
  grade : grade option;
  reason : string;
}
[@@deriving show, eq, sexp]

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
[@@deriving show, sexp]

(* Alias used to expose t via Base.Sexpable.S for File_sexp *)
type state = t

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
(* Persistence                                                          *)
(* ------------------------------------------------------------------ *)

module S = struct
  type t = state

  let sexp_of_t = sexp_of_t
  let t_of_sexp = t_of_sexp
end

let save state ~path = File_sexp.Sexp.save (module S) state ~path
let load ~path = File_sexp.Sexp.load (module S) ~path
