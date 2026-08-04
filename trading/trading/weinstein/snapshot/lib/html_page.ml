open Core

(* Ampersand is substituted FIRST so the entities introduced by the later
   substitutions are not themselves re-encoded. *)
let escape s =
  s
  |> String.substr_replace_all ~pattern:"&" ~with_:"&amp;"
  |> String.substr_replace_all ~pattern:"<" ~with_:"&lt;"
  |> String.substr_replace_all ~pattern:">" ~with_:"&gt;"
  |> String.substr_replace_all ~pattern:"\"" ~with_:"&quot;"
  |> String.substr_replace_all ~pattern:"'" ~with_:"&#39;"

(* The stylesheet is carried as a list of quoted single-line strings rather
   than one {|...|} block: CSS is dense with numeric literals (font sizes,
   paddings, all-digit hex colours), and the magic-number linter reads bare
   numerics inside {|...|} as code while it correctly ignores them inside
   "..." string literals. Quoted lines keep the literals honestly marked as
   text without contorting the CSS itself. *)

(* Colour roles. Light values first, then the dark overrides. The chart pair
   (--entry / --stop) is blue/red: validated for lightness band, chroma floor,
   CVD separation and surface contrast in BOTH modes. *)
let _palette =
  [
    ":root {";
    "  color-scheme: light dark;";
    "  --surface: #fcfcfb;";
    "  --surface-alt: #f4f3f0;";
    "  --ink: #0b0b0b;";
    "  --ink-soft: #52514e;";
    "  --rule: #dedcd6;";
    "  --px: #52514e;";
    "  --entry: #2a78d6;";
    "  --stop: #e34948;";
    "  --cap: #c77f1a;";
    "  --ma: #4a6fa5;";
    "  --vol: #d0cfc9;";
    "  --band: #eceae4;";
    "  --flag: #b4451f;";
    "  --good: #1e6b52;";
    "  --good-tint: #e7f0ec;";
    "}";
    "@media (prefers-color-scheme: dark) {";
    "  :root {";
    "    --surface: #1a1a19;";
    "    --surface-alt: #232322;";
    "    --ink: #ffffff;";
    "    --ink-soft: #c3c2b7;";
    "    --rule: #3a3a37;";
    "    --px: #c3c2b7;";
    "    --entry: #3987e5;";
    "    --stop: #e66767;";
    "    --cap: #e0a54a;";
    "    --ma: #7ea3d8;";
    "    --vol: #45443f;";
    "    --band: #2b2b28;";
    "    --flag: #f0925f;";
    "    --good: #63b394;";
    "    --good-tint: #22322c;";
    "  }";
    "}";
  ]

let _layout =
  [
    "body {";
    "  background: var(--surface);";
    "  color: var(--ink);";
    "  font: 14px/20px system-ui, sans-serif;";
    "  margin: 0 auto;";
    "  max-width: 1180px;";
    "  padding: 24px 16px 64px;";
    "}";
    "h1 { font-size: 22px; margin: 0 0 4px; }";
    "h2 { border-bottom: 1px solid var(--rule); font-size: 16px;";
    "     margin: 32px 0 8px; padding-bottom: 4px; }";
    ".note { color: var(--ink-soft); font-size: 12px; font-style: italic;";
    "        margin: 6px 0 0; }";
    ".empty { color: var(--ink-soft); font-style: italic; }";
    "ul { margin: 4px 0; padding-left: 20px; }";
  ]

(* Masthead, counts strip and the closing notes. *)
let _masthead_style =
  [
    "header { border-bottom: 3px double var(--ink); margin-bottom: 18px;";
    "         padding-bottom: 14px; }";
    ".mast-top { align-items: baseline; display: flex; flex-wrap: wrap;";
    "            gap: 12px; justify-content: space-between; }";
    ".asof { color: var(--ink-soft); font-size: 13px; }";
    ".mast-meta { display: flex; flex-wrap: wrap; gap: 8px;";
    "             margin-top: 10px; }";
    ".strip { background: var(--rule); border: 1px solid var(--rule);";
    "         border-radius: 4px; display: grid; gap: 1px; margin-bottom: 8px;";
    "         grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));";
    "         overflow: hidden; }";
    ".stat { background: var(--surface); padding: 8px 12px; }";
    ".stat .label { color: var(--ink-soft); font-size: 11px;";
    "               letter-spacing: .05em; text-transform: uppercase; }";
    ".stat b { display: block; font-size: 20px;";
    "          font-variant-numeric: tabular-nums; }";
    "footer { border-top: 1px solid var(--rule); color: var(--ink-soft);";
    "         font-size: 12px; margin-top: 32px; padding-top: 12px; }";
    "footer p { max-width: 76ch; }";
  ]

(* Cards. One [.cand] per candidate or held position: an identity row, the
   chart, then the executable line. *)
