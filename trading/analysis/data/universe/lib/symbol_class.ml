open Core

type t = Warrant | Unit | Non_usd_listing [@@deriving sexp, eq, show]

let curated_non_usd = [ "HSBA"; "SBER"; "CELSIA"; "LDG"; "CTRA_old" ]

(* Dash-separated tokens after the first: "C-WS-A" -> ["WS"; "A"]. The first
   token is the root ticker, so a bare ticker named "UN" or "WS" is not a
   suffix. *)
let _suffix_tokens upper =
  match String.split upper ~on:'-' with [] -> [] | _ :: rest -> rest

let _has_token upper token =
  List.mem (_suffix_tokens upper) token ~equal:String.equal

let classify ?(extra_non_usd = []) symbol =
  let upper = String.uppercase symbol in
  if _has_token upper "WS" then Some Warrant
  else if _has_token upper "UN" then Some Unit
  else if
    List.exists (curated_non_usd @ extra_non_usd) ~f:(fun s ->
        String.equal (String.uppercase s) upper)
  then Some Non_usd_listing
  else None
