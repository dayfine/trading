open Core

let min_adjusted_amount = 0.01

(* Prices are quoted in cents above $1, FINRA's minimum quotation variation. *)
let _cents_per_dollar = 100.0

(* Absorbs float error so 67.46 - 23.00 (44.459999...) floors to 44.46. *)
let _round_epsilon = 1e-6

let _round_down_to_cent x =
  Float.round_down ((x *. _cents_per_dollar) +. _round_epsilon)
  /. _cents_per_dollar

let reduce_stop_level ~stop_level ~amount =
  if Float.(amount < min_adjusted_amount) then stop_level
  else Float.max 0.0 (_round_down_to_cent (stop_level -. amount))

let _in_window ~after ~through (d : Corporate_actions.dividend) =
  Date.(d.ex_date > after && d.ex_date <= through)

let _window_dividends ~dividends ~after ~through =
  List.filter dividends ~f:(_in_window ~after ~through)
  |> List.sort ~compare:(fun (a : Corporate_actions.dividend) b ->
      Date.compare a.ex_date b.ex_date)

let reduce_for_dividends ~dividends ~after ~through stop_level =
  _window_dividends ~dividends ~after ~through
  |> List.fold ~init:stop_level
       ~f:(fun level (d : Corporate_actions.dividend) ->
         match d.unadjusted_amount with
         | None -> level
         | Some amount -> reduce_stop_level ~stop_level:level ~amount)

type loader = string -> Corporate_actions.dividend list Status.status_or

type counts = { reduced : int; skipped_no_amount : int; no_files : int }
[@@deriving show, eq]

type t = {
  load : loader;
  cache : Corporate_actions.dividend list option String.Table.t;
      (* [None] = the file was missing or unreadable for this symbol. *)
  reduced_events : String.Hash_set.t;
  skipped_events : String.Hash_set.t;
}

let create ~load =
  {
    load;
    cache = String.Table.create ();
    reduced_events = String.Hash_set.create ();
    skipped_events = String.Hash_set.create ();
  }

let of_data_dir ~data_dir =
  create ~load:(Corporate_actions.read_dividends ~data_dir)

let _dividends_for t symbol =
  Hashtbl.find_or_add t.cache symbol ~default:(fun () ->
      Result.ok (t.load symbol))

let _event_key ~symbol (d : Corporate_actions.dividend) =
  symbol ^ "@" ^ Date.to_string d.ex_date

let _record t ~symbol (d : Corporate_actions.dividend) =
  match d.unadjusted_amount with
  | None -> Hash_set.add t.skipped_events (_event_key ~symbol d)
  | Some amount when Float.(amount >= min_adjusted_amount) ->
      Hash_set.add t.reduced_events (_event_key ~symbol d)
  | Some _ -> ()

let adjust t ~symbol ~after ~through stop_level =
  match _dividends_for t symbol with
  | None -> stop_level
  | Some dividends ->
      List.iter
        (_window_dividends ~dividends ~after ~through)
        ~f:(_record t ~symbol);
      reduce_for_dividends ~dividends ~after ~through stop_level

let counts t =
  {
    reduced = Hash_set.length t.reduced_events;
    skipped_no_amount = Hash_set.length t.skipped_events;
    no_files = Hashtbl.count t.cache ~f:Option.is_none;
  }
