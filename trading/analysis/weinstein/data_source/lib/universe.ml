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
