(** Static markup + CSS half of the interactive trade-audit report page. See
    [.mli] for the contract; the JS behaviour half is {!Html_script}. *)

(* Document head, inline CSS, and body skeleton, ending with the opening
   [<script>] tag and the [const DATA=/*DATA*/;] assignment. {!Html_render}
   concatenates this with {!Html_script.script} and substitutes the run's JS
   object literal for the single [/*DATA*/] placeholder. The CSS + layout are
   adapted from the human-approved [audit_dashboard_D.html] mock. *)
let markup =
  {html|<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Trade Audit</title>
<style>
  :root {
    --surface: #fcfcfb; --surface-2: #f3f2ef; --line: #e4e2dc;
    --ink: #0b0b0b; --ink-2: #52514e; --ink-3: #8a8880;
    --strat: #2a78d6; --bench: #8a8984;
    --good: #008300; --bad: #c93736;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --surface: #1a1a19; --surface-2: #232322; --line: #373633;
      --ink: #ffffff; --ink-2: #c3c2b7; --ink-3: #8b8a82;
      --strat: #3987e5; --bench: #8b8a82;
      --good: #4caf50; --bad: #e66767;
    }
  }
  body {
    font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
    background: var(--surface); color: var(--ink);
    margin: 0; padding: 28px clamp(16px, 4vw, 48px) 64px;
    font-size: 14.5px; line-height: 1.5;
  }
  h1 { font-size: 22px; margin: 0 0 2px; letter-spacing: -0.01em; text-wrap: balance; }
  .sub { color: var(--ink-2); margin: 0 0 22px; font-size: 13.5px; }
  h2 { font-size: 15px; margin: 34px 0 10px; letter-spacing: 0.02em; }
  h2 .note { font-weight: 400; color: var(--ink-3); font-size: 12.5px; margin-left: 8px; }
  .mono, td.num, .kpi b { font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace; font-variant-numeric: tabular-nums; }

  .kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(128px, 1fr)); gap: 10px; }
  .kpi { background: var(--surface-2); border: 1px solid var(--line); border-radius: 6px; padding: 10px 12px; }
  .kpi span { display: block; font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--ink-3); }
  .kpi b { display: block; font-size: 19px; font-weight: 600; margin-top: 3px; }
  .kpi small { color: var(--ink-2); font-size: 11.5px; }
  .kpi.hero { border-color: var(--strat); }

  .chartwrap { position: relative; margin-top: 6px; }
  svg text { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 11px; fill: var(--ink-3); }
  svg .serieslabel { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 12px; font-weight: 600; }
  .tip { position: absolute; pointer-events: none; background: var(--surface-2); border: 1px solid var(--line);
         border-radius: 5px; padding: 6px 9px; font-size: 12px; display: none; white-space: nowrap; box-shadow: 0 2px 8px rgba(0,0,0,.12); z-index: 5; }
  .tip b { font-family: ui-monospace, Menlo, monospace; font-weight: 600; }

  .tablewrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 6px; }
  table { border-collapse: collapse; width: 100%; font-size: 13px; }
  th, td { padding: 6px 10px; text-align: left; border-bottom: 1px solid var(--line); white-space: nowrap; }
  td.num, th.num { text-align: right; }
  thead th { position: sticky; top: 0; background: var(--surface-2); font-size: 11.5px; text-transform: uppercase;
             letter-spacing: 0.05em; color: var(--ink-2); cursor: pointer; user-select: none; }
  thead th:hover { color: var(--ink); }
  thead th .arrow { font-size: 9px; margin-left: 3px; }
  tbody tr:hover { background: var(--surface-2); }
  tbody tr:last-child td { border-bottom: none; }
  .pos { color: var(--good); } .neg { color: var(--bad); }
  .chip { display: inline-block; padding: 1px 7px; border-radius: 999px; font-size: 11px; background: var(--surface-2); border: 1px solid var(--line); color: var(--ink-2); }

  .filters { display: flex; gap: 10px; flex-wrap: wrap; margin: 0 0 10px; align-items: center; }
  .filters input, .filters select {
    font: inherit; font-size: 13px; color: var(--ink); background: var(--surface-2);
    border: 1px solid var(--line); border-radius: 5px; padding: 5px 9px;
  }
  .filters input:focus, .filters select:focus { outline: 2px solid var(--strat); outline-offset: 1px; }
  .filters .count { color: var(--ink-3); font-size: 12.5px; margin-left: auto; }

  .grid2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 12px; }
  .panel { background: var(--surface-2); border: 1px solid var(--line); border-radius: 6px; padding: 12px 14px; }
  .panel h3 { margin: 0 0 8px; font-size: 13px; }
  .panel ul { margin: 0; padding-left: 18px; color: var(--ink-2); font-size: 13px; }
  .panel table { font-size: 12.5px; }
  .panel th, .panel td { padding: 3px 8px; border-bottom: 1px solid var(--line); }
  .footnote { color: var(--ink-3); font-size: 12px; margin-top: 8px; }
  .hidden { display: none; }

  tr.traderow { cursor: pointer; }
  tr.detailrow > td { background: var(--surface-2); padding: 0; }
  .tradedetail { padding: 12px 14px; }
  .tdhead { font-size: 13px; margin-bottom: 8px; color: var(--ink-2); }
  .tradecv { width: 100%; height: 260px; display: block; background: var(--surface); border: 1px solid var(--line); border-radius: 6px; }
  .gradechip { display: inline-block; min-width: 46px; text-align: center; padding: 1px 7px; border-radius: 999px; font-size: 11px; font-weight: 700; border: 1px solid var(--line); }
  .grade-Ap { background: rgba(46,160,67,.25); color: var(--good); }
  .grade-A { background: rgba(46,160,67,.15); color: var(--good); }
  .grade-B { background: rgba(210,153,34,.18); color: #d29922; }
  .grade-C { background: var(--surface-2); color: var(--ink-2); }
  .grade-D { background: rgba(248,81,73,.12); color: var(--bad); }
  .grade-F { background: rgba(248,81,73,.22); color: var(--bad); }
  .qbars { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 6px 18px; margin-top: 10px; }
  .qbar { display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--ink-2); }
  .qbar span { width: 82px; }
  .qbar b { width: 38px; text-align: right; }
  .qtrack { flex: 1; height: 6px; background: var(--surface); border: 1px solid var(--line); border-radius: 999px; overflow: hidden; }
  .qfill { height: 100%; background: var(--strat); }
