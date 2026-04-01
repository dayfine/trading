open Core
open OUnit2

module type Ord = sig
  type t

  val compare : t -> t -> int
  val show : t -> string
end

module Int_ord = struct
  type t = int

  let compare = Int.compare
  let show = Int.to_string
end

module Float_ord = struct
  type t = float

  let compare = Float.compare
  let show = Float.to_string
end

(* ========================================================================== *)
(* Core Matcher Types                                                        *)
(* ========================================================================== *)

type 'a matcher = 'a -> unit

let assert_that value matcher = matcher value

(* ========================================================================== *)
(* Basic Matchers                                                            *)
(* ========================================================================== *)

let equal_to ?(cmp = Poly.equal) ?(msg = "Values should be equal") expected
    actual =
  assert_equal expected actual ~cmp ~msg

let field accessor matcher value = matcher (accessor value)
let all_of checks value = List.iter checks ~f:(fun check -> check value)

let not_ ?(msg = "Expected matcher to fail but it succeeded") matcher value =
  let passed =
    try
      matcher value;
      true
    with _ -> false
  in
  if passed then assert_failure msg

(* ========================================================================== *)
(* Result Matchers                                                           *)
(* ========================================================================== *)

let is_ok result =
  match result with
  | Ok _ -> () (* Expected *)
  | Error err -> assert_failure ("Expected Ok but got Error: " ^ Status.show err)

let is_ok_and_holds matcher result =
  match result with
  | Ok value -> matcher value
  | Error err -> assert_failure ("Expected Ok but got Error: " ^ Status.show err)

let is_error result =
  match result with
  | Ok _ -> assert_failure "Expected Error but got Ok"
  | Error _ -> () (* Expected *)

let is_error_with ?msg expected_code result =
  match result with
  | Ok _ -> assert_failure "Expected Error but got Ok"
  | Error ({ Status.code; _ } as status) -> (
      if not (Status.equal_code code expected_code) then
        assert_failure
          (Printf.sprintf "Expected error code %s but got %s"
             (Status.show_code expected_code)
             (Status.show_code code));
      match msg with
      | Some substring ->
          let msg_str = Status.show status in
          if not (String.is_substring msg_str ~substring) then
            assert_failure
              (Printf.sprintf
                 "Expected error message to contain '%s' but got: %s" substring
                 msg_str)
      | None -> ())

(* ========================================================================== *)
(* Option Matchers                                                           *)
(* ========================================================================== *)

let is_some_and matcher option =
  match option with
  | Some value -> matcher value
  | None -> assert_failure "Expected Some but got None"

let is_none option =
  match option with
  | Some _ -> assert_failure "Expected None but got Some"
  | None -> () (* Expected *)

let matching ?(msg = "Value did not match expected variant") extract
    inner_matcher value =
  match extract value with
  | Some inner -> inner_matcher inner
  | None -> assert_failure msg

let pair fst_matcher snd_matcher (a, b) =
  fst_matcher a;
  snd_matcher b

(* ========================================================================== *)
(* Numeric Matchers                                                          *)
(* ========================================================================== *)

let float_equal ?(epsilon = 1e-9) expected actual =
  if Float.(abs (expected - actual) >= epsilon) then
    assert_failure
      (Printf.sprintf "Expected float %f but got %f (epsilon: %g)" expected
         actual epsilon)

let gt (type a) (module M : Ord with type t = a) threshold actual =
  if M.compare actual threshold <= 0 then
    assert_failure
      (Printf.sprintf "Expected value > %s but got %s" (M.show threshold)
         (M.show actual))

let ge (type a) (module M : Ord with type t = a) threshold actual =
  if M.compare actual threshold < 0 then
    assert_failure
      (Printf.sprintf "Expected value >= %s but got %s" (M.show threshold)
         (M.show actual))

let lt (type a) (module M : Ord with type t = a) threshold actual =
  if M.compare actual threshold >= 0 then
    assert_failure
      (Printf.sprintf "Expected value < %s but got %s" (M.show threshold)
         (M.show actual))

let le (type a) (module M : Ord with type t = a) threshold actual =
  if M.compare actual threshold > 0 then
    assert_failure
      (Printf.sprintf "Expected value <= %s but got %s" (M.show threshold)
         (M.show actual))

(* ========================================================================== *)
(* List Matchers                                                             *)
(* ========================================================================== *)

let each matcher list = List.iter list ~f:matcher

let one matcher list =
  match list with
  | [ single ] -> matcher single
  | _ ->
      assert_failure
        (Printf.sprintf "Expected exactly one element, got %d"
           (List.length list))

let elements_are matchers list =
  if List.length list <> List.length matchers then
    assert_failure
      (Printf.sprintf "List length (%d) does not match matchers length (%d)"
         (List.length list) (List.length matchers))
  else List.iter2_exn list matchers ~f:(fun elem matcher -> matcher elem)

let unordered_elements_are matchers list =
  (* Check length first *)
  if List.length matchers <> List.length list then
    assert_failure
      (Printf.sprintf "Expected %d elements but got %d" (List.length matchers)
         (List.length list))
  else
    (* Build match matrix: matrix.(i).(j) = true if element i matches matcher j *)
    let matrix =
      List.map list ~f:(fun element ->
          List.map matchers ~f:(fun matcher ->
              try
                matcher element;
                true
              with _ -> false))
    in
    (* Check which matchers matched at least one element *)
    let matcher_matched =
      List.init (List.length matchers) ~f:(fun j ->
          List.exists matrix ~f:(fun row -> List.nth_exn row j))
    in
    (* Check which elements matched at least one matcher *)
    let element_matched =
      List.map matrix ~f:(fun row -> List.exists row ~f:Fn.id)
    in
    (* Find unmatched matchers *)
    let unmatched_matchers =
      List.filter_mapi matcher_matched ~f:(fun i matched ->
          if matched then None else Some i)
    in
    (* Find unmatched elements *)
    let unmatched_elements =
      List.filter_mapi element_matched ~f:(fun i matched ->
          if matched then None else Some i)
    in
    (* Report errors if any *)
    if
      (not (List.is_empty unmatched_matchers))
      || not (List.is_empty unmatched_elements)
    then
      let msgs = [] in
      let msgs =
        if not (List.is_empty unmatched_matchers) then
          Printf.sprintf
            "where the following matchers don't match any elements: %s"
            (String.concat ~sep:", "
               (List.map unmatched_matchers ~f:(fun i ->
                    Printf.sprintf "matcher #%d" i)))
          :: msgs
        else msgs
      in
      let msgs =
        if not (List.is_empty unmatched_elements) then
          Printf.sprintf
            "where the following elements don't match any matchers: %s"
            (String.concat ~sep:", "
               (List.map unmatched_elements ~f:(fun i ->
                    Printf.sprintf "element #%d" i)))
          :: msgs
        else msgs
      in
      assert_failure (String.concat ~sep:"\nand " (List.rev msgs))

let size_is expected_size list =
  let actual_size = List.length list in
  if actual_size <> expected_size then
    assert_failure
      (Printf.sprintf "Expected size %d but got %d" expected_size actual_size)

let is_empty list =
  if not (List.is_empty list) then
    assert_failure
      (Printf.sprintf "Expected empty list but got %d elements"
         (List.length list))
