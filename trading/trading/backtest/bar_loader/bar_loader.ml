(** Tier-aware bar loader — see [bar_loader.mli]. *)

open Core
module Price_cache = Trading_simulation_data.Price_cache
module Summary_compute = Summary_compute

type tier = Metadata_tier | Summary_tier | Full_tier
[@@deriving show, eq, sexp]

module Metadata = struct
  type t = {
    symbol : string;
    sector : string;
    last_close : float;
    avg_vol_30d : float option;
    market_cap : float option;
  }
  [@@deriving show, eq, sexp]
end

type stats_counts = { metadata : int; summary : int; full : int }
[@@deriving show, eq, sexp]

type entry = { tier : tier; metadata : Metadata.t option }
(** Per-symbol entry. Held in a mutable hashtable keyed on symbol. The [tier]
    field reflects the highest tier this symbol has been promoted to; the
    tier-specific data fields are [Some _] at that tier and below. In 3a only
    [metadata] is ever populated. *)

type t = {
  sector_map : string String.Table.t;
  entries : (string, entry) Hashtbl.t;
  price_cache : Price_cache.t;
}

let create ~data_dir ~sector_map ~universe:_ =
  (* [universe] is accepted in the signature so 3b/3c/3f can drive tier-wide
     operations ("promote every universe symbol to Metadata on startup")
     without a signature churn. Not consumed yet in 3a. *)
  {
    sector_map;
    entries = Hashtbl.create (module String);
    price_cache = Price_cache.create ~data_dir;
  }

let tier_of t ~symbol =
  Hashtbl.find t.entries symbol |> Option.map ~f:(fun e -> e.tier)

let get_metadata t ~symbol =
  Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.metadata)

let get_summary _t ~symbol:_ = None
let get_full _t ~symbol:_ = None

(** [_tier_rank] encodes the Metadata < Summary < Full ordering used for
    idempotent promotion: a symbol at tier [>= to_] is left alone. *)
let _tier_rank = function
  | Metadata_tier -> 0
  | Summary_tier -> 1
  | Full_tier -> 2

(** [_load_metadata] reads the last bar on or before [as_of] from the shared
    [Price_cache] and joins the sector table. Market cap and average volume are
    [None] on this increment — wired when the first consumer needs them (§Risks
    #4 of the plan). *)
let _load_metadata t ~symbol ~as_of : (Metadata.t, Status.t) Result.t =
  match Price_cache.get_prices t.price_cache ~symbol ~end_date:as_of () with
  | Error err -> Error err
  | Ok [] ->
      Error
        (Status.not_found_error
           (Printf.sprintf "No bars for %s on or before %s" symbol
              (Date.to_string as_of)))
  | Ok bars ->
      let last = List.last_exn bars in
      let sector =
        Hashtbl.find t.sector_map symbol |> Option.value ~default:""
      in
      Ok
        {
          Metadata.symbol;
          sector;
          last_close = last.close_price;
          avg_vol_30d = None;
          market_cap = None;
        }

(** [_promote_one_to_metadata] is idempotent: if the symbol is already at
    Metadata or higher, it's a no-op. Otherwise it runs the metadata load and
    inserts the entry. *)
let _promote_one_to_metadata t ~symbol ~as_of : (unit, Status.t) Result.t =
  match Hashtbl.find t.entries symbol with
  | Some entry when _tier_rank entry.tier >= _tier_rank Metadata_tier -> Ok ()
  | _ -> (
      match _load_metadata t ~symbol ~as_of with
      | Error err -> Error err
      | Ok metadata ->
          Hashtbl.set t.entries ~key:symbol
            ~data:{ tier = Metadata_tier; metadata = Some metadata };
          Ok ())

let _unimplemented_tier tier : Status.t =
  {
    code = Status.Unimplemented;
    message =
      Printf.sprintf "Bar_loader.promote: tier %s not yet implemented (3a only)"
        (show_tier tier);
  }

let promote t ~symbols ~to_ ~as_of =
  match to_ with
  | Summary_tier | Full_tier -> Error (_unimplemented_tier to_)
  | Metadata_tier ->
      List.fold_until symbols ~init:()
        ~f:(fun () symbol ->
          match _promote_one_to_metadata t ~symbol ~as_of with
          | Ok () -> Continue ()
          | Error err -> Stop (Error err))
        ~finish:(fun () -> Ok ())

let demote _t ~symbols:_ ~to_:_ =
  (* 3a: no Summary / Full data exists, so there is nothing to drop. The
     signature is stable so 3b / 3c wire in real demotion without churn. *)
  ()

let stats t =
  Hashtbl.fold t.entries ~init:{ metadata = 0; summary = 0; full = 0 }
    ~f:(fun ~key:_ ~data acc ->
      match data.tier with
      | Metadata_tier -> { acc with metadata = acc.metadata + 1 }
      | Summary_tier -> { acc with summary = acc.summary + 1 }
      | Full_tier -> { acc with full = acc.full + 1 })
