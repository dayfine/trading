open Async
open Core

module Instruments = struct
  type t = Types.Instrument_info.t list [@@deriving sexp]
end

let _universe_path data_dir = Fpath.(v data_dir / "universe.sexp")

let load data_dir =
  let path = _universe_path data_dir in
  match File_sexp.Sexp.load (module Instruments) ~path with
  | Ok instruments -> Ok instruments
  | Error { Status.code = NotFound; _ } -> Ok []
  | Error e -> Error e

let get_deferred data_dir = return (load data_dir)

let save ~data_dir instruments =
  File_sexp.Sexp.save
    (module Instruments)
    instruments
    ~path:Fpath.(data_dir / "universe.sexp")
