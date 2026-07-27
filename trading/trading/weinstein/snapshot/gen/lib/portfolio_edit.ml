open Core

type trim = { shares : int; price : float } [@@deriving sexp, eq, show]

let _normalize_symbol s = String.uppercase (String.strip s)

(* Every validation returns [Ok ()] or a described error, so a group of them
   composes with [Or_error.combine_errors_unit] and the caller sees all the
   problems at once rather than one per re-run. Each check that needs a
   formatted message is its own named function, which keeps the composing lists
   flat and readable. *)
let _check cond message = if cond then Ok () else Or_error.error_string message

let _check_positive_int ~name value =
  _check (value > 0) (sprintf "%s must be positive: %d" name value)

let _check_positive_float ~name value =
  _check Float.(value > 0.0) (sprintf "%s must be positive: %.4f" name value)

let _check_symbol symbol =
  _check (not (String.is_empty symbol)) "symbol must not be blank (--symbol)"

let _find (t : Live_portfolio.t) ~symbol =
  List.find t.positions ~f:(fun p -> String.equal p.symbol symbol)

let _require_held t ~symbol =
  match _find t ~symbol with
  | Some position -> Ok position
  | None -> Or_error.error_string (sprintf "%s is not held" symbol)

let _replace (t : Live_portfolio.t) ~(position : Live_portfolio.position) =
  List.map t.positions ~f:(fun p ->
      if String.equal p.symbol position.symbol then position else p)

let _remove (t : Live_portfolio.t) ~symbol =
  List.filter t.positions ~f:(fun p -> not (String.equal p.symbol symbol))

let _proceeds ~shares ~price = Float.of_int shares *. price

(* --- record ------------------------------------------------------------- *)

let _check_stop_below_entry ~stop_price ~entry_price =
  _check
    Float.(stop_price < entry_price)
    (sprintf "stop-price (%.4f) must sit below entry-price (%.4f)" stop_price
       entry_price)

let _check_not_held t ~symbol =
  _check
    (Option.is_none (_find t ~symbol))
    (sprintf "%s is already held; use `adjust` to change it, or `close` first"
       symbol)

let _check_affordable ~symbol ~cost ~cash =
  _check
    Float.(cash -. cost >= 0.0)
    (sprintf "insufficient cash: %s costs %.2f but only %.2f is available"
       symbol cost cash)

let _validate_new (p : Live_portfolio.position) =
  Or_error.combine_errors_unit
    [
      _check_symbol p.symbol;
      _check_positive_int ~name:"shares" p.shares;
      _check_positive_float ~name:"entry-price" p.entry_price;
      _check_positive_float ~name:"stop-price" p.stop_price;
      _check_stop_below_entry ~stop_price:p.stop_price
        ~entry_price:p.entry_price;
    ]

let record (t : Live_portfolio.t) ~as_of ~(position : Live_portfolio.position) =
  let position = { position with symbol = _normalize_symbol position.symbol } in
  let cost = _proceeds ~shares:position.shares ~price:position.entry_price in
  let open Or_error.Let_syntax in
  let%bind () = _validate_new position in
  let%bind () = _check_not_held t ~symbol:position.symbol in
  let%map () = _check_affordable ~symbol:position.symbol ~cost ~cash:t.cash in
  {
    Live_portfolio.cash = t.cash -. cost;
    as_of;
    positions = t.positions @ [ position ];
  }

(* --- close -------------------------------------------------------------- *)

let close (t : Live_portfolio.t) ~as_of ~symbol ~exit_price =
  let symbol = _normalize_symbol symbol in
  let open Or_error.Let_syntax in
  let%bind () = _check_positive_float ~name:"exit-price" exit_price in
  let%map held = _require_held t ~symbol in
  let cash = t.cash +. _proceeds ~shares:held.shares ~price:exit_price in
  { Live_portfolio.cash; as_of; positions = _remove t ~symbol }

(* --- adjust ------------------------------------------------------------- *)

let _check_trim_fits ~shares ~held_shares =
  _check (shares < held_shares)
    (sprintf
       "trim-shares (%d) must be fewer than the %d held; use `close` for a \
        full exit"
       shares held_shares)

