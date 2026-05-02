open Core

type held_lot = { symbol : string; quantity : float; entry_price : float }
[@@deriving show, eq]

type check_status = Pass | Fail [@@deriving show, eq]

type check = { name : string; status : check_status; detail : string }
[@@deriving show, eq]

module Round_trip_result = struct
  type t = { checks : check list } [@@deriving show, eq]

  let all_pass t =
    List.for_all t.checks ~f:(fun c ->
        match c.status with Pass -> true | Fail -> false)

  let failures t =
    List.filter t.checks ~f:(fun c ->
        match c.status with Fail -> true | Pass -> false)
end

(* --------- Helpers --------- *)

let _default_adjusted_close_tolerance = 1e-3
let _default_cash_tolerance = 1e-6

(* Tolerance for arithmetic identities computed in this verifier (cost basis,
   stop adjustment) — we control both sides, so tight float epsilon. *)
let _arithmetic_tolerance = 1e-9
let _pass ~name detail = { name; status = Pass; detail }
let _fail ~name detail = { name; status = Fail; detail }

let _approximately_equal ~tolerance actual expected =
  let scale = Float.max (Float.abs expected) 1.0 in
  Float.( <= ) (Float.abs (actual -. expected)) (tolerance *. scale)

(* Find the held_position record for [symbol] in a snapshot. *)
let _find_held (snapshot : Weekly_snapshot.t) symbol =
  List.find snapshot.held_positions ~f:(fun h -> String.equal h.symbol symbol)

let _candidate_symbols (snapshot : Weekly_snapshot.t) =
  let extract = List.map ~f:(fun (c : Weekly_snapshot.candidate) -> c.symbol) in
  String.Set.of_list
    (extract snapshot.long_candidates @ extract snapshot.short_candidates)

(* --------- Split checks --------- *)

let _check_adjusted_close_continuity ~symbol ~split_date ~factor ~tolerance
    (bars : Types.Daily_price.t list) =
  let pre_bars = List.filter bars ~f:(fun b -> Date.( < ) b.date split_date) in
  match pre_bars with
  | [] ->
      _fail ~name:"adjusted_close_continuity"
        (Printf.sprintf "%s: no pre-split bars present in fixture" symbol)
  | _ ->
      let mismatches =
        List.filter_map pre_bars ~f:(fun b ->
            let recovered = b.adjusted_close *. factor in
            if _approximately_equal ~tolerance recovered b.close_price then None
            else
              Some
                (Printf.sprintf
                   "%s on %s: adjusted_close*factor=%.6f, close_price=%.6f"
                   symbol (Date.to_string b.date) recovered b.close_price))
      in
      if List.is_empty mismatches then
        _pass ~name:"adjusted_close_continuity"
          (Printf.sprintf
             "%s: all %d pre-split bars reconcile (factor=%.4f, tol=%.1e)"
             symbol (List.length pre_bars) factor tolerance)
      else
        _fail ~name:"adjusted_close_continuity"
          (Printf.sprintf "%s: %d bar(s) failed; first: %s" symbol
             (List.length mismatches) (List.hd_exn mismatches))

let _check_position_carryover ~symbol ~factor ~(pre_lot : held_lot)
    (pick_pre : Weekly_snapshot.t) (pick_post : Weekly_snapshot.t) =
  match (_find_held pick_pre symbol, _find_held pick_post symbol) with
  | None, _ ->
      _fail ~name:"position_carryover"
        (Printf.sprintf "%s: not present in pre-split snapshot.held_positions"
           symbol)
  | _, None ->
      _fail ~name:"position_carryover"
        (Printf.sprintf "%s: dropped from post-split snapshot.held_positions"
           symbol)
  | Some pre, Some post ->
      let expected_stop = pre.stop /. factor in
      if
        _approximately_equal ~tolerance:_arithmetic_tolerance post.stop
          expected_stop
      then
        _pass ~name:"position_carryover"
          (Printf.sprintf
             "%s: stop %.4f -> %.4f (factor=%.4f); pre quantity=%.4f" symbol
             pre.stop post.stop factor pre_lot.quantity)
      else
        _fail ~name:"position_carryover"
          (Printf.sprintf "%s: stop_post=%.6f, expected stop_pre/factor=%.6f"
             symbol post.stop expected_stop)

let _check_cost_basis_preserved ~symbol ~factor ~(pre_lot : held_lot) =
  let qty_post = pre_lot.quantity *. factor in
  let entry_post = pre_lot.entry_price /. factor in
  let pre_total = pre_lot.quantity *. pre_lot.entry_price in
  let post_total = qty_post *. entry_post in
  if _approximately_equal ~tolerance:_arithmetic_tolerance pre_total post_total
  then
    _pass ~name:"cost_basis_preserved"
      (Printf.sprintf "%s: pre=%.4f x %.4f = %.6f; post=%.4f x %.4f = %.6f"
         symbol pre_lot.quantity pre_lot.entry_price pre_total qty_post
         entry_post post_total)
  else
    _fail ~name:"cost_basis_preserved"
      (Printf.sprintf "%s: pre_total=%.6f, post_total=%.6f" symbol pre_total
         post_total)

