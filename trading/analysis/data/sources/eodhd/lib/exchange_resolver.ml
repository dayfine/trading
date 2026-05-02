open Core

type exchange = US | LSE | TSE | ASX | HKEX | TSX [@@deriving show, eq]

type parsed_symbol = { ticker : string; exchange : exchange }
[@@deriving show, eq]

let all = [ US; LSE; TSE; ASX; HKEX; TSX ]

(* Canonical EODHD code as used in URL paths and as the symbol suffix.
   Sources: EODHD docs https://eodhd.com/financial-apis/list-supported-exchanges/.
   These are intentionally fixed strings; they are routing keys, not
   tunable parameters, so the magic-number linter exemption (string
   identifiers) applies. *)
let to_eodhd_code = function
  | US -> "US"
  | LSE -> "LSE"
  | TSE -> "TSE"
  | ASX -> "AU"
  | HKEX -> "HK"
  | TSX -> "TO"

(* ISO 4217 currency codes. Same rationale as above — fixed routing
   strings, not tunable. *)
let currency = function
  | US -> "USD"
  | LSE -> "GBP"
  | TSE -> "JPY"
  | ASX -> "AUD"
  | HKEX -> "HKD"
  | TSX -> "CAD"

let calendar = function
  | US -> "NYSE"
  | LSE -> "LSE"
  | TSE -> "TSE"
  | ASX -> "ASX"
  | HKEX -> "HKEX"
  | TSX -> "TSX"

(* Map a user-supplied suffix (case-insensitive, no leading dot) to an
   exchange. We accept both EODHD's canonical code and the looser aliases
   that the M7.0 plan document calls out (.L for London, .T for Tokyo,
   .AX for Sydney, .TSX for Toronto). *)
let _exchange_of_suffix s =
  match String.uppercase s with
  | "US" -> Some US
  | "LSE" | "L" -> Some LSE
  | "TSE" | "T" -> Some TSE
  | "AU" | "AX" -> Some ASX
  | "HK" -> Some HKEX
  | "TO" | "TSX" -> Some TSX
  | _ -> None

let _split_on_last_dot s =
  match String.rsplit2 s ~on:'.' with
  | Some (ticker, suffix) -> (ticker, Some suffix)
  | None -> (s, None)

let _resolve_explicit_suffix ~raw suffix =
  Result.of_option
    (_exchange_of_suffix suffix)
    ~error:
      (Status.invalid_argument_error
         (Printf.sprintf "Unknown exchange suffix %S in symbol %S" suffix raw))

let _resolve_suffix ~raw = function
  | None -> Ok US
  | Some suffix -> _resolve_explicit_suffix ~raw suffix

let _validate_non_empty raw =
  if String.is_empty raw then Status.error_invalid_argument "Empty symbol"
  else Ok ()

let _validate_ticker ~raw ticker =
  if String.is_empty ticker then
    Status.error_invalid_argument
      (Printf.sprintf "Empty ticker in symbol: %S" raw)
  else Ok ticker

let parse raw =
  let open Result.Let_syntax in
  let%bind () = _validate_non_empty raw in
  let ticker_raw, suffix_opt = _split_on_last_dot raw in
  let%bind ticker = _validate_ticker ~raw ticker_raw in
  let%bind exchange = _resolve_suffix ~raw suffix_opt in
  Ok { ticker; exchange }

let to_eodhd_symbol { ticker; exchange } = ticker ^ "." ^ to_eodhd_code exchange
