#!/usr/bin/env python3
"""Generate the aggregate Markdown report for a perf sweep.

Companion to ``dev/scripts/run_perf_sweep.sh``. Walks the sweep output
directory, collects per-cell ``peak_rss_kb`` + per-cell wall-time +
per-cell ``trace.sexp`` for both Legacy and Tiered strategies, and emits
a Markdown report containing:

  1. Top-level matrix table
     Rows = N (universe cap), columns = T (run length).
     Cells = "L_RSS / T_RSS / ratio" — peak RSS in MB plus the
     Tiered/Legacy ratio.
  2. N-sweep complexity table (at fixed T = 1y)
     One row per N, two columns (Legacy / Tiered) for both peak RSS and
     wall time. Includes a coarse linear slope estimate
     (RSS_max - RSS_min) / (N_max - N_min) at the table extremes.
  3. T-sweep complexity table (at fixed N = 300)
     Same shape, with T parameterised by trading days (~21 / month).
  4. Wall-time matrix
     Same shape as table 1, but cells are seconds.
  5. Failure note
     Lists every cell that errored (timeout, OOM, parse-error, ...).

The slope estimates are intentionally coarse — readers want the curve
shape (linear? quadratic?), not regression statistics. If a richer
analysis is needed, drop the raw artifacts into a notebook.

Wall time is scraped from ``/usr/bin/time -f '%M'`` output. ``%M``
captures only RSS, not wall time, so the sweep driver doesn't currently
emit a separate wall-time file. We extract wall time from the
``trace.sexp`` instead by summing ``elapsed_ms`` across all phases —
that's the runner's own measurement of total backtest work and should be
within a few percent of process wall time for the well-instrumented
phases (trace coverage is best-effort and may understate teardown
overhead; documented in the report).

The trace sexp parser is hand-rolled and shared in shape (but not in
code) with ``perf_hypothesis_report.py`` — keeping this script
self-contained avoids a Python module dependency between two ad-hoc
helpers; if a third script wants the same parser, lift it then.
"""

import argparse
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Sexp parsing — hand-rolled. Shape mirrors perf_hypothesis_report.py.
# ---------------------------------------------------------------------------


def _tokenize(text: str):
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
        j = i
        while j < n and not text[j].isspace() and text[j] not in "()":
            j += 1
        yield text[i:j]
        i = j


def _parse(tokens):
    tok = next(tokens)
    if tok == "(":
        result = []
        for tok in tokens:
            if tok == ")":
                return result
            if tok == "(":
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
    for entry in record:
        if isinstance(entry, list) and len(entry) >= 2 and entry[0] == key:
            return entry[1] if len(entry) == 2 else entry[1:]
    return None


def _parse_trace(path: Path):
    """Return [{phase, elapsed_ms}, ...] from a trace.sexp, or [] if missing."""
    if not path.is_file():
        return []
    try:
        text = path.read_text()
        parsed = _parse(_tokenize(text))
    except (StopIteration, ValueError):
        return []
    out = []
    for rec in parsed:
        phase = _alist_get(rec, "phase")
        elapsed = _alist_get(rec, "elapsed_ms")
        out.append(
            {
                "phase": phase if isinstance(phase, str) else "?",
                "elapsed_ms": int(elapsed) if elapsed is not None else 0,
            }
        )
    return out


# ---------------------------------------------------------------------------
# Per-cell artifact reading.
# ---------------------------------------------------------------------------


def _read_peak_rss_kb(path: Path) -> Optional[int]:
    """Return integer kB from ``/usr/bin/time -f '%M'``, or None.

    Returns None if the file is missing, contains "UNAVAILABLE", or fails
    to parse — callers render None as "n/a" in the matrix.
    """
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


def _wall_time_ms(trace_path: Path) -> Optional[int]:
    """Sum elapsed_ms across all phases in a trace.sexp."""
    phases = _parse_trace(trace_path)
    if not phases:
        return None
    return sum(p["elapsed_ms"] for p in phases)


def _has_error(cell_dir: Path, strategy: str) -> Optional[str]:
    """Return the error-file contents if the cell errored, else None."""
    err = cell_dir / f"{strategy}.error"
    if not err.is_file():
        return None
    return err.read_text().strip()


# ---------------------------------------------------------------------------
# Sweep cell layout — must match the CELLS array in run_perf_sweep.sh.
# ---------------------------------------------------------------------------


# (N, T_label, T_trading_days_est) — trading-days estimate is used only for
# the slope arithmetic in the T-sweep complexity table. ~63/126/252/756 are
# the canonical "3m/6m/1y/3y" bucket midpoints.
CELLS = [
    (100, "1y", 252),
    (300, "1y", 252),
    (500, "1y", 252),
    (1000, "1y", 252),
    (300, "3m", 63),
    (300, "6m", 126),
    (300, "3y", 756),
    (1000, "3y", 756),
]