let _card_style =
  [
    ".cands { display: flex; flex-direction: column; gap: 10px;";
    "         margin-top: 10px; }";
    ".cand { background: var(--surface); border: 1px solid var(--rule);";
    "        border-radius: 4px; overflow: hidden; }";
    ".cand-extended { border-color: var(--flag); }";
    ".cand-main { align-items: center; display: flex; flex-wrap: wrap;";
    "             gap: 12px; padding: 8px 12px; }";
    ".rank { color: var(--ink-soft); font-variant-numeric: tabular-nums; }";
    "a.sym { border-bottom: 1px dashed var(--ink-soft); color: var(--ink);";
    "        font-size: 16px; font-weight: 700; text-decoration: none; }";
    "a.sym:hover, a.sym:focus { border-bottom-color: var(--entry);";
    "                           color: var(--entry); }";
    ".chips { display: flex; flex-wrap: wrap; gap: 5px; }";
    ".sectors { display: flex; flex-wrap: wrap; gap: 6px; }";
    ".nums { display: flex; flex-wrap: wrap; gap: 14px;";
    "        font-variant-numeric: tabular-nums; margin-left: auto; }";
    ".nums i { color: var(--ink-soft); display: block; font-size: 10px;";
    "          font-style: normal; letter-spacing: .06em;";
    "          text-transform: uppercase; }";
    ".num-value-entry { color: var(--entry); font-weight: 600; }";
    ".num-value-stop { color: var(--stop); font-weight: 600; }";
    ".chart { border-top: 1px dashed var(--rule); padding: 2px 12px 4px; }";
    ".nochart { color: var(--ink-soft); font-size: 11px;";
    "           font-style: italic; }";
    ".ticket { background: var(--surface-alt); border-top: 1px solid \
     var(--rule);";
    "          font-size: 12px; padding: 7px 12px; }";
    ".ticket-suppressed { color: var(--flag); }";
    ".legend { color: var(--ink-soft); display: flex; flex-wrap: wrap;";
    "          font-size: 12px; gap: 14px; margin: 6px 0 0; }";
    ".legend .sw { border-top: 2.5px solid; display: inline-block;";
    "              height: 0; margin-right: 5px; vertical-align: middle;";
    "              width: 20px; }";
    ".sw-px { border-color: var(--px); }";
    ".sw-ma { border-color: var(--ma); }";
    ".sw-entry { border-color: var(--entry); border-top-style: dashed; }";
    ".sw-stop { border-color: var(--stop); border-top-style: dashed; }";
  ]

(* Tag chips. Most facts are recessive; only the ones that change what a reader
   should DO escalate. Identity never rests on colour alone — every chip's text
   spells out what its colour is saying. *)
let _chip_style =
  [
    ".chip { border: 1px solid var(--rule); border-radius: 3px;";
    "        display: inline-block; font-size: 11px; padding: 1px 6px;";
    "        white-space: nowrap; }";
    ".chip-score { font-variant-numeric: tabular-nums; font-weight: 600; }";
    (* Recessive facts: true, worth stating, not worth escalating. *)
    ".chip-vol-ok, .chip-rs, .chip-breakout, .chip-early, .chip-supply,";
    ".chip-resistance, .chip-status, .chip-neutral {";
    "  background: var(--surface-alt); border-color: transparent; }";
    ".chip-vol-strong, .chip-structural, .chip-sector, .chip-bullish {";
    "  background: var(--good-tint); border-color: transparent;";
    "  color: var(--good); }";
    ".chip-virgin { background: var(--band); border-color: transparent; }";
    ".chip-fallback, .chip-suspect, .chip-bearish {";
    "  background: var(--band); border-color: transparent;";
    "  color: var(--flag); font-weight: 600; }";
    ".chip-valid-stop { background: var(--surface-alt); color: \
     var(--ink-soft); }";
    ".chip-through-entry { background: var(--band); color: var(--ink); }";
    ".chip-extended { background: var(--band); color: var(--flag);";
    "                 font-weight: 600; }";
    (* Score-composition + sector-name: recessive facts. *)
    ".chip-breakdown { background: var(--surface-alt); border-color: \
     transparent;";
    "                  font-variant-numeric: tabular-nums; }";
    ".chip-sectorname { background: var(--surface-alt);";
    "                   border-color: transparent; }";
    (* The weakest-links caveat escalates like the other flag chips. *)
    ".chip-weak { background: var(--band); border-color: transparent;";
    "             color: var(--flag); }";
  ]

(* Mark specs: thin strokes, recessive volume, dashed level lines so identity
   never rests on colour alone. *)
let _chart_style =
  [
    "svg.spark { display: block; height: auto; max-width: 100%; }";
    "svg.spark .band { fill: var(--band); }";
    "svg.spark .vol { fill: var(--vol); }";
    "svg.spark .px { fill: none; stroke: var(--px); stroke-width: 1.5px;";
    "                stroke-linejoin: round; }";
    "svg.spark .ma { fill: none; stroke: var(--ma); stroke-width: 1.5px;";
    "                stroke-linejoin: round; }";
    "svg.spark .last { fill: var(--px); stroke: var(--surface);";
    "                  stroke-width: 1.5px; }";
    "svg.spark .lvl { stroke-width: 1.5px; }";
    "svg.spark .lvl-entry { stroke: var(--entry); stroke-dasharray: 5 3; }";
    "svg.spark .lvl-stop { stroke: var(--stop); stroke-dasharray: 2 2; }";
    "svg.spark .lvl-ref { stroke: var(--ink-soft); stroke-dasharray: 1 3; }";
    "svg.spark .lvl-cap { stroke: var(--cap); stroke-dasharray: 4 2; }";
    "svg.spark .lvl-label { font-size: 10.5px;";
    "                       font-variant-numeric: tabular-nums; }";
    "svg.spark .lvl-label-entry { fill: var(--entry); }";
    "svg.spark .lvl-label-stop { fill: var(--stop); }";
    "svg.spark .lvl-label-ref { fill: var(--ink-soft); }";
    "svg.spark .lvl-label-cap { fill: var(--cap); }";
  ]

let css =
  String.concat ~sep:"\n"
    (List.concat
       [
         _palette;
         _layout;
         _masthead_style;
         _card_style;
         _chip_style;
         _chart_style;
       ])

let document ~title ~body =
  Printf.sprintf
    "<!DOCTYPE html>\n\
     <html lang=\"en\">\n\
     <head>\n\
     <meta charset=\"utf-8\">\n\
     <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
     <title>%s</title>\n\
     <style>\n\
     %s\n\
     </style>\n\
     </head>\n\
     <body>\n\
     %s\n\
     </body>\n\
     </html>\n"
    (escape title) css body
