open Core

let pct x = sprintf "%.1f%%" (x *. 100.0)
let signed_pct x = sprintf "%+.2f%%" (x *. 100.0)
let money x = "$" ^ Float.to_string_hum ~delimiter:',' ~decimals:2 x
let opt f = function Some x -> f x | None -> "-"

let setting ~show ~equal ~default value =
  if equal value default then show value
  else
    sprintf "%s (demo setting; the default is %s)" (show value) (show default)

(* [ppx_deriving.show] qualifies constructors ("Weinstein_types.Bullish"). *)
let unqualified s = List.last_exn (String.split s ~on:'.')

let stage_name : Weinstein_types.stage -> string = function
  | Stage1 { weeks_in_base } -> sprintf "Stage 1 (wk %d)" weeks_in_base
  | Stage2 { weeks_advancing; late = false } ->
      sprintf "Stage 2 (wk %d)" weeks_advancing
  | Stage2 { weeks_advancing; late = true } ->
      sprintf "Stage 2 late (wk %d)" weeks_advancing
  | Stage3 { weeks_topping } -> sprintf "Stage 3 (wk %d)" weeks_topping
  | Stage4 { weeks_declining } -> sprintf "Stage 4 (wk %d)" weeks_declining

let stage_number : Weinstein_types.stage -> int = function
  | Stage1 _ -> 1
  | Stage2 _ -> 2
  | Stage3 _ -> 3
  | Stage4 _ -> 4

let side_name : Trading_base.Types.position_side -> string = function
  | Long -> "long"
  | Short -> "short"

(* Width of the "Does:" text column; with its 8-column indent a line stays
   within 84 columns. *)
let _does_width = 76

(* Greedy word wrap: each line takes words while it stays within [width]. *)
let _wrap ~width text =
  String.split text ~on:' '
  |> List.filter ~f:(fun word -> not (String.is_empty word))
  |> List.fold ~init:[] ~f:(fun lines word ->
      match lines with
      | line :: rest when String.length line + 1 + String.length word <= width
        ->
          (line ^ " " ^ word) :: rest
      | _ -> word :: lines)
  |> List.rev

let header buf ~n ~title ~does ~input ~output =
  bprintf buf "\n==== STAGE %d of 9: %s ====\n" n title;
  List.concat_map does ~f:(_wrap ~width:_does_width)
  |> List.iteri ~f:(fun i line ->
      bprintf buf "  %s %s\n" (if i = 0 then "Does:" else "     ") line);
  bprintf buf "  In:   %s\n  Out:  %s\n\n" input output

let row buf fmt = ksprintf (fun s -> bprintf buf "  %s\n" s) fmt
