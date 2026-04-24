#!/usr/bin/env python3
"""Generate a comparative Markdown report for a perf hypothesis test.

Workstream C2 of dev/plans/backtest-perf-2026-04-24.md. Invoked from
dev/scripts/run_perf_hypothesis.sh after both Legacy and Tiered runs
have produced their per-strategy artifacts.

Reads (from the hypothesis output dir):
  legacy.peak_rss_kb    integer kB or "UNAVAILABLE"
  tiered.peak_rss_kb    same
  legacy.log            full stdout+stderr
  tiered.log            same
  legacy.trace.sexp     list of phase_metrics records (see
                        trading/trading/backtest/lib/trace.mli)
  tiered.trace.sexp     same

Emits to stdout: a Markdown report with two tables:
  1. Top-level summary: peak RSS, final portfolio value, round-trip
     count, total PnL, ratio.
  2. Per-phase rollup: phase name, elapsed_ms (Legacy / Tiered / delta).

The trace sexp parser is hand-rolled because the only Python sexp
library available without network access is whatever ships with the
container, and the trace shape is fixed enough that a 60-line tokenizer
beats a dependency. The shape is exactly what
`Backtest.Trace.write` emits via `sexp_of_phase_metrics`:

  ((phase Load_universe)
   (elapsed_ms 12)
   (symbols_in (302))
   (symbols_out (302))
   (peak_rss_kb (148228))
   (bar_loads ()))

i.e. each record is an alist; option fields wrap their value in a list
(`()` for None, `(v)` for Some v).
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Sexp parsing — hand-rolled, scoped strictly to the Trace.write shape.
# ---------------------------------------------------------------------------


def _tokenize(text: str):
    """Yield '(', ')', and atom strings from a sexp text."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
            continue
        if c in "()":
            yield c
            i += 1
            continue
        # Atom: read up to whitespace or paren.
        j = i
        while j < n and not text[j].isspace() and text[j] not in "()":
            j += 1
        yield text[i:j]
        i = j


def _parse(tokens):
    """Parse a token stream into nested lists of strings.

    Returns the first complete sexp expression. Subsequent calls would
    parse further expressions, but the trace.sexp file holds exactly one
    top-level list, so a single call suffices.
    """
    tok = next(tokens)
    if tok == "(":
        result = []
        for tok in tokens:
            if tok == ")":
                return result
            if tok == "(":
                # Push back; recurse via a small wrapper.
                inner = _parse(_chain([tok], tokens))
                result.append(inner)
            else:
                result.append(tok)
        raise ValueError("unterminated sexp list")
    return tok


def _chain(prefix, rest):
    for t in prefix:
        yield t
    for t in rest:
        yield t


def _alist_get(record, key):
    """Look up `key` in an alist-shape sexp record and return the value sexp.

    Each entry in `record` is `[key, value]`. Returns the value (a string
    or a list) or None if the key isn't present.
    """
    for entry in record:
        if isinstance(entry, list) and len(entry) >= 2 and entry[0] == key:
            return entry[1] if len(entry) == 2 else entry[1:]
    return None


def _opt_int(value):
    """Parse a `(v)` option-style sexp into an int, or None for `()`."""
    if value is None:
        return None
    if isinstance(value, list):
        if not value:
            return None
        return int(value[0])
    # Bare scalar (shouldn't happen for option fields, but be lenient).
    return int(value)


def _parse_trace(path: Path):
    """Return a list of dicts: phase, elapsed_ms, symbols_in/out, peak_rss_kb, bar_loads."""
    if not path.is_file():
        return []
    text = path.read_text()
    parsed = _parse(_tokenize(text))
    out = []
    for rec in parsed:
        phase = _alist_get(rec, "phase")
        elapsed = _alist_get(rec, "elapsed_ms")
        out.append(
            {
                "phase": phase if isinstance(phase, str) else "?",
                "elapsed_ms": int(elapsed) if elapsed is not None else 0,
                "symbols_in": _opt_int(_alist_get(rec, "symbols_in")),
                "symbols_out": _opt_int(_alist_get(rec, "symbols_out")),
                "peak_rss_kb": _opt_int(_alist_get(rec, "peak_rss_kb")),
                "bar_loads": _opt_int(_alist_get(rec, "bar_loads")),
            }
        )
    return out


