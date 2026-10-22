// Diagnostic policies, not book-prescribed thresholds or a strategy verdict.
// Portfolio size is scored against a 10% reference weight; top-k P&L shares
// describe fat-tail dependence and are not penalised. Recovery uses the page's
// existing "many entries" reference (6 per 13 weeks). No blended overall score.
const CareerScorecard = (() => {
  const POLICY = { weightPct: 10, reopenEntries: 6 };
  const rules = [
    ['bear', 'Bear defense', '2.1', 'Mean of check-7 pass rate and share of DOWN years matching/beating SPY.'],
    ['selection', 'Selection', '4.1–4.4, 3.1', 'Pooled observed pass rate of checks 1, 5, 6, 8.'],
    ['volume', 'Volume', '4.2', 'Pooled observed pass rate of checks 3, 4.'],
    ['risk', 'Stop / risk', '5.1, 4.7', 'Mean of checks 10/11 pass rate and observed fills not above limit.'],
    ['riding', 'Riding winners', '5.2, 5.6', 'Mean of check-12 pass rate and payoff/(1+payoff); healthy-sale evidence is unavailable and not scored.'],
    ['portfolio', 'Portfolio construction', '5.1', '100 × min(1, 10 / average weight %); top-k shares are descriptive, with no concentration penalty.'],
    ['recovery', 'Recovery playbook', '2.1, 4.1', 'Mean of min(entries in 13 weeks / 6, 1) across complete gate-reopen episodes.'],
    ['shorts', 'Shorts', '6.1', 'Shorts enabled: 100 for fills with positive P&L, 50 for flat P&L, 0 for losses or zero fills.']
  ];
  const num = v => typeof v === 'number' && Number.isFinite(v);
  const fmt = v => Number(v.toFixed(2)).toString();
  const mean = vs => vs.every(num) && vs.length ? vs.reduce((a,b) => a+b,0) / vs.length : null;
  function checks(f, ids) {
    const xs = f?.available && Array.isArray(f.rows) ? f.rows.flatMap(t => t.checks || []).filter(c => ids.includes(c.id) && ['pass','fail'].includes(c.status)) : [];
    const pass = xs.filter(c => c.status === 'pass').length;
    return { n:xs.length, pass, score:xs.length ? 100*pass/xs.length : null, why:`checks ${ids.join('/')} ${pass}/${xs.length} observed pass` };
  }
  function detector(f, key) {
    const xs = f?.available && Array.isArray(f.rows) ? f.rows.map(t => t.detectors?.[key]).filter(x => typeof x === 'boolean') : [];
    const hits = xs.filter(Boolean).length;
    return { n:xs.length, hits, score:xs.length ? 100*(xs.length-hits)/xs.length : null };
  }
  function score(input = {}) {
    const f=input.faithfulness, all=input.anatomy?.available ? input.anatomy.rows?.find(r => r.year === 'All') : null;
    const c7=checks(f,[7]), selection=checks(f,[1,5,6,8]), volume=checks(f,[3,4]), risk=checks(f,[10,11]), exit=checks(f,[12]);
    const above=detector(f,'above');
    const down=Array.isArray(input.downPeriods) ? input.downPeriods : [];
    const downKnown=down.length && down.every(p => num(p.ret) && num(p.spy));
    const beaten=downKnown ? down.filter(p => p.ret >= p.spy).length : 0;
    const eps=Array.isArray(input.episodes) ? input.episodes : [];
    const epsKnown=eps.length && eps.every(e => Number.isInteger(e.e13) && e.e13 >= 0);
    const payoff=num(all?.payoff) && all.payoff >= 0 ? 100*all.payoff/(1+all.payoff) : null;
    const portfolio=num(all?.weight) && all.weight > 0 && ['top5','top10','top20'].every(k => num(all[k]));
    const short=input.meta?.short_leg;
    const shorts=short && Number.isInteger(short.fills) && short.fills >= 0 && num(short.pnl);
    const values = {
      bear: [mean([c7.score, downKnown ? 100*beaten/down.length : null]), `${c7.why}; DOWN ${beaten}/${down.length} years ≥ SPY (${down.filter(p => num(p.ret) && num(p.spy)).map(p => `${p.period}: ${fmt(p.ret)}% vs ${fmt(p.spy)}%`).join('; ') || 'n/a'})`],
      selection: [selection.score, selection.why], volume: [volume.score, volume.why],
      risk: [mean([risk.score,above.score]), `${risk.why}; filled from above ${above.hits}/${above.n} observed`],
      riding: [mean([exit.score,payoff]), `${exit.why}; healthy-sale evidence unavailable (detector cannot read true), not scored; payoff ${num(all?.payoff) ? fmt(all.payoff) : 'n/a'}`],
      portfolio: [portfolio ? 100*Math.min(1,POLICY.weightPct/all.weight) : null, `average weight ${num(all?.weight) ? fmt(all.weight) : 'n/a'}% (reference ${POLICY.weightPct}%); top-5/10/20 shares ${['top5','top10','top20'].map(k => num(all?.[k]) ? fmt(all[k])+'%' : 'n/a').join('/')} (no concentration penalty)`],
      recovery: [epsKnown ? 100*eps.reduce((s,e) => s+Math.min(e.e13/POLICY.reopenEntries,1),0)/eps.length : null, `13-week entries ${eps.map(e => `${e.d}: ${num(e.e13) ? e.e13 : 'n/a'}`).join('; ') || 'n/a'}; reference ${POLICY.reopenEntries} per episode`],
      shorts: [shorts ? (short.fills > 0 ? (short.pnl > 0 ? 100 : short.pnl === 0 ? 50 : 0) : 0) : null, short ? `short fills ${num(short.fills) ? short.fills : 'n/a'}; short P&L $${num(short.pnl) ? fmt(short.pnl) : 'n/a'}` : 'shorts disabled or parameters unavailable']
    };
    const rows=rules.map(([id,name,section,policy]) => ({id,name,section,policy,score:values[id][0],because:values[id][0] == null ? `n/a — required evidence unavailable; ${values[id][1]}` : `Because ${values[id][1]}`}));
    return { rows, scored:rows.filter(r => r.score != null).length };
  }
  // Same compounded daily returns, split by calendar year, as the page's era
  // regime cells. Each day's lagged regime is supplied by spyRegimeByDay.
  function downPeriods(nav, spy, regime) {
    if (!Array.isArray(nav) || !Array.isArray(spy) || nav.length < 2 || nav.length !== spy.length || !regime) return null;
    const years=new Map();
    for (let i=1;i<nav.length;i++) {
      if (nav[i][0] !== spy[i][0] || nav[i-1][0] !== spy[i-1][0]) return null;
      if (regime.get(nav[i][0]) !== 'DOWN') continue;
      if (![nav[i][1],nav[i-1][1],spy[i][1],spy[i-1][1]].every(v => num(v) && v>0)) return null;
      const y=nav[i][0].slice(0,4), r=years.get(y) || {period:y,nav:1,spy:1,days:0};
      r.nav*=nav[i][1]/nav[i-1][1]; r.spy*=spy[i][1]/spy[i-1][1]; r.days++; years.set(y,r);
    }
    return [...years.values()].map(r => ({period:r.period,ret:100*(r.nav-1),spy:100*(r.spy-1),days:r.days}));
  }
  return { score, downPeriods, POLICY };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = CareerScorecard;
