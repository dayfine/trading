open Async
open Core

module Instruments = struct
  type t = Types.Instrument_info.t list [@@deriving sexp]
end

let load data_dir =
  let path = Fpath.(v data_dir / "universe.sexp") in
  match File_sexp.Sexp.load (module Instruments) ~path with
  | Ok instruments -> Ok instruments
  | Error { Status.code = NotFound; _ } -> Ok []
  | Error e -> Error e

let get_deferred data_dir = return (load data_dir)

(** Extract a string field from a JSON object by key. *)
let _json_string fields key =
  Option.bind (List.Assoc.find ~equal:String.equal fields key) ~f:(function
    | `String s -> Some s
    | _ -> None)

(** Build a minimal Instrument_info with empty metadata from a symbol string. *)
let _make_instrument symbol : Types.Instrument_info.t =
  {
    symbol;
    name = "";
    sector = "";
    industry = "";
    market_cap = 0.0;
    exchange = "";
  }

(** Convert a JSON symbol entry to an Instrument_info, or None if malformed. *)
let _entry_to_instrument = function
  | `Assoc fields ->
      Option.map (_json_string fields "symbol") ~f:_make_instrument
  | _ -> None

(** Parse the "symbols" array from the inventory JSON object. *)
let _parse_symbols_field fields =
  match List.Assoc.find ~equal:String.equal fields "symbols" with
  | Some (`List entries) -> Ok (List.filter_map entries ~f:_entry_to_instrument)
  | _ -> Status.error_invalid_argument "inventory.json: missing 'symbols' array"

(** Parse all instruments from [inventory.json] content. *)
let _parse_inventory json =
  match json with
  | `Assoc fields -> _parse_symbols_field fields
  | _ -> Status.error_invalid_argument "inventory.json: expected JSON object"

let _save_universe ~data_dir instruments =
  let universe_path = Fpath.(data_dir / "universe.sexp") in
  File_sexp.Sexp.save (module Instruments) instruments ~path:universe_path

let _read_inventory inventory_path =
  match Bos.OS.File.read inventory_path with
  | Error (`Msg msg) ->
      Status.error_not_found
        (Printf.sprintf "inventory.json not found at %s: %s"
           (Fpath.to_string inventory_path)
           msg)
  | Ok contents ->
      let json = Yojson.Basic.from_string contents in
      _parse_inventory json

let rebuild_from_data_dir ~data_dir () =
  let inventory_path = Fpath.(data_dir / "inventory.json") in
  match _read_inventory inventory_path with
  | Error _ as e -> e
  | Ok instruments -> _save_universe ~data_dir instruments