(* Weinstein's never-lower rule (weinstein-book-reference.md §5.2 "Continue
   moving the sell-stop up as the MA advances"; §5.4 "Don't hold hoping it will
   come back"). Compared against [stop_price] — the trader's actual working
   broker order, which is the field this subcommand edits. Equality passes, so
   re-running the same command is idempotent rather than an error. *)
let _check_stop_not_lowered ~allow_lower ~new_stop ~current =
  _check
    (allow_lower || Float.(new_stop >= current))
    (sprintf
       "stop-price (%.4f) is below the stop in force (%.4f); a Weinstein \
        trailing stop is never lowered. Pass --allow-lower-stop to override \
        (which also resets the stop state)."
       new_stop current)

let _validate_stop_value ~(held : Live_portfolio.position) ~allow_lower new_stop
    =
  Or_error.combine_errors_unit
    [
      _check_positive_float ~name:"stop-price" new_stop;
      _check_stop_not_lowered ~allow_lower ~new_stop ~current:held.stop_price;
    ]

let _validate_stop ~held ~allow_lower stop_price =
  Option.value_map stop_price ~default:(Ok ())
    ~f:(_validate_stop_value ~held ~allow_lower)

(* Keep the carried stop state in step with a manual raise, so next week's
   [Stop_thread.advance] resumes from the stop actually in force rather than
   resurrecting a stale machine level. A refusal from {!Stop_track.ratchet}
   means the machine's own stop already sits higher, in which case leaving the
   track alone is what the never-lower rule requires. *)
let _ratchet_track track ~to_ =
  Option.map track ~f:(fun t ->
      Option.value (Stop_track.ratchet t ~to_) ~default:t)

(* A deliberate [--allow-lower-stop] override drops the track: the machine's
   accumulated state is no longer a truthful description of a position whose
   stop the trader has moved against it, so the next advance re-seeds honestly
   from bars instead of carrying state that has been contradicted. *)
let _apply_stop (held : Live_portfolio.position) ~allow_lower ~stop_price =
  match stop_price with
  | None -> held
  | Some new_stop when allow_lower && Float.(new_stop < held.stop_price) ->
      { held with stop_price = new_stop; stop_state = None }
  | Some new_stop ->
      {
        held with
        stop_price = new_stop;
        stop_state = _ratchet_track held.stop_state ~to_:new_stop;
      }

let _validate_trim_value ~held_shares { shares; price } =
  Or_error.combine_errors_unit
    [
      _check_positive_int ~name:"trim-shares" shares;
      _check_positive_float ~name:"trim-price" price;
      _check_trim_fits ~shares ~held_shares;
    ]

let _validate_trim ~held_shares trim =
  Option.value_map trim ~default:(Ok ()) ~f:(_validate_trim_value ~held_shares)

let _check_not_a_no_op ~stop_price ~trim =
  _check
    (Option.is_some stop_price || Option.is_some trim)
    "adjust needs --stop-price and/or --trim-shares with --trim-price"

(* The adjusted position plus the cash it frees (zero for a stop-only edit). *)
let _adjusted held ~allow_lower ~stop_price ~trim =
  let held = _apply_stop held ~allow_lower ~stop_price in
  match trim with
  | None -> (held, 0.0)
  | Some { shares; price } ->
      ( { held with Live_portfolio.shares = held.shares - shares },
        _proceeds ~shares ~price )

let adjust (t : Live_portfolio.t) ~as_of ~symbol ?stop_price
    ?(allow_lower = false) ?trim () =
  let symbol = _normalize_symbol symbol in
  let open Or_error.Let_syntax in
  let%bind held = _require_held t ~symbol in
  let%bind () = _check_not_a_no_op ~stop_price ~trim in
  let%map () =
    Or_error.combine_errors_unit
      [
        _validate_stop ~held ~allow_lower stop_price;
        _validate_trim ~held_shares:held.shares trim;
      ]
  in
  let position, credit = _adjusted held ~allow_lower ~stop_price ~trim in
  {
    Live_portfolio.cash = t.cash +. credit;
    as_of;
    positions = _replace t ~position;
  }
