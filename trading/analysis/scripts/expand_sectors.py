#!/usr/bin/env python3
"""Expand sectors.csv with GICS sector data from EODHD fundamentals API.

For each ticker that has cached price data but is NOT yet in sectors.csv,
queries the EODHD fundamentals endpoint to get the GICS sector, then appends
new entries to sectors.csv.

Usage:
    python3 expand_sectors.py --data-dir /path/to/data --api-key KEY [--batch-size 100]

The EODHD fundamentals endpoint:
    GET https://eodhd.com/api/fundamentals/{SYMBOL}.US?api_token={KEY}&filter=General&fmt=json

Rate limiting: 0.2s delay between requests to stay within EODHD limits.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# EODHD uses slightly different sector names than GICS canonical names.
SECTOR_NORMALIZATION = {
    "Technology": "Information Technology",
    "Healthcare": "Health Care",
    "Consumer Cyclical": "Consumer Discretionary",
    "Consumer Defensive": "Consumer Staples",
    "Basic Materials": "Materials",
    "Financial Services": "Financials",
}

# Sectors that already match GICS names (no normalization needed).
VALID_GICS_SECTORS = {
    "Energy",
    "Materials",
    "Industrials",
    "Consumer Discretionary",
    "Consumer Staples",
    "Health Care",
    "Financials",
    "Information Technology",
    "Communication Services",
    "Utilities",
    "Real Estate",
}


def _read_existing_sectors(sectors_path: Path) -> set[str]:
    """Read sectors.csv and return the set of tickers already mapped."""
    if not sectors_path.exists():
        return set()
    tickers = set()
    with sectors_path.open("r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if header is None:
            return set()
        for row in reader:
            if row:
                tickers.add(row[0])
    return tickers


def _scan_data_tickers(data_dir: Path) -> set[str]:
    """Scan the data directory tree to find all tickers with cached data.

    Data is stored at data/{first_letter}/{second_letter}/{symbol}/data.csv.
    """
    tickers = set()
    for first in sorted(data_dir.iterdir()):
        if not first.is_dir() or first.name in ("breadth",):
            continue
        # Skip non-letter directories and files
        if len(first.name) != 1 or not first.name.isalpha():
            continue
        for second in sorted(first.iterdir()):
            if not second.is_dir():
                continue
            for symbol_dir in sorted(second.iterdir()):
                if not symbol_dir.is_dir():
                    continue
                data_csv = symbol_dir / "data.csv"
                if data_csv.exists():
                    tickers.add(symbol_dir.name)
    return tickers


def _normalize_sector(raw_sector: str) -> str | None:
    """Normalize an EODHD sector name to GICS canonical name.

    Returns None if the sector is empty or unrecognized.
    """
    sector = raw_sector.strip()
    if not sector:
        return None
    # Check normalization map first
    if sector in SECTOR_NORMALIZATION:
        return SECTOR_NORMALIZATION[sector]
    # Already a valid GICS name
    if sector in VALID_GICS_SECTORS:
        return sector
    # Unknown sector - return as-is but warn
    return sector


def _fetch_sector(symbol: str, api_key: str) -> str | None:
    """Fetch GICS sector for a symbol from EODHD fundamentals API.

    Returns the normalized sector name, or None on failure.
    """
    # Most symbols are US-listed
    exchange = "US"
    if "." in symbol:
        # Handle non-US symbols like ISF.LSE
        parts = symbol.rsplit(".", 1)
        if len(parts) == 2 and parts[1] in ("LSE", "INDX"):
            return None  # Skip non-US symbols

    url = (
        f"https://eodhd.com/api/fundamentals/{symbol}.{exchange}"
        f"?api_token={api_key}&filter=General&fmt=json"
    )

    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError):
        return None
    except Exception:
        return None

    if not isinstance(data, dict):
        return None

    raw_sector = data.get("Sector", "")
    if not raw_sector:
        # Try GicSector field as fallback
        raw_sector = data.get("GicSector", "")

    return _normalize_sector(raw_sector)


def _append_to_sectors_csv(
    sectors_path: Path, new_entries: list[tuple[str, str]]
) -> None:
    """Append new (symbol, sector) entries to sectors.csv, maintaining sort."""
    # Read existing entries
    existing: list[tuple[str, str]] = []
    if sectors_path.exists():
        with sectors_path.open("r", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader, None)
            for row in reader:
                if len(row) >= 2:
                    existing.append((row[0], row[1]))

    # Merge and sort
    all_entries = existing + new_entries
    all_entries.sort(key=lambda kv: kv[0])

    # Write back
    with sectors_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["symbol", "sector"])
        writer.writerows(all_entries)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-dir",
        required=True,
        help="Path to the data directory",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("EODHD_API_KEY", ""),
        help="EODHD API key (default: $EODHD_API_KEY)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=0,
        help="Max symbols to process (0 = all)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.2,
        help="Delay between API requests in seconds (default: 0.2)",
    )
    args = parser.parse_args()

    if not args.api_key:
        print(
            "ERROR: No API key provided. Set EODHD_API_KEY or use --api-key.",
            file=sys.stderr,
        )
        return 1

    data_dir = Path(args.data_dir)
    sectors_path = data_dir / "sectors.csv"

    # Step 1: Read existing sectors
    existing_tickers = _read_existing_sectors(sectors_path)
    print(
        f"Existing sectors.csv: {len(existing_tickers)} tickers",
        file=sys.stderr,
    )

    # Step 2: Scan data directory for all tickers
    all_tickers = _scan_data_tickers(data_dir)
    print(
        f"Data directory: {len(all_tickers)} tickers with cached data",
        file=sys.stderr,
    )

    # Step 3: Find tickers not yet in sectors.csv
    missing = sorted(all_tickers - existing_tickers)

    # Filter out non-US symbols (those with dots like .INDX, .LSE)
    # and numeric-prefixed symbols (fund IDs like 0P000070L2)
    missing = [
        t
        for t in missing
        if "." not in t and t[0:1].isalpha()
    ]

    print(
        f"Missing from sectors.csv: {len(missing)} tickers",
        file=sys.stderr,
    )

    if args.batch_size > 0:
        missing = missing[: args.batch_size]
        print(
            f"Processing batch of {len(missing)} tickers",
            file=sys.stderr,
        )

    # Step 4: Fetch sectors from EODHD
    new_entries: list[tuple[str, str]] = []
    errors = 0

    for i, ticker in enumerate(missing):
        if i > 0 and i % 100 == 0:
            print(
                f"  Progress: {i}/{len(missing)} processed, "
                f"{len(new_entries)} found, {errors} errors",
                file=sys.stderr,
            )

        sector = _fetch_sector(ticker, args.api_key)
        if sector:
            new_entries.append((ticker, sector))
        else:
            errors += 1

        if args.delay > 0 and i < len(missing) - 1:
            time.sleep(args.delay)

    # Step 5: Append to sectors.csv
    if new_entries:
        _append_to_sectors_csv(sectors_path, new_entries)

    # Print summary
    print(f"\n=== Summary ===", file=sys.stderr)
    print(f"Processed: {len(missing)} tickers", file=sys.stderr)
    print(f"New sectors found: {len(new_entries)}", file=sys.stderr)
    print(f"Failed/skipped: {errors}", file=sys.stderr)
    print(
        f"Total in sectors.csv: {len(existing_tickers) + len(new_entries)}",
        file=sys.stderr,
    )

    # Print sector distribution of new entries
    if new_entries:
        sector_counts: dict[str, int] = {}
        for _, sector in new_entries:
            sector_counts[sector] = sector_counts.get(sector, 0) + 1
        print(f"\nNew entries by sector:", file=sys.stderr)
        for sector, count in sorted(sector_counts.items()):
            print(f"  {sector}: {count}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