T_DAYS = {"3m": 63, "6m": 126, "1y": 252, "3y": 756}
T_ORDER = ["3m", "6m", "1y", "3y"]
N_ORDER = [100, 300, 500, 1000]
STRATEGIES = ["legacy", "tiered"]


# ---------------------------------------------------------------------------
# Cell-data collection.
# ---------------------------------------------------------------------------


def _collect(sweep_dir: Path):
    """Return {(N, T_label): {strategy: {rss_kb, wall_ms, error}}}."""
    out: dict = {}
    for n, t_label, _ in CELLS:
        cell_dir = sweep_dir / f"{n}-{t_label}"
        cell: dict = {}
        for strat in STRATEGIES:
            cell[strat] = {
                "rss_kb": _read_peak_rss_kb(cell_dir / f"{strat}.peak_rss_kb"),
                "wall_ms": _wall_time_ms(cell_dir / f"{strat}.trace.sexp"),
                "error": _has_error(cell_dir, strat),
            }
        out[(n, t_label)] = cell
    return out


# ---------------------------------------------------------------------------
# Formatting helpers.
# ---------------------------------------------------------------------------


def _mb(kb: Optional[int]) -> str:
    if kb is None:
        return "n/a"
    return f"{kb / 1024:.0f}MB"


def _sec(ms: Optional[int]) -> str:
    if ms is None:
        return "n/a"
    return f"{ms / 1000:.1f}s"


def _ratio(t: Optional[int], legacy: Optional[int]) -> str:
    if t is None or legacy is None or legacy == 0:
        return "n/a"
    return f"{t / legacy:.2f}x"


def _slope(y_hi: Optional[int], y_lo: Optional[int], x_hi: int, x_lo: int) -> str:
    """Coarse slope at table extremes. Units depend on caller."""
    if y_hi is None or y_lo is None or x_hi == x_lo:
        return "n/a"
    return f"{(y_hi - y_lo) / (x_hi - x_lo):+.2f}"


# ---------------------------------------------------------------------------
# Tables.
# ---------------------------------------------------------------------------


def _matrix_table(
    title: str,
    cell_data: dict,
    cell_render,
) -> str:
    """Render a matrix with rows = N, columns = T (only the cells we ran).

    cell_render(cell) -> string for the (Legacy / Tiered / ratio) cell text.
    Cells we didn't run (e.g. N=100 × T=3y) render as "—".
    """
    rows = [f"## {title}", ""]
    rows.append("| N \\ T | " + " | ".join(T_ORDER) + " |")
    rows.append("|---:|" + "---:|" * len(T_ORDER))
    ran = {(n, t) for n, t, _ in CELLS}
    for n in N_ORDER:
        cells = []
        for t in T_ORDER:
            if (n, t) in ran:
                cells.append(cell_render(cell_data[(n, t)]))
            else:
                cells.append("—")
        rows.append(f"| **{n}** | " + " | ".join(cells) + " |")
    rows.append("")
    return "\n".join(rows)


def _rss_cell(cell: dict) -> str:
    legacy = cell["legacy"]["rss_kb"]
    tiered = cell["tiered"]["rss_kb"]
    return f"{_mb(legacy)} / {_mb(tiered)} / {_ratio(tiered, legacy)}"


def _wall_cell(cell: dict) -> str:
    legacy = cell["legacy"]["wall_ms"]
    tiered = cell["tiered"]["wall_ms"]
    return f"{_sec(legacy)} / {_sec(tiered)} / {_ratio(tiered, legacy)}"


def _n_sweep_table(cell_data: dict) -> str:
    """N-sweep at fixed T=1y."""
    rows = [
        "## N-sweep complexity (T = 1y)",
        "",
        "Peak RSS and wall time as N (universe cap) grows. Slope row is the",
        "linear extreme-fit `(y[N=1000] - y[N=100]) / (1000 - 100)` — coarse,",
        "but tells you whether RSS scales sub-linearly, linearly, or worse.",
        "",
        "| N | Legacy RSS | Tiered RSS | Tiered/Legacy | Legacy wall | Tiered wall |",
        "|---:|---:|---:|---:|---:|---:|",
    ]
    for n in N_ORDER:
        cell = cell_data[(n, "1y")]
        rows.append(
            "| {n} | {lr} | {tr} | {ratio} | {lw} | {tw} |".format(
                n=n,
                lr=_mb(cell["legacy"]["rss_kb"]),
                tr=_mb(cell["tiered"]["rss_kb"]),
                ratio=_ratio(cell["tiered"]["rss_kb"], cell["legacy"]["rss_kb"]),
                lw=_sec(cell["legacy"]["wall_ms"]),
                tw=_sec(cell["tiered"]["wall_ms"]),
            )
        )
    legacy_lo = cell_data[(100, "1y")]["legacy"]["rss_kb"]
    legacy_hi = cell_data[(1000, "1y")]["legacy"]["rss_kb"]
    tiered_lo = cell_data[(100, "1y")]["tiered"]["rss_kb"]
    tiered_hi = cell_data[(1000, "1y")]["tiered"]["rss_kb"]
    rows.append(
        "| **slope (kB / N)** | {l} | {t} | — | — | — |".format(
            l=_slope(legacy_hi, legacy_lo, 1000, 100),
            t=_slope(tiered_hi, tiered_lo, 1000, 100),
        )
    )
    rows.append("")
    return "\n".join(rows)


