open Core

type category = Bond_cef | Equity_cef | Bullion_trust | Spac
[@@deriving sexp, eq, show]

type entry = { symbol : string; category : category }
[@@deriving sexp, eq, show]

(* Internal representation: uppercased-symbol -> category. Hashtbl gives O(1)
   membership; the public sexp form is the deterministic sorted [entry] list
   (see [sexp_of_t]) so a [t] serialises stably as a config field. *)
type t = (string, category) Hashtbl.t

let empty : t = Hashtbl.create (module String)

let _add tbl { symbol; category } =
  Hashtbl.set tbl ~key:(String.uppercase symbol) ~data:category

let of_entries entries : t =
  let tbl = Hashtbl.create (module String) in
  List.iter entries ~f:(_add tbl);
  tbl

let find t ~symbol = Hashtbl.find t (String.uppercase symbol)
let is_blocked t ~symbol = Option.is_some (find t ~symbol)
let size t = Hashtbl.length t

let entries t : entry list =
  Hashtbl.to_alist t
  |> List.map ~f:(fun (symbol, category) -> { symbol; category })
  |> List.sort ~compare:(fun a b -> String.compare a.symbol b.symbol)

let union a b : t =
  let tbl = Hashtbl.copy a in
  Hashtbl.iteri b ~f:(fun ~key ~data -> Hashtbl.set tbl ~key ~data);
  tbl

let sexp_of_t t = [%sexp_of: entry list] (entries t)
let t_of_sexp sexp = of_entries ([%of_sexp: entry list] sexp)

let load ~path : t Status.status_or =
  try Ok (t_of_sexp (Sexp.load_sexp path)) with
  | Sys_error msg | Failure msg ->
      Status.error_internal ("asset_type_blocklist: load: " ^ msg)
  | Sexp.Of_sexp_error (exn, _) ->
      Status.error_internal
        ("asset_type_blocklist: decode: " ^ Exn.to_string exn)

(* ------------------------------------------------------------------ *)
(* Curated seed — the checked-in source of record.                     *)
(*                                                                     *)
(* Every entry is a real instrument EODHD mislabels as "Common Stock". *)
(* Extend this list (grouped by category) as new leaks are found. SPAC *)
(* shells are intentionally omitted: their tickers are ephemeral (they *)
(* de-SPAC or liquidate), so hand-curating them goes stale fast — the  *)
(* [Spac] category is reserved for a heuristic / fundamentals feed via *)
(* [of_entries] (see the .mli). *)
(* ------------------------------------------------------------------ *)

let _bond_cefs =
  [ "FTHY"; "PDI"; "PTY"; "PCN"; "PML"; "PFN"; "PFL"; "RCS"; "DSL"; "NAD" ]

let _equity_cefs = [ "ADX"; "GAB"; "CET"; "USA"; "STK"; "ETV"; "ETY"; "EOS" ]
let _bullion_trusts = [ "PHYS"; "PSLV"; "CEF"; "SPPP" ]

let _seed category symbols =
  List.map symbols ~f:(fun symbol -> { symbol; category })

let curated : t =
  of_entries
    (List.concat
       [
         _seed Bond_cef _bond_cefs;
         _seed Equity_cef _equity_cefs;
         _seed Bullion_trust _bullion_trusts;
       ])