# ---------------------------------------------------------------------------
# Log scraping — pull a few well-known scalars from summary.sexp echoed
# on stdout by backtest_runner.exe.
# ---------------------------------------------------------------------------


_NUM_RE = r"[-+]?[0-9]+(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?"


def _scrape(log_text: str, key: str) -> Optional[str]:
    """Return the first numeric value paired with `(key ...)` in `log_text`,
    or None if not found."""
    pattern = rf"\({re.escape(key)}\s+({_NUM_RE})"
    m = re.search(pattern, log_text)
    return m.group(1) if m else None


def _read_log_summary(log_path: Path) -> dict:
    """Pull final_portfolio_value, n_round_trips, total_pnl, sharpe_ratio,
    max_drawdown, win_rate from a log.

    The summary sexp embeds metric values under fully-qualified module-name
    keys like `metric_types.metric_type.t.totalpnl`. We accept either the
    plain key (legacy field on the top-level summary record) or the
    dotted-suffix variant. First match wins.
    """
    if not log_path.is_file():
        return {}
    text = log_path.read_text()

    def _scrape_either(plain_key: str, suffix_key: str):
        return _scrape(text, plain_key) or _scrape(text, suffix_key)

    return {
        "final_portfolio_value": _scrape(text, "final_portfolio_value"),
        "n_round_trips": _scrape(text, "n_round_trips"),
        "total_pnl": _scrape_either("total_pnl", "metric_types.metric_type.t.totalpnl"),
        "sharpe_ratio": _scrape_either("sharpe_ratio", "metric_types.metric_type.t.sharperatio"),
        "max_drawdown": _scrape_either("max_drawdown", "metric_types.metric_type.t.maxdrawdown"),
        "win_rate": _scrape_either("win_rate", "metric_types.metric_type.t.winrate"),
    }


def _read_peak_rss(path: Path) -> Optional[int]:
    """Read kilobyte-int from a peak_rss_kb file, or None for missing/UNAVAILABLE."""
    if not path.is_file():
        return None
    raw = path.read_text().strip().splitlines()
    if not raw:
        return None
    first = raw[0].strip()
    if first == "UNAVAILABLE":
        return None
    try:
        return int(first)
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Markdown rendering.
# ---------------------------------------------------------------------------


def _fmt_int(n) -> str:
    if n is None:
        return "n/a"
    return f"{int(n):,}"


def _fmt_num(s) -> str:
    if s is None:
        return "n/a"
    return s


def _fmt_ratio(t, l) -> str:
    if t is None or l is None or l == 0:
        return "n/a"
    return f"{t / l:.3f}"


def _fmt_delta(t, l) -> str:
    if t is None or l is None:
        return "n/a"
    return f"{t - l:+,}"


def _scalar_row(label: str, key: str, legacy_log: dict, tiered_log: dict) -> str:
    """One-line row for a scalar metric scraped from each log. Delta and ratio
    are left as `n/a` for these — the harness's job is to surface the raw
    values; analyzing PnL deltas is a human-judgement task downstream."""
    return (
        f"| {label} | {_fmt_num(legacy_log.get(key))} | "
        f"{_fmt_num(tiered_log.get(key))} | n/a | n/a |"
    )


