open Core

type num = { label : string; value : string; modifier : string option }

let num ?modifier ~label value = { label; value; modifier }

type footer = { body : string; modifier : string option }

let footer ?modifier body = { body; modifier }

type t = {
  modifier : string option;
  arm : string;
  rank : int option;
  symbol : string;
  chips : Chip.t list;
  nums : num list;
  chart : string option;
  footer : footer option;
}

let _e = Html_page.escape

(* Rendered in place of a sparkline when the caller had no bars for the symbol
   (fewer than two, or no bar source at all). The card stays complete. *)
let _no_chart_marker = "<span class=\"nochart\">no chart data</span>"
let _tradingview_base = "https://www.tradingview.com/chart/?symbol="
let tradingview_href symbol = _tradingview_base ^ _e symbol

(* [base] alone when there is no modifier, [base base-<m>] when there is — the
   one place the report builds a two-token class name. *)
let _cls base = function
  | None -> base
  | Some m -> Printf.sprintf "%s %s-%s" base base m

let _rank = function
  | None -> ""
  | Some r -> Printf.sprintf "<span class=\"rank\">%d</span>" r

(* The symbol opens its TradingView chart in a new tab. [rel="noopener"] is
   required alongside [target="_blank"]: without it the opened page gets a
   handle back to this document. *)
let _symbol symbol =
  Printf.sprintf
    "<a class=\"sym\" href=\"%s\" target=\"_blank\" rel=\"noopener\">%s</a>"
    (tradingview_href symbol) (_e symbol)

let _num (n : num) =
  Printf.sprintf
    "<span class=\"num\"><i>%s</i><span class=\"%s\">%s</span></span>"
    (_e n.label)
    (_cls "num-value" n.modifier)
    (_e n.value)

let _nums nums =
  Printf.sprintf "<span class=\"nums\">%s</span>"
    (String.concat ~sep:"" (List.map nums ~f:_num))

let _chart ~arm ~symbol chart =
  Printf.sprintf "<div class=\"chart\" data-chart=\"%s:%s\">%s</div>" (_e arm)
    (_e symbol)
    (Option.value chart ~default:_no_chart_marker)

let _footer : footer option -> string = function
  | None -> ""
  | Some f ->
      Printf.sprintf "<div class=\"%s\">%s</div>" (_cls "ticket" f.modifier)
        f.body

let render (c : t) =
  Printf.sprintf
    "<div class=\"%s\"><div class=\"cand-main\">%s%s%s%s</div>%s%s</div>"
    (_cls "cand" c.modifier) (_rank c.rank) (_symbol c.symbol)
    (Chip.group c.chips) (_nums c.nums)
    (_chart ~arm:c.arm ~symbol:c.symbol c.chart)
    (_footer c.footer)