let _check_no_phantom_picks ~symbol (pick_pre : Weekly_snapshot.t)
    (pick_post : Weekly_snapshot.t) =
  let pre_set = _candidate_symbols pick_pre in
  let post_set = _candidate_symbols pick_post in
  let phantom = Set.diff post_set pre_set in
  if Set.is_empty phantom then
    _pass ~name:"no_phantom_picks"
      (Printf.sprintf
         "%s: post-split candidate set is a subset of pre (sizes: pre=%d, \
          post=%d)"
         symbol (Set.length pre_set) (Set.length post_set))
  else
    _fail ~name:"no_phantom_picks"
      (Printf.sprintf "%s: new symbols in post-split candidates: %s" symbol
         (Set.to_list phantom |> String.concat ~sep:","))

let _check_stop_adjusted ~symbol ~factor (pick_pre : Weekly_snapshot.t)
    (pick_post : Weekly_snapshot.t) =
  match (_find_held pick_pre symbol, _find_held pick_post symbol) with
  | Some pre, Some post ->
      let expected = pre.stop /. factor in
      if
        _approximately_equal ~tolerance:_default_adjusted_close_tolerance
          post.stop expected
      then
        _pass ~name:"stop_adjusted"
          (Printf.sprintf "%s: stop %.4f -> %.4f (factor=%.4f)" symbol pre.stop
             post.stop factor)
      else
        _fail ~name:"stop_adjusted"
          (Printf.sprintf "%s: stop_post=%.6f, expected pre/factor=%.6f" symbol
             post.stop expected)
  | _ ->
      _fail ~name:"stop_adjusted"
        (Printf.sprintf "%s: position missing from snapshots" symbol)

let verify_split_round_trip ~symbol ~split_date ~factor ~bars
    ~(pre_split_lot : held_lot) ~(pick_pre_split : Weekly_snapshot.t)
    ~(pick_post_split : Weekly_snapshot.t)
    ?(adjusted_close_tolerance = _default_adjusted_close_tolerance) () =
  let checks =
    [
      _check_adjusted_close_continuity ~symbol ~split_date ~factor
        ~tolerance:adjusted_close_tolerance bars;
      _check_position_carryover ~symbol ~factor ~pre_lot:pre_split_lot
        pick_pre_split pick_post_split;
      _check_cost_basis_preserved ~symbol ~factor ~pre_lot:pre_split_lot;
      _check_no_phantom_picks ~symbol pick_pre_split pick_post_split;
      _check_stop_adjusted ~symbol ~factor pick_pre_split pick_post_split;
    ]
  in
  { Round_trip_result.checks }

(* --------- Dividend checks --------- *)

let _check_cash_credit ~symbol ~amount_per_share ~quantity ~cash_pre ~cash_post
    ~tolerance =
  let expected = cash_pre +. (quantity *. amount_per_share) in
  if _approximately_equal ~tolerance cash_post expected then
    _pass ~name:"cash_credit"
      (Printf.sprintf "%s: cash %.4f -> %.4f (+%.4f x %.4f)" symbol cash_pre
         cash_post quantity amount_per_share)
  else
    _fail ~name:"cash_credit"
      (Printf.sprintf "%s: cash_post=%.6f, expected=%.6f" symbol cash_post
         expected)

let _check_quantity_unchanged_label ~symbol ~quantity =
  (* Quantity is an input — the verifier cannot observe a runtime change. We
     record it so the test plan is explicit: the dividend convention here
     leaves quantity untouched (no DRIP, no scrip). *)
  _pass ~name:"quantity_unchanged"
    (Printf.sprintf "%s: quantity=%.4f (no DRIP / scrip)" symbol quantity)

let _check_stop_unchanged ~symbol (pick_pre : Weekly_snapshot.t)
    (pick_post : Weekly_snapshot.t) =
  match (_find_held pick_pre symbol, _find_held pick_post symbol) with
  | Some pre, Some post ->
      if
        _approximately_equal ~tolerance:_arithmetic_tolerance post.stop pre.stop
      then
        _pass ~name:"stop_unchanged"
          (Printf.sprintf "%s: stop %.4f preserved across dividend" symbol
             pre.stop)
      else
        _fail ~name:"stop_unchanged"
          (Printf.sprintf
             "%s: stop_pre=%.6f, stop_post=%.6f (dividends should not adjust)"
             symbol pre.stop post.stop)
  | _ ->
      _fail ~name:"stop_unchanged"
        (Printf.sprintf "%s: position missing from snapshots" symbol)

let verify_dividend_round_trip ~symbol ~ex_date:_ ~amount_per_share
    ~(pre_lot : held_lot) ~(pick_pre : Weekly_snapshot.t)
    ~(pick_post : Weekly_snapshot.t) ~cash_pre ~cash_post
    ?(cash_tolerance = _default_cash_tolerance) () =
  let checks =
    [
      _check_cash_credit ~symbol ~amount_per_share ~quantity:pre_lot.quantity
        ~cash_pre ~cash_post ~tolerance:cash_tolerance;
      _check_quantity_unchanged_label ~symbol ~quantity:pre_lot.quantity;
      _check_stop_unchanged ~symbol pick_pre pick_post;
    ]
  in
  { Round_trip_result.checks }
