#!/usr/bin/env python3
"""Scrape GICS sector metadata for US large/mid-cap stocks from Wikipedia.

Sources (each has a table with a Symbol/Ticker column and a GICS Sector
column):

- List of S&P 500 companies  (~503 rows)
- List of S&P 400 companies  (~400 rows)
- List of S&P 600 companies  (~603 rows)
- Russell 1000 Index         (~1006 rows)

The union is the Weinstein-screener-relevant universe (~1,500-1,700 unique
US stocks). The 11 SPDR sector ETFs (XLK, XLF, etc.) are appended as a
hardcoded table — they are not on these index lists.

Usage:
    python3 fetch_sectors.py [--output data/sectors.csv]

Output format (UTF-8, no header on purpose — the OCaml loader allows
optional header):
    symbol,sector
    AAPL,Information Technology
    XLK,Technology
    ...

No third-party dependencies — uses only the Python stdlib (urllib +
html.parser), because the Docker container does not ship pandas.

Wikipedia table structure: the relevant tables have either id="constituents"
(S&P lists) or are the first sortable wikitable on the Russell 1000 page.
The parser walks every <table class="wikitable"> and picks the first one
whose header row contains both a "Symbol"/"Ticker" column and a
"GICS Sector" column. That is resilient to header renames and table
reordering.
"""

from __future__ import annotations

import argparse
import csv
import html
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Optional

USER_AGENT = (
    "trading-1-sector-scraper/1.0 "
    "(+https://github.com/dayfine/trading; contact: devs)"
)

SOURCES = [
    (
        "S&P 500",
        "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies",
    ),
    (
        "S&P 400",
        "https://en.wikipedia.org/wiki/List_of_S%26P_400_companies",
    ),
    (
        "S&P 600",
        "https://en.wikipedia.org/wiki/List_of_S%26P_600_companies",
    ),
    (
        "Russell 1000",
        "https://en.wikipedia.org/wiki/Russell_1000_Index",
    ),
]

# The 11 SPDR sector ETFs — Weinstein uses these as sector proxies in the
# screener. They are not on the Wikipedia index lists, so we hardcode them.
SPDR_SECTOR_ETFS = [
    ("XLK", "Technology"),
    ("XLF", "Financials"),
    ("XLE", "Energy"),
    ("XLV", "Health Care"),
    ("XLI", "Industrials"),
    ("XLP", "Consumer Staples"),
    ("XLY", "Consumer Discretionary"),
    ("XLU", "Utilities"),
    ("XLB", "Materials"),
    ("XLRE", "Real Estate"),
    ("XLC", "Communication Services"),
]


