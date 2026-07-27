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

(* Colour roles. Light values first, then the dark overrides. The chart pair
   (--entry / --stop) is blue/red: validated for lightness band, chroma floor,
   CVD separation and surface contrast in BOTH modes. *)
let _palette =
  {|:root {
  color-scheme: light dark;
  --surface: #fcfcfb;
  --surface-alt: #f4f3f0;
  --ink: #0b0b0b;
  --ink-soft: #52514e;
  --rule: #dedcd6;
  --px: #52514e;
  --entry: #2a78d6;
  --stop: #e34948;
  --vol: #d0cfc9;
  --band: #eceae4;
  --flag: #b4451f;
}
@media (prefers-color-scheme: dark) {
  :root {
    --surface: #1a1a19;
    --surface-alt: #232322;
    --ink: #ffffff;
    --ink-soft: #c3c2b7;
    --rule: #3a3a37;
    --px: #c3c2b7;
    --entry: #3987e5;
    --stop: #e66767;
    --vol: #45443f;
    --band: #2b2b28;
    --flag: #f0925f;
  }
}|}

let _layout =
  {|body {
  background: var(--surface);
  color: var(--ink);
  font: 14px/20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  margin: 0 auto;
  max-width: 1180px;
  padding: 24px 16px 64px;
}
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { border-bottom: 1px solid var(--rule); font-size: 16px; margin: 32px 0 8px; padding-bottom: 4px; }
.subtitle { color: var(--ink-soft); margin: 0 0 8px; }
.macro { font-size: 16px; }
.note { color: var(--ink-soft); font-size: 12px; font-style: italic; margin: 6px 0 0; }
.empty { color: var(--ink-soft); font-style: italic; }
.flag { color: var(--flag); font-weight: 600; }
ul { margin: 4px 0; padding-left: 20px; }|}

let _table_style =
  {|table { border-collapse: collapse; font-size: 13px; width: 100%; }
th, td { border-bottom: 1px solid var(--rule); padding: 6px 8px; text-align: left; vertical-align: top; }
th { color: var(--ink-soft); font-size: 11px; letter-spacing: .04em; text-transform: uppercase; }
tbody tr:nth-child(even) { background: var(--surface-alt); }
td.num { font-variant-numeric: tabular-nums; text-align: right; white-space: nowrap; }
td.rationale { color: var(--ink-soft); }
td.instruction { font-size: 12px; }
td.chart { width: 268px; }
td.chart .nochart { color: var(--ink-soft); font-size: 11px; font-style: italic; }|}

(* Mark specs: thin strokes, recessive volume, dashed level lines so identity
   never rests on colour alone. *)
let _chart_style =
  {|svg.spark { display: block; height: auto; width: 260px; }
svg.spark .band { fill: var(--band); }
svg.spark .vol { fill: var(--vol); }
svg.spark .px { fill: none; stroke: var(--px); stroke-width: 1.5px; stroke-linejoin: round; }
svg.spark .lvl { stroke-width: 1.5px; }
svg.spark .lvl-entry { stroke: var(--entry); stroke-dasharray: 5 3; }
svg.spark .lvl-stop { stroke: var(--stop); stroke-dasharray: 2 2; }
svg.spark .lvl-ref { stroke: var(--ink-soft); stroke-dasharray: 1 3; }|}

let css =
  String.concat ~sep:"\n" [ _palette; _layout; _table_style; _chart_style ]

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
