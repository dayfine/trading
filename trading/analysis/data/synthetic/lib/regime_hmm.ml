open Core

type regime = Bull | Bear | Crisis [@@deriving sexp, eq, show]
type transition_matrix = (regime * (regime * float) list) list
type t = { initial_regime : regime; transitions : transition_matrix }

(* Tolerance for "row sums to 1". Each transition row is a tiny float
   association list; floating-point sums of three exact decimals like
   0.97 + 0.025 + 0.005 land within ~1e-15. We use a generous epsilon
   so hand-set matrices entered as decimal literals always pass. *)
let _prob_epsilon = 1e-9

(* Hand-set defaults — see regime_hmm.mli for rationale. *)
let default_transitions : transition_matrix =
  [
    (Bull, [ (Bull, 0.97); (Bear, 0.025); (Crisis, 0.005) ]);
    (Bear, [ (Bull, 0.05); (Bear, 0.93); (Crisis, 0.02) ]);
    (Crisis, [ (Bull, 0.10); (Bear, 0.25); (Crisis, 0.65) ]);
  ]

let default = { initial_regime = Bull; transitions = default_transitions }

(* ---------------------------------------------------------------------- *)
(* Validation                                                             *)
(* ---------------------------------------------------------------------- *)

let _all_regimes = [ Bull; Bear; Crisis ]

let _check_row_present transitions r =
  if List.Assoc.mem transitions ~equal:equal_regime r then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "transition matrix missing row for regime %s"
         (show_regime r))

let _check_row_entries row =
  let missing =
    List.filter _all_regimes ~f:(fun r ->
        not (List.Assoc.mem row ~equal:equal_regime r))
  in
  match missing with
  | [] -> Ok ()
  | r :: _ ->
      Status.error_invalid_argument
        (Printf.sprintf "transition row missing entry for %s" (show_regime r))

let _check_row_probs row =
  let bad =
    List.find row ~f:(fun (_, p) -> Float.(p < 0.0) || Float.(p > 1.0))
  in
  match bad with
  | Some (r, p) ->
      Status.error_invalid_argument
        (Printf.sprintf "transition probability out of [0,1] for %s: %.6f"
           (show_regime r) p)
  | None -> Ok ()

let _check_row_sum row =
  let s = List.sum (module Float) row ~f:snd in
  if Float.(abs (s -. 1.0) <= _prob_epsilon) then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "transition row sums to %.9f (expected 1.0)" s)

let _validate_row transitions r =
  match List.Assoc.find transitions ~equal:equal_regime r with
  | None ->
      Status.error_invalid_argument
        (Printf.sprintf "no row for %s" (show_regime r))
  | Some row ->
      Status.combine_status_list
        [ _check_row_entries row; _check_row_probs row; _check_row_sum row ]

let validate t =
  let row_presence =
    List.map _all_regimes ~f:(_check_row_present t.transitions)
  in
  let row_validations =
    List.map _all_regimes ~f:(_validate_row t.transitions)
  in
  Status.combine_status_list (row_presence @ row_validations)

(* ---------------------------------------------------------------------- *)
(* Sampling                                                               *)
(* ---------------------------------------------------------------------- *)

(* Inverse-CDF sampling on a discrete distribution. Walk the row in fixed
   order; cumulate probabilities; return the first regime whose cumulative
   exceeds the uniform draw. We canonicalise the iteration order via
   [_all_regimes] so the result is independent of how the caller spelled
   the row association list. *)
let _sample_next_regime ~rng ~row =
  let u = Stdlib.Random.State.float rng 1.0 in
  let rec walk acc = function
    | [] -> List.last_exn _all_regimes
    | r :: rest ->
        let p =
          List.Assoc.find row ~equal:equal_regime r |> Option.value ~default:0.0
        in
        let acc' = acc +. p in
        if Float.(u <= acc') then r else walk acc' rest
  in
  walk 0.0 _all_regimes

let _row_for ~transitions r =
  match List.Assoc.find transitions ~equal:equal_regime r with
  | Some row -> row
  | None ->
      invalid_arg
        (Printf.sprintf "regime_hmm: missing transition row for %s"
           (show_regime r))

let sample_path t ~n_steps ~seed =
  if n_steps <= 0 then []
  else
    match validate t with
    | Error e -> invalid_arg ("regime_hmm: invalid t — " ^ Status.show e)
    | Ok () ->
        let rng = Stdlib.Random.State.make [| seed |] in
        let arr = Array.create ~len:n_steps t.initial_regime in
        for k = 1 to n_steps - 1 do
          let row = _row_for ~transitions:t.transitions arr.(k - 1) in
          arr.(k) <- _sample_next_regime ~rng ~row
        done;
        Array.to_list arr