class WikiTableParser(HTMLParser):
    """Extract rows from every <table class="wikitable"> on the page.

    Each table is returned as a list[list[str]] where row 0 is the header.
    We keep all wikitables — the caller decides which one contains the
    sector mapping by inspecting the headers.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tables: list[list[list[str]]] = []
        self._in_wikitable = 0  # depth counter (tables can nest)
        self._current_table: Optional[list[list[str]]] = None
        self._current_row: Optional[list[str]] = None
        self._current_cell_parts: Optional[list[str]] = None
        # Skip text inside sup/style/script tags — they contain footnote
        # markers like "[1]" that pollute cell values.
        self._skip_depth = 0

    # ---- table / row / cell boundaries ----

    def handle_starttag(self, tag: str, attrs: list[tuple[str, Optional[str]]]) -> None:
        attr_map = {k: (v or "") for k, v in attrs}
        if tag == "table":
            classes = attr_map.get("class", "").split()
            if "wikitable" in classes:
                self._in_wikitable += 1
                if self._in_wikitable == 1:
                    self._current_table = []
        elif self._in_wikitable and tag == "tr":
            self._current_row = []
        elif self._in_wikitable and tag in ("td", "th"):
            self._current_cell_parts = []
        elif tag in ("sup", "style", "script"):
            self._skip_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in ("sup", "style", "script") and self._skip_depth > 0:
            self._skip_depth -= 1
            return
        if tag in ("td", "th") and self._current_cell_parts is not None:
            cell = " ".join("".join(self._current_cell_parts).split())
            if self._current_row is not None:
                self._current_row.append(cell)
            self._current_cell_parts = None
        elif tag == "tr" and self._current_row is not None:
            if self._current_table is not None and self._current_row:
                self._current_table.append(self._current_row)
            self._current_row = None
        elif tag == "table" and self._in_wikitable:
            self._in_wikitable -= 1
            if self._in_wikitable == 0 and self._current_table is not None:
                self.tables.append(self._current_table)
                self._current_table = None

    def handle_data(self, data: str) -> None:
        if self._skip_depth > 0:
            return
        if self._current_cell_parts is not None:
            self._current_cell_parts.append(data)


def _fetch(url: str) -> str:
    """GET a URL with a descriptive User-Agent (Wikipedia blocks default UA)."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _find_sector_table(tables: list[list[list[str]]]) -> Optional[list[list[str]]]:
    """Pick the first table whose header has a ticker column + GICS Sector.

    The Wikipedia layouts differ slightly:
    - S&P lists label the ticker column "Symbol"
    - Russell 1000 labels it "Ticker" or "Symbol"
    Both label the sector column "GICS Sector".
    """
    for table in tables:
        if not table:
            continue
        headers = [h.strip().lower() for h in table[0]]
        symbol_idx = None
        sector_idx = None
        for idx, header in enumerate(headers):
            if symbol_idx is None and header in ("symbol", "ticker"):
                symbol_idx = idx
            if sector_idx is None and "gics sector" in header:
                sector_idx = idx
        if symbol_idx is not None and sector_idx is not None:
            return [[row[symbol_idx], row[sector_idx]] for row in table[1:]
                    if len(row) > max(symbol_idx, sector_idx)]
    return None


def _normalize_symbol(sym: str) -> str:
    """Wikipedia sometimes formats BRK.B as 'BRK.B' or 'BRK/B' — normalize
    to the dot form used by EODHD. Strip footnote leftovers and whitespace."""
    sym = html.unescape(sym).strip().upper()
    sym = sym.replace("/", ".")
    # Drop any trailing footnote artefacts like "[a]" that escaped the sup tag
    if "[" in sym:
        sym = sym.split("[", 1)[0]
    return sym.strip()


def scrape_source(name: str, url: str) -> list[tuple[str, str]]:
    print(f"Fetching {name} from {url}", file=sys.stderr)
    html_text = _fetch(url)
    parser = WikiTableParser()
    parser.feed(html_text)
    rows = _find_sector_table(parser.tables)
    if not rows:
        print(
            f"  WARN: could not find sector table on {name}; skipping",
            file=sys.stderr,
        )
        return []
    result: list[tuple[str, str]] = []
    for row in rows:
        sym = _normalize_symbol(row[0])
        sector = row[1].strip()
        if sym and sector:
            result.append((sym, sector))
    print(f"  {name}: {len(result)} rows", file=sys.stderr)
    return result


def build_sector_map() -> dict[str, str]:
    """Union all sources — first occurrence wins for duplicates.

    Sources are scraped in order [S&P 500, S&P 400, S&P 600, Russell 1000],
    so a ticker that appears in multiple indices keeps the S&P 500 sector
    label if present. In practice the GICS sector is identical across
    indices so this only matters for edge cases."""
    merged: dict[str, str] = {}
    for name, url in SOURCES:
        for sym, sector in scrape_source(name, url):
            merged.setdefault(sym, sector)
    for sym, sector in SPDR_SECTOR_ETFS:
        merged.setdefault(sym, sector)
    return merged


def write_csv(path: Path, mapping: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = sorted(mapping.items(), key=lambda kv: kv[0])
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["symbol", "sector"])
        writer.writerows(rows)
    print(f"Wrote {len(rows)} rows to {path}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default="data/sectors.csv",
        help="Output CSV path (default: data/sectors.csv)",
    )
    args = parser.parse_args()
    mapping = build_sector_map()
    write_csv(Path(args.output), mapping)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
