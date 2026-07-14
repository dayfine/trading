(** JS behaviour + closing tags half of the interactive report page. See [.mli]
    for the contract; the markup + CSS half is {!Html_template}. *)

(* Generic client-side JS that reads every value from the [DATA] object literal
   {!Html_render} injects into {!Html_template.markup}. It hides the benchmark
   line, the capital-utilization chart, the open-positions table, and the
   conformance / behavioural panels when the corresponding [DATA] fields are
   absent/empty, so a run with no bar source still renders cleanly. Adapted from
   the human-approved [audit_dashboard_D.html] mock. *)
let script =
  {js|
/* ---- formatters ---- */
const fmt$ = v => (v<0?'-':'') + '$' + Math.abs(Math.round(v)).toLocaleString();
const fmtM = v => (v<0?'-':'') + '$' + (Math.abs(v)/1e6).toFixed(2) + 'M';
const pct = v => (v>0?'+':'') + v.toFixed(1) + '%';
const fmtAxis = v => v>=1e6 ? '$'+(v/1e6).toFixed(v>=1e7?0:1)+'M' : v>=1e3 ? '$'+Math.round(v/1e3)+'K' : '$'+Math.round(v);

/* ---- header ---- */
document.title = 'Trade Audit — ' + DATA.scenario;
document.getElementById('title').textContent = 'Trade Audit — ' + DATA.scenario;
document.getElementById('subtitle').textContent = DATA.subtitle;
document.getElementById('charthead').innerHTML =
  (DATA.has_benchmark ? 'NAV vs '+DATA.bench_label : 'Portfolio NAV') +
  ' <span class="note">' + (DATA.has_benchmark?'both start at initial cash &middot; ':'') + 'log scale &middot; weekly samples</span>';

/* ---- KPIs ---- */
document.getElementById('kpis').innerHTML = DATA.kpis.map(k =>
  `<div class="kpi${k[3]?' hero':''}"><span>${k[0]}</span><b>${k[1]}</b><small>${k[2]}</small></div>`).join('');

/* ---- xy helpers shared by the two time-series charts ---- */
function yearTicks(y0, y1) {
  const span = y1 - y0, step = span > 20 ? 5 : span > 8 ? 2 : 1, out = [];
  for (let yr = Math.ceil(y0/step)*step; yr <= y1; yr += step) out.push(yr);
  return out;
}

/* ---- NAV chart (log scale, crosshair tooltip; benchmark optional) ---- */
const svg = document.getElementById('chart'), wrap = document.getElementById('chartwrap'), tip = document.getElementById('tip');
const HB = DATA.has_benchmark;
function niceLogGrid(vmin, vmax) {
  const g = [];
  for (let e = Math.floor(Math.log10(vmin)); e <= Math.ceil(Math.log10(vmax)); e++)
    for (const m of [1, 3]) { const v = m * Math.pow(10, e); if (v >= vmin && v <= vmax) g.push(v); }
  return g;
}
function drawChart() {
  const C = DATA.curve, n = C.length;
  if (n < 2) return;
  const W = wrap.clientWidth, H = 380, mL = 62, mR = HB ? 88 : 20, mT = 14, mB = 28;
  const pw = W - mL - mR, ph = H - mT - mB;
  const t0 = new Date(C[0][0]).getTime(), t1 = new Date(C[n-1][0]).getTime();
  let lo = Infinity, hi = -Infinity;
  for (const p of C) for (let i = 1; i < p.length; i++) { if (p[i] < lo) lo = p[i]; if (p[i] > hi) hi = p[i]; }
  const pad = 0.06 * (Math.log10(hi) - Math.log10(lo) || 1);
  const vmin = Math.pow(10, Math.log10(lo) - pad), vmax = Math.pow(10, Math.log10(hi) + pad);
  const x = d => mL + pw * (new Date(d).getTime() - t0) / (t1 - t0 || 1);
  const y = v => mT + ph * (1 - (Math.log10(Math.max(v, vmin)) - Math.log10(vmin)) / (Math.log10(vmax) - Math.log10(vmin)));
  let g = '';
  for (const v of niceLogGrid(vmin, vmax))
    g += `<line x1="${mL}" x2="${W-mR}" y1="${y(v)}" y2="${y(v)}" stroke="var(--line)" stroke-width="1"/>` +
         `<text x="${mL-8}" y="${y(v)+4}" text-anchor="end">${fmtAxis(v)}</text>`;
  for (const yr of yearTicks(new Date(C[0][0]).getFullYear(), new Date(C[n-1][0]).getFullYear()))
    g += `<text x="${x(yr+'-01-03')}" y="${H-8}" text-anchor="middle">${yr}</text>`;
  const path = idx => C.map((p, i) => (i?'L':'M') + x(p[0]).toFixed(1) + ' ' + y(p[idx]).toFixed(1)).join('');
  if (HB) g += `<path d="${path(2)}" fill="none" stroke="var(--bench)" stroke-width="2" stroke-linejoin="round"/>`;
  g += `<path d="${path(1)}" fill="none" stroke="var(--strat)" stroke-width="2" stroke-linejoin="round"/>`;
  if (HB) {
    g += `<text class="serieslabel" x="${W-mR+8}" y="${y(C[n-1][1])+4}" fill="var(--strat)">Strategy</text>`;
    g += `<text class="serieslabel" x="${W-mR+8}" y="${y(C[n-1][2])+4}" fill="var(--bench)">${DATA.bench_label}</text>`;
  }
  g += `<line id="xhair" x1="0" x2="0" y1="${mT}" y2="${H-mB}" stroke="var(--ink-3)" stroke-width="1" visibility="hidden"/>`;
  g += `<circle id="dot1" r="4" fill="var(--strat)" stroke="var(--surface)" stroke-width="2" visibility="hidden"/>`;
  if (HB) g += `<circle id="dot2" r="4" fill="var(--bench)" stroke="var(--surface)" stroke-width="2" visibility="hidden"/>`;
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`); svg.innerHTML = g;
  const ids = HB ? ['xhair','dot1','dot2'] : ['xhair','dot1'];
  const hide = () => { tip.style.display='none'; for (const id of ids) { const e=document.getElementById(id); if(e) e.setAttribute('visibility','hidden'); } };
  svg.onmousemove = ev => {
    const r = svg.getBoundingClientRect(), px = (ev.clientX - r.left) * (W / r.width);
    if (px < mL || px > W - mR) { hide(); return; }
    const tt = t0 + (px - mL) / pw * (t1 - t0);
    let a = 0, b = n-1;
    while (b - a > 1) { const m = (a+b)>>1; (new Date(C[m][0]).getTime() < tt) ? a = m : b = m; }
    const p = C[b], cx = x(p[0]);
    document.getElementById('xhair').setAttribute('visibility','visible');
    document.getElementById('xhair').setAttribute('x1',cx); document.getElementById('xhair').setAttribute('x2',cx);
    const d1 = document.getElementById('dot1'); d1.setAttribute('visibility','visible'); d1.setAttribute('cx',cx); d1.setAttribute('cy',y(p[1]));
    if (HB) { const d2 = document.getElementById('dot2'); d2.setAttribute('visibility','visible'); d2.setAttribute('cx',cx); d2.setAttribute('cy',y(p[2])); }
    tip.style.display = 'block';
    tip.innerHTML = `${p[0]}<br>Strategy <b>${fmtM(p[1])}</b>` + (HB ? `<br>${DATA.bench_label} <b>${fmtM(p[2])}</b>` : '');
    tip.style.left = Math.min(px + 14, W - 180) + 'px'; tip.style.top = (y(p[1]) - 40) + 'px';
  };
  svg.onmouseleave = hide;
}
drawChart(); addEventListener('resize', drawChart);

/* ---- Capital-utilization area chart (only when a bar source supplied it) ---- */
const usvg = document.getElementById('utilchart'), uwrap = document.getElementById('utilwrap'), utip = document.getElementById('utiltip');
function drawUtil() {
  const C = DATA.curve, U = DATA.util, n = C.length;
  if (!U || n < 2) return;
  const W = uwrap.clientWidth, H = 200, mL = 62, mR = HB ? 88 : 20, mT = 10, mB = 26;
  const pw = W - mL - mR, ph = H - mT - mB;
  const t0 = new Date(C[0][0]).getTime(), t1 = new Date(C[n-1][0]).getTime();
  const umax = 110;
  const x = d => mL + pw * (new Date(d).getTime() - t0) / (t1 - t0 || 1);
  const y = v => mT + ph * (1 - Math.min(v, umax) / umax);
  let g = '';
  for (const v of [0, 50, 100])
    g += `<line x1="${mL}" x2="${W-mR}" y1="${y(v)}" y2="${y(v)}" stroke="var(--line)"/>` +
         `<text x="${mL-8}" y="${y(v)+4}" text-anchor="end">${v}%</text>`;
  for (const yr of yearTicks(new Date(C[0][0]).getFullYear(), new Date(C[n-1][0]).getFullYear()))
    g += `<text x="${x(yr+'-01-03')}" y="${H-6}" text-anchor="middle">${yr}</text>`;
  const pts = C.map((p, i) => [x(p[0]), y(U[i] ?? 0)]);
  const line = pts.map((p, i) => (i?'L':'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join('');
  g += `<path d="${line} L ${pts[n-1][0].toFixed(1)} ${y(0)} L ${pts[0][0].toFixed(1)} ${y(0)} Z" fill="var(--strat)" opacity="0.12" stroke="none"/>`;
  g += `<path d="${line}" fill="none" stroke="var(--strat)" stroke-width="1.5" stroke-linejoin="round"/>`;
  usvg.setAttribute('viewBox', `0 0 ${W} ${H}`); usvg.innerHTML = g;
  usvg.onmousemove = ev => {
    const r = usvg.getBoundingClientRect(), px = (ev.clientX - r.left) * (W / r.width);
    if (px < mL || px > W - mR) { utip.style.display='none'; return; }
    const idx = Math.min(n-1, Math.max(0, Math.round((px - mL) / pw * (n-1))));
    utip.style.display='block';
    utip.innerHTML = `${C[idx][0]}<br>deployed <b>${(U[idx] ?? 0).toFixed(1)}%</b>`;
    utip.style.left = Math.min(px + 12, W - 150) + 'px'; utip.style.top = (y(U[idx] ?? 0) - 34) + 'px';
  };
  usvg.onmouseleave = () => { utip.style.display='none'; };
}
if (DATA.util) {
  for (const id of ['utilhead','utilwrap']) document.getElementById(id).classList.remove('hidden');
  drawUtil(); addEventListener('resize', drawUtil);
}

/* ---- Open positions ---- */
if (DATA.opens.length) {
  for (const id of ['openhead','openwrap','openfoot']) document.getElementById(id).classList.remove('hidden');
  const totVal = DATA.opens.reduce((s,o)=>s+o[5],0), totUnrl = DATA.opens.reduce((s,o)=>s+o[6],0);
  document.getElementById('opens').innerHTML =
    '<thead><tr><th>Symbol</th><th>Entry date</th><th class="num">Entry px</th><th class="num">Qty</th><th class="num">Mark</th><th class="num">Value</th><th class="num">Unrealized</th><th class="num">Gain</th><th class="num">% of NAV</th></tr></thead><tbody>' +
    DATA.opens.map(o => `<tr><td><b>${o[0]}</b></td><td>${o[1]}</td><td class="num">$${o[2].toFixed(2)}</td><td class="num">${o[3].toLocaleString()}</td><td class="num">$${o[4].toFixed(2)}</td><td class="num">${fmt$(o[5])}</td><td class="num ${o[6]>=0?'pos':'neg'}">${fmt$(o[6])}</td><td class="num ${o[7]>=0?'pos':'neg'}">${pct(o[7])}</td><td class="num">${DATA.final_nav?(100*o[5]/DATA.final_nav).toFixed(1):'0.0'}%</td></tr>`).join('') +
    `<tr><td colspan="5"><b>Total (${DATA.opens.length} positions)</b></td><td class="num"><b>${fmt$(totVal)}</b></td><td class="num ${totUnrl>=0?'pos':'neg'}"><b>${fmt$(totUnrl)}</b></td><td></td><td class="num"><b>${DATA.final_nav?(100*totVal/DATA.final_nav).toFixed(1):'0.0'}%</b></td></tr></tbody>`;
  const mtmPct = DATA.final_nav ? (100*totVal/DATA.final_nav).toFixed(0) : '0';
  document.getElementById('openfoot').textContent =
    `Cash + other: ${fmtM(DATA.final_nav - totVal)} of ${fmtM(DATA.final_nav)} NAV — ${mtmPct}% of terminal NAV is mark-to-market.` +
    (DATA.stale_held.length ? ` Stale-held (delisted / zero-marked): ${DATA.stale_held.join(', ')}.` : '');
}

/* ---- Behavioural + conformance panels ---- */
if (DATA.conformance || DATA.behavioral.length || DATA.decision) {
  for (const id of ['panelhead','panels']) document.getElementById(id).classList.remove('hidden');
  if (DATA.conformance) {
    document.getElementById('confhead').textContent = `Weinstein conformance — spirit score ${DATA.conformance.spirit}`;
    document.getElementById('conftbl').innerHTML =
      '<tr><th>Rule</th><th>Pass rate</th><th class="num">Fails</th></tr>' +
      DATA.conformance.rules.map(r => `<tr><td>${r[0]}</td><td>${r[1]}</td><td class="num">${r[2]}</td></tr>`).join('');
  }
  document.getElementById('behav').innerHTML = DATA.behavioral.map(b => `<li>${b}</li>`).join('');
  if (DATA.decision) {
    document.getElementById('dechead').textContent =
      `Decision quality — ${DATA.decision.total} trades, ${DATA.decision.overall} win`;
    document.getElementById('dectbl').innerHTML =
      '<tr><th>Cascade quartile</th><th class="num">Trades</th><th class="num">Wins</th><th class="num">Win rate</th></tr>' +
      DATA.decision.quartiles.map(q => `<tr><td>${q[0]}</td><td class="num">${q[1]}</td><td class="num">${q[2]}</td><td class="num">${q[3]}</td></tr>`).join('');
  }
}

/* ---- Sortable / filterable trades table ---- */
document.getElementById('tradenote').textContent = `click a column header to sort · ${DATA.trades.length.toLocaleString()} trades`;
const COLS = [
  ['Symbol',0,'s'],['Entry',1,'s'],['Exit',2,'s'],['Days',3,'n'],['Entry px',4,'n'],['Exit px',5,'n'],
  ['Qty',6,'n'],['PnL $',7,'n'],['PnL %',8,'n'],['Exit trigger',9,'s'],['Stage',10,'s'],['Stop kind',11,'s'],['Score',12,'n']];
let sortCol = 1, sortDir = 1, rows = DATA.trades.slice();
const tbl = document.getElementById('trades');
const trigSel = document.getElementById('ftrig');
[...new Set(DATA.trades.map(t=>t[9]).filter(Boolean))].sort().forEach(v => trigSel.insertAdjacentHTML('beforeend', `<option>${v}</option>`));
function renderTrades() {
  const fs = document.getElementById('fsym').value.trim().toUpperCase();
  const ft = trigSel.value, fw = document.getElementById('fwin').value;
  rows = DATA.trades.filter(t =>
    (!fs || t[0].toUpperCase().includes(fs)) && (!ft || t[9]===ft) &&
    (!fw || (fw==='w' ? t[7]>0 : t[7]<=0)));
  rows.sort((a,b) => { const x=a[sortCol], z=b[sortCol]; return (x<z?-1:x>z?1:0)*sortDir; });
  const head = '<thead><tr>' + COLS.map(c =>
    `<th class="${c[2]==='n'?'num':''}" data-i="${c[1]}">${c[0]}<span class="arrow">${sortCol===c[1]?(sortDir>0?'▲':'▼'):''}</span></th>`).join('') + '</tr></thead>';
  const body = '<tbody>' + rows.map(t =>
    `<tr><td><b>${t[0]}</b></td><td>${t[1]}</td><td>${t[2]}</td><td class="num">${t[3]}</td>` +
    `<td class="num">$${t[4].toFixed(2)}</td><td class="num">$${t[5].toFixed(2)}</td><td class="num">${t[6].toLocaleString()}</td>` +
    `<td class="num ${t[7]>=0?'pos':'neg'}">${fmt$(t[7])}</td><td class="num ${t[8]>=0?'pos':'neg'}">${pct(t[8])}</td>` +
    `<td><span class="chip">${t[9]||'—'}</span></td><td>${t[10]||'—'}</td><td>${t[11]||'—'}</td><td class="num">${t[12]===null?'—':t[12]}</td></tr>`).join('') + '</tbody>';
  tbl.innerHTML = head + body;
  const sumP = rows.reduce((s,t)=>s+t[7],0), w = rows.filter(t=>t[7]>0).length;
  document.getElementById('count').textContent =
    `${rows.length} trades · ${w} winners (${rows.length?(100*w/rows.length).toFixed(1):0}%) · net ${fmtM(sumP)}`;
  tbl.querySelectorAll('th').forEach(th => th.onclick = () => {
    const i = +th.dataset.i;
    if (sortCol === i) sortDir = -sortDir; else { sortCol = i; sortDir = 1; }
    renderTrades();
  });
}
for (const id of ['fsym','ftrig','fwin']) document.getElementById(id).addEventListener('input', renderTrades);
renderTrades();
</script>
</body>
</html>
|js}
