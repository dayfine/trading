open Core

(* Display caps for the candidate tables. Match the section headers
   ("top 10" / "top 5") to keep header and content in sync. *)
let _long_display_limit = 10
let _short_display_limit = 5

(* Marker rendered for empty lists / tables so the reader never sees a missing
   section. *)
let _empty_marker = "(none)"

let _risk_pct ~entry ~stop =
  if Float.equal entry 0.0 then 0.0 else (entry -. stop) /. entry *. 100.0

(* Header line plus separator for a Markdown table. *)
let _table_header columns =
  let header = "| " ^ String.concat ~sep:" | " columns ^ " |" in
  let sep =
    "|" ^ String.concat ~sep:"" (List.map columns ~f:(fun _ -> "---|"))
  in
  header ^ "\n" ^ sep

let _candidate_row ~rank (c : Weekly_snapshot.candidate) =
  let risk = _risk_pct ~entry:c.entry ~stop:c.stop in
  Printf.sprintf "| %d | %s | %s | %.2f | $%.2f | $%.2f | %.1f%% | %s |" rank
    c.symbol c.grade c.score c.entry c.stop risk c.rationale

let _candidate_table candidates ~limit =
  let header =
    _table_header
      [
        "Rank";
        "Symbol";
        "Grade";
        "Score";
        "Entry";
        "Stop";
        "Risk %";
        "Rationale";
      ]
  in
  match candidates with
  | [] -> _empty_marker
  | _ ->
      let truncated = List.take candidates limit in
      let rows =
        List.mapi truncated ~f:(fun i c -> _candidate_row ~rank:(i + 1) c)
      in
      String.concat ~sep:"\n" (header :: rows)

let _held_row (h : Weekly_snapshot.held_position) =
  Printf.sprintf "| %s | %s | $%.2f | %s |" h.symbol (Date.to_string h.entered)
    h.stop h.status

let _held_table positions =
  let header = _table_header [ "Symbol"; "Entered"; "Stop"; "Status" ] in
  match positions with
  | [] -> _empty_marker
  | _ ->
      let rows = List.map positions ~f:_held_row in
      String.concat ~sep:"\n" (header :: rows)

let _sector_list sectors =
  match sectors with
  | [] -> _empty_marker
  | _ -> String.concat ~sep:"\n" (List.map sectors ~f:(fun s -> "- " ^ s))

let _macro_section (m : Weekly_snapshot.macro_context) =
  Printf.sprintf "**%s** (score %.2f)" m.regime m.score

let _section ~title body = Printf.sprintf "## %s\n%s" title body

let render (t : Weekly_snapshot.t) : string =
  let buf = Buffer.create 1024 in
  Buffer.add_string buf
    (Printf.sprintf "# Weekly Pick Report — %s\n\n" (Date.to_string t.date));
  Buffer.add_string buf
    (Printf.sprintf "System version: `%s`\n\n" t.system_version);
  Buffer.add_string buf (_section ~title:"Macro" (_macro_section t.macro));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Strong sectors" (_sector_list t.sectors_strong));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Long candidates (top 10)"
       (_candidate_table t.long_candidates ~limit:_long_display_limit));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Short candidates (top 5)"
       (_candidate_table t.short_candidates ~limit:_short_display_limit));
  Buffer.add_string buf "\n\n";
  Buffer.add_string buf
    (_section ~title:"Held positions" (_held_table t.held_positions));
  Buffer.add_string buf "\n";
  Buffer.contents buf
