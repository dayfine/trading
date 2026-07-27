open Core

type t = { text : string; modifier : string option }

let make ?modifier text = { text; modifier }

(* The modifier is escaped as well as the text: a modifier derived from snapshot
   data (a regime label, a reconciliation class) reaches an attribute, and an
   unescaped quote there would break out of it. *)
let _class_attr = function
  | None -> "chip"
  | Some m -> Printf.sprintf "chip chip-%s" (Html_page.escape m)

let render c =
  Printf.sprintf "<span class=\"%s\">%s</span>" (_class_attr c.modifier)
    (Html_page.escape c.text)

let render_all chips = String.concat ~sep:"" (List.map chips ~f:render)

let group ?(cls = "chips") chips =
  Printf.sprintf "<span class=\"%s\">%s</span>" cls (render_all chips)