def _render_summary(args, legacy_rss, tiered_rss, legacy_log, tiered_log) -> str:
    rows = [
        f"# Perf hypothesis report: {args.hypothesis_id}",
        "",
        f"- **Scenario**: `{args.scenario}`",
        f"- **Period**  : {args.start_date} .. {args.end_date}",
        f"- **Override**: `{args.override or '(none)'}`",
        "",
        "## Top-level comparison",
        "",
        "| Metric | Legacy | Tiered | Delta | Ratio (T/L) |",
        "|---|---:|---:|---:|---:|",
        f"| Peak RSS (kB) | {_fmt_int(legacy_rss)} | {_fmt_int(tiered_rss)} | "
        f"{_fmt_delta(tiered_rss, legacy_rss)} | {_fmt_ratio(tiered_rss, legacy_rss)} |",
        _scalar_row("Final portfolio value", "final_portfolio_value", legacy_log, tiered_log),
        _scalar_row("Round trips", "n_round_trips", legacy_log, tiered_log),
        _scalar_row("Total PnL", "total_pnl", legacy_log, tiered_log),
        _scalar_row("Sharpe ratio", "sharpe_ratio", legacy_log, tiered_log),
        _scalar_row("Max drawdown %", "max_drawdown", legacy_log, tiered_log),
        _scalar_row("Win rate %", "win_rate", legacy_log, tiered_log),
        "",
    ]
    return "\n".join(rows)


def _render_phase_table(legacy_phases, tiered_phases) -> str:
    """Build a per-phase rollup. Joins phases by name, summing duplicates."""
    legacy_by_phase: dict = {}
    tiered_by_phase: dict = {}
    for p in legacy_phases:
        legacy_by_phase[p["phase"]] = legacy_by_phase.get(p["phase"], 0) + p["elapsed_ms"]
    for p in tiered_phases:
        tiered_by_phase[p["phase"]] = tiered_by_phase.get(p["phase"], 0) + p["elapsed_ms"]

    # Peak peak_rss_kb across the phase's records (only meaningful when
    # /proc/self/status is available — None on macOS).
    def _peak_rss(phases, name):
        vals = [p["peak_rss_kb"] for p in phases if p["phase"] == name and p["peak_rss_kb"] is not None]
        return max(vals) if vals else None

    all_phases = sorted(set(legacy_by_phase.keys()) | set(tiered_by_phase.keys()))
    if not all_phases:
        return "## Per-phase rollup\n\n_(no phases recorded — neither trace.sexp produced entries)_\n"

    rows = [
        "## Per-phase rollup",
        "",
        "Sums elapsed_ms across all records for each phase. Peak RSS is the max",
        "VmHWM observed at the end of any record for that phase. RSS is `None`",
        "on platforms without `/proc/self/status` (e.g. macOS).",
        "",
        "| Phase | Legacy elapsed_ms | Tiered elapsed_ms | Δ (T-L) | Legacy peak RSS kB | Tiered peak RSS kB |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name in all_phases:
        l_ms = legacy_by_phase.get(name, 0)
        t_ms = tiered_by_phase.get(name, 0)
        rows.append(
            f"| {name} | {_fmt_int(l_ms)} | {_fmt_int(t_ms)} | {_fmt_delta(t_ms, l_ms)} | "
            f"{_fmt_int(_peak_rss(legacy_phases, name))} | {_fmt_int(_peak_rss(tiered_phases, name))} |"
        )
    rows.append("")
    return "\n".join(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--hypothesis-id", required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--start-date", required=True)
    parser.add_argument("--end-date", required=True)
    parser.add_argument("--override", default="")
    args = parser.parse_args()

    out_dir: Path = args.out_dir
    legacy_rss = _read_peak_rss(out_dir / "legacy.peak_rss_kb")
    tiered_rss = _read_peak_rss(out_dir / "tiered.peak_rss_kb")
    legacy_log = _read_log_summary(out_dir / "legacy.log")
    tiered_log = _read_log_summary(out_dir / "tiered.log")
    legacy_phases = _parse_trace(out_dir / "legacy.trace.sexp")
    tiered_phases = _parse_trace(out_dir / "tiered.trace.sexp")

    summary = _render_summary(args, legacy_rss, tiered_rss, legacy_log, tiered_log)
    phases = _render_phase_table(legacy_phases, tiered_phases)
    sys.stdout.write(summary + "\n" + phases)
    return 0


if __name__ == "__main__":
    sys.exit(main())
