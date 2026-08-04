open Core

type t = { text : string; modifier : string option; title : string option }

let make ?modifier ?title text = { text; modifier; title }

(* The modifier is escaped as well as the text: a modifier derived from snapshot
   data (a regime label, a reconciliation class) reaches an attribute, and an
   unescaped quote there would break out of it. *)
let _class_attr = function
  | None -> "chip"
  | Some m -> Printf.sprintf "chip chip-%s" (Html_page.escape m)

(* Native [title] tooltip — a browser-standard hover explainer needing no CSS or
   JS, so it survives the report's strict standalone CSP. Escaped, since the
   text is a shared explainer sentence that may carry quotes. *)
let _title_attr = function
  | None -> ""
  | Some t -> Printf.sprintf " title=\"%s\"" (Html_page.escape t)

let render c =
  Printf.sprintf "<span class=\"%s\"%s>%s</span>" (_class_attr c.modifier)
    (_title_attr c.title) (Html_page.escape c.text)

let render_all chips = String.concat ~sep:"" (List.map chips ~f:render)

let group ?(cls = "chips") chips =
  Printf.sprintf "<span class=\"%s\">%s</span>" cls (render_all chips)
