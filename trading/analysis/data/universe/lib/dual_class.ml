open Core

(* Curated dual-class entities. The canonical key is conventionally the more
   commonly-quoted / more-liquid class's ticker, but any stable string works —
   only equality of keys across a pair matters. Tickers are stored uppercased;
   [entity_key] uppercases its input before lookup. *)
let known_pairs =
  [
    ("GOOGL", [ "GOOG"; "GOOGL" ]);
    (* Alphabet Class C / Class A *)
    ("BRK-B", [ "BRK-A"; "BRK-B" ]);
    (* Berkshire Hathaway Class A / Class B *)
    ("UA", [ "UA"; "UAA" ]);
    (* Under Armour Class C / Class A *)
    ("FOXA", [ "FOX"; "FOXA" ]);
    (* Fox Corp Class B / Class A *)
    ("NWSA", [ "NWS"; "NWSA" ]);
    (* News Corp Class B / Class A *)
    ("LEN", [ "LEN"; "LEN-B" ]);
    (* Lennar Class A / Class B *)
    ("HEI", [ "HEI"; "HEI-A" ]);
    (* HEICO common / Class A *)
  ]

(* Reverse index: member-ticker (uppercased) -> canonical key. Built once. *)
let _member_to_key : (string, string) Hashtbl.t =
  let tbl = Hashtbl.create (module String) in
  List.iter known_pairs ~f:(fun (key, members) ->
      List.iter members ~f:(fun m ->
          Hashtbl.set tbl ~key:(String.uppercase m) ~data:key));
  tbl

(* Class suffixes the root heuristic strips. A two-char separator+letter
   ([-A], [.B]) collapses to the root before it. Order does not matter; each is
   tested as an exact trailing match. *)
let _class_suffixes = [ "-A"; "-B"; "-C"; ".A"; ".B"; ".C" ]

let _strip_class_suffix upper =
  match
    List.find _class_suffixes ~f:(fun suf -> String.is_suffix upper ~suffix:suf)
  with
  | Some suf -> String.drop_suffix upper (String.length suf)
  | None -> upper

let entity_key symbol =
  let upper = String.uppercase symbol in
  match Hashtbl.find _member_to_key upper with
  | Some key -> key
  | None -> _strip_class_suffix upper