</style>
</head>
<body>
  <h1 id="title">Trade Audit</h1>
  <p class="sub" id="subtitle"></p>

  <div class="kpis" id="kpis"></div>

  <h2 id="charthead">Portfolio NAV <span class="note">log scale &middot; weekly samples</span></h2>
  <div class="chartwrap" id="chartwrap">
    <svg id="chart" width="100%" height="380" role="img" aria-label="Portfolio NAV versus benchmark, log scale"></svg>
    <div class="tip" id="tip"></div>
  </div>

  <h2 id="utilhead" class="hidden">Capital utilization <span class="note">&Sigma; held-position value / NAV &middot; weekly &middot; raw-close marks (spikes &gt;100% = corrupt-bar noise, not leverage)</span></h2>
  <div class="chartwrap hidden" id="utilwrap">
    <svg id="utilchart" width="100%" height="200" role="img" aria-label="Percent of NAV deployed in positions over time"></svg>
    <div class="tip" id="utiltip"></div>
  </div>

  <h2 id="openhead" class="hidden">Open positions at end of run</h2>
  <div class="tablewrap hidden" id="openwrap"><table id="opens"></table></div>
  <p class="footnote hidden" id="openfoot"></p>

  <h2 id="panelhead" class="hidden">Behavioural &amp; conformance summary</h2>
  <div class="grid2 hidden" id="panels">
    <div class="panel"><h3 id="confhead">Weinstein conformance</h3><table id="conftbl"></table></div>
    <div class="panel"><h3>Behavioural metrics</h3><ul id="behav"></ul></div>
    <div class="panel"><h3 id="dechead">Decision quality</h3><table id="dectbl"></table></div>
  </div>

  <h2 id="tradehead">All round-trips <span class="note" id="tradenote"></span></h2>
  <div class="filters">
    <input id="fsym" type="search" placeholder="Filter symbol&hellip;" aria-label="Filter by symbol">
    <select id="ftrig" aria-label="Filter by exit trigger"><option value="">All exit triggers</option></select>
    <select id="fwin" aria-label="Filter by outcome">
      <option value="">Winners + losers</option><option value="w">Winners only</option><option value="l">Losers only</option>
    </select>
    <span class="count" id="count"></span>
  </div>
  <div class="tablewrap" style="max-height: 70vh; overflow-y: auto;"><table id="trades"></table></div>
<script>
const DATA=/*DATA*/;
|html}
