open Core
open OUnit2

let assert_ok_with ~msg result ~f =
  match result with
  | Ok value -> f value
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let assert_error ~msg result =
  match result with Ok _ -> assert_failure msg | Error _ -> () (* Expected *)

let assert_ok ~msg result =
  match result with
  | Ok value -> value
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let assert_float_equal ?(epsilon = 1e-9) expected actual ~msg =
  let cmp a b = Float.(abs (a - b) < epsilon) in
  let printer = Float.to_string in
  assert_equal expected actual ~cmp ~printer ~msg

let assert_some_with ~msg option ~f =
  match option with Some value -> f value | None -> assert_failure msg

let assert_some ~msg option =
  match option with Some value -> value | None -> assert_failure msg

let assert_none ~msg option =
  match option with Some _ -> assert_failure msg | None -> () (* Expected *)

let elements_are list callbacks =
  if List.length list <> List.length callbacks then
    assert_failure
      (Printf.sprintf "List length (%d) does not match callbacks length (%d)"
         (List.length list) (List.length callbacks))
  else List.iter2_exn list callbacks ~f:(fun elem callback -> callback elem)

let all_of checks value = List.iter checks ~f:(fun check -> check value)
let field accessor matcher value = matcher (accessor value)

let equal_to ?(cmp = Poly.equal) ?(msg = "Values should be equal") expected
    actual =
  assert_equal expected actual ~cmp ~msg

(* Fluent Matcher API *)
type 'a matcher = 'a -> unit

let assert_that value matcher = matcher value

let is_ok_and_holds matcher result =
  match result with
  | Ok value -> matcher value
  | Error err -> assert_failure ("Expected Ok but got Error: " ^ Status.show err)

let each matcher list = List.iter list ~f:matcher

let one matcher list =
  match list with
  | [ single ] -> matcher single
  | _ ->
      assert_failure
        (Printf.sprintf "Expected exactly one element, got %d"
           (List.length list))

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