def _t_sweep_table(cell_data: dict) -> str:
    """T-sweep at fixed N=300."""
    rows = [
        "## T-sweep complexity (N = 300)",
        "",
        "Peak RSS and wall time as T (run length, in trading days) grows.",
        "Slope row is the linear extreme-fit `(y[3y] - y[3m]) / (756 - 63)` —",
        "useful for separating per-bar work from one-shot setup overhead.",
        "",
        "| T | days | Legacy RSS | Tiered RSS | Tiered/Legacy | Legacy wall | Tiered wall |",
        "|:---|---:|---:|---:|---:|---:|---:|",
    ]
    for t_label in T_ORDER:
        cell = cell_data[(300, t_label)]
        rows.append(
            "| {t} | {d} | {lr} | {tr} | {ratio} | {lw} | {tw} |".format(
                t=t_label,
                d=T_DAYS[t_label],
                lr=_mb(cell["legacy"]["rss_kb"]),
                tr=_mb(cell["tiered"]["rss_kb"]),
                ratio=_ratio(cell["tiered"]["rss_kb"], cell["legacy"]["rss_kb"]),
                lw=_sec(cell["legacy"]["wall_ms"]),
                tw=_sec(cell["tiered"]["wall_ms"]),
            )
        )
    legacy_lo = cell_data[(300, "3m")]["legacy"]["rss_kb"]
    legacy_hi = cell_data[(300, "3y")]["legacy"]["rss_kb"]
    tiered_lo = cell_data[(300, "3m")]["tiered"]["rss_kb"]
    tiered_hi = cell_data[(300, "3y")]["tiered"]["rss_kb"]
    rows.append(
        "| **slope (kB / day)** | — | {l} | {t} | — | — | — |".format(
            l=_slope(legacy_hi, legacy_lo, 756, 63),
            t=_slope(tiered_hi, tiered_lo, 756, 63),
        )
    )
    rows.append("")
    return "\n".join(rows)


def _failure_section(cell_data: dict) -> str:
    failed = []
    for n, t_label, _ in CELLS:
        for strat in STRATEGIES:
            err = cell_data[(n, t_label)][strat]["error"]
            if err is not None:
                failed.append(f"- N={n} T={t_label} {strat}: {err}")
    if not failed:
        return "## Failures\n\n_None — every cell completed cleanly._\n"
    return "## Failures\n\n" + "\n".join(failed) + "\n"


# ---------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sweep-dir", required=True, type=Path)
    parser.add_argument("--sweep-id", required=True)
    args = parser.parse_args()

    sweep_dir: Path = args.sweep_dir
    if not sweep_dir.is_dir():
        print(f"FAIL: sweep directory not found: {sweep_dir}", file=sys.stderr)
        return 1

    cell_data = _collect(sweep_dir)

    parts = [
        f"# Perf sweep report: {args.sweep_id}",
        "",
        f"Sweep dir: `{sweep_dir}`",
        "",
        "Cells = (N universe cap) × (T run length) × (Legacy | Tiered loader).",
        "Each matrix cell shows `Legacy_RSS / Tiered_RSS / ratio`. RSS values",
        "come from `/usr/bin/time -f '%M'` (kilobytes, rendered as MB).",
        "Wall time comes from the runner's own `--trace` sexp, summing",
        "`elapsed_ms` across all phases — that's the canonical work time and",
        "should be within a few percent of process wall time.",
        "",
        _matrix_table("Peak RSS matrix (Legacy / Tiered / ratio)", cell_data, _rss_cell),
        _n_sweep_table(cell_data),
        _t_sweep_table(cell_data),
        _matrix_table("Wall-time matrix (Legacy / Tiered / ratio)", cell_data, _wall_cell),
        _failure_section(cell_data),
    ]
    sys.stdout.write("\n".join(parts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
