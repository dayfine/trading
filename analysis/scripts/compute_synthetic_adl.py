#!/usr/bin/env python3
"""Compute synthetic NYSE advance/decline data from the stock universe.

Reads daily close prices for all stocks in data/sectors.csv, computes
per-day advance and decline counts, writes synthetic breadth CSVs, and
validates against the existing golden breadth data.

Usage:
    python3 analysis/scripts/compute_synthetic_adl.py [--data-dir DATA_DIR]

The script expects to be run from the repo root (or pass --data-dir).
"""

import argparse
import csv
import math
import os
import sys
from collections import defaultdict


def load_symbols(sectors_path):
    """Read stock symbols from sectors.csv (symbol,sector header)."""
    symbols = []
    with open(sectors_path, "r") as f:
        reader = csv.reader(f)
        header = next(reader)
        assert header[0].strip().lower() == "symbol", f"Unexpected header: {header}"
        for row in reader:
            if row:
                symbols.append(row[0].strip())
    return symbols


def symbol_data_path(data_dir, symbol):
    """Return path to data/{first_char}/{last_char}/{SYMBOL}/data.csv."""
    if not symbol:
        return None
    first = symbol[0].upper()
    last = symbol[-1].upper()
    return os.path.join(data_dir, first, last, symbol, "data.csv")


def load_close_prices(path):
    """Load (date_str, close) pairs from a stock's data.csv.

    Returns list of (date_str, close_float) sorted by date ascending.
    Skips rows with missing or unparseable close prices.
    """
    prices = []
    with open(path, "r") as f:
        reader = csv.reader(f)
        header = next(reader)
        # Expected: date,open,high,low,close,adjusted_close,volume
        close_idx = None
        for i, col in enumerate(header):
            if col.strip().lower() == "close":
                close_idx = i
                break
        if close_idx is None:
            return prices

        for row in reader:
            if len(row) <= close_idx:
                continue
            date_str = row[0].strip()
            try:
                close = float(row[close_idx].strip())
                prices.append((date_str, close))
            except (ValueError, IndexError):
                continue

    prices.sort(key=lambda x: x[0])
    return prices


def compute_daily_changes(all_prices):
    """Compute per-date advance/decline/unchanged counts.

    Args:
        all_prices: dict of symbol -> [(date_str, close), ...]

    Returns:
        dict of date_str -> (advances, declines, unchanged, total)
        sorted by date.
    """
    # For each symbol, compute daily change direction
    # date -> [direction, ...] where direction is +1, -1, or 0
    date_directions = defaultdict(list)

    for symbol, prices in all_prices.items():
        if len(prices) < 2:
            continue
        for i in range(1, len(prices)):
            prev_date, prev_close = prices[i - 1]
            curr_date, curr_close = prices[i]
            if prev_close == 0:
                continue
            if curr_close > prev_close:
                date_directions[curr_date].append(1)
            elif curr_close < prev_close:
                date_directions[curr_date].append(-1)
            else:
                date_directions[curr_date].append(0)

    # Aggregate
    result = {}
    for date_str in sorted(date_directions.keys()):
        dirs = date_directions[date_str]
        advances = sum(1 for d in dirs if d > 0)
        declines = sum(1 for d in dirs if d < 0)
        unchanged = sum(1 for d in dirs if d == 0)
        result[date_str] = (advances, declines, unchanged, len(dirs))

    return result


def format_date_yyyymmdd(date_str):
    """Convert YYYY-MM-DD to YYYYMMDD."""
    return date_str.replace("-", "")


def write_breadth_csv(path, date_count_pairs):
    """Write breadth CSV in existing format: 'YYYYMMDD, count' (no header)."""
    with open(path, "w") as f:
        for date_str, count in date_count_pairs:
            yyyymmdd = format_date_yyyymmdd(date_str)
            f.write(f"{yyyymmdd}, {count}\n")


def load_golden_breadth(path):
    """Load existing breadth CSV. Returns dict of YYYYMMDD -> count."""
    data = {}
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(",")
            if len(parts) != 2:
                continue
            date_str = parts[0].strip()
            try:
                count = int(parts[1].strip())
                if count > 0:  # skip zero-count entries
                    data[date_str] = count
            except ValueError:
                continue
    return data


def pearson_correlation(xs, ys):
    """Compute Pearson correlation coefficient."""
    n = len(xs)
    if n == 0:
        return 0.0
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    cov = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    var_x = sum((x - mean_x) ** 2 for x in xs)
    var_y = sum((y - mean_y) ** 2 for y in ys)
    denom = math.sqrt(var_x * var_y)
    if denom == 0:
        return 0.0
    return cov / denom


def mean_absolute_error(xs, ys):
    """Compute mean absolute error."""
    if not xs:
        return 0.0
    return sum(abs(x - y) for x, y in zip(xs, ys)) / len(xs)


def validate_against_golden(synthetic, golden, label):
    """Compare synthetic data against golden data for overlapping dates.

    Args:
        synthetic: dict of YYYYMMDD -> count
        golden: dict of YYYYMMDD -> count
        label: "advances" or "declines"

    Returns:
        (correlation, mae, overlap_count)
    """
    overlap_dates = sorted(set(synthetic.keys()) & set(golden.keys()))
    if not overlap_dates:
        print(f"  No overlapping dates for {label}")
        return 0.0, 0.0, 0

    syn_vals = [synthetic[d] for d in overlap_dates]
    gold_vals = [golden[d] for d in overlap_dates]

    corr = pearson_correlation(syn_vals, gold_vals)
    mae = mean_absolute_error(syn_vals, gold_vals)

    print(f"\n  {label}:")
    print(f"    Overlapping dates: {len(overlap_dates)}")
    print(f"    Date range: {overlap_dates[0]} - {overlap_dates[-1]}")
    print(f"    Synthetic mean: {sum(syn_vals)/len(syn_vals):.1f}")
    print(f"    Golden mean:    {sum(gold_vals)/len(gold_vals):.1f}")
    print(f"    Pearson correlation: {corr:.4f}")
    print(f"    Mean absolute error: {mae:.1f}")

    return corr, mae, len(overlap_dates)


def main():
    parser = argparse.ArgumentParser(
        description="Compute synthetic advance/decline data"
    )
    parser.add_argument(
        "--data-dir",
        default="data",
        help="Path to data directory (default: data)",
    )
    args = parser.parse_args()
    data_dir = args.data_dir

    sectors_path = os.path.join(data_dir, "sectors.csv")
    if not os.path.exists(sectors_path):
        print(f"Error: {sectors_path} not found", file=sys.stderr)
        sys.exit(1)

    # Step 1: Load universe
    symbols = load_symbols(sectors_path)
    print(f"Universe: {len(symbols)} symbols from sectors.csv")

    # Step 2: Load close prices for all symbols
    print("Loading daily close prices...")
    all_prices = {}
    missing = 0
    for symbol in symbols:
        path = symbol_data_path(data_dir, symbol)
        if path and os.path.exists(path):
            prices = load_close_prices(path)
            if prices:
                all_prices[symbol] = prices
        else:
            missing += 1

    print(
        f"Loaded prices for {len(all_prices)} symbols "
        f"({missing} missing data files)"
    )

    # Step 3: Compute daily advances/declines
    print("Computing daily advance/decline counts...")
    daily = compute_daily_changes(all_prices)

    # Filter to dates with at least 100 stocks reporting
    min_stocks = 100
    filtered = {
        d: v for d, v in daily.items() if v[3] >= min_stocks
    }
    print(
        f"Total trading days: {len(daily)}, "
        f"with >= {min_stocks} stocks: {len(filtered)}"
    )

    if not filtered:
        print("Error: no dates with sufficient data", file=sys.stderr)
        sys.exit(1)

    sorted_dates = sorted(filtered.keys())
    print(f"Date range: {sorted_dates[0]} to {sorted_dates[-1]}")

    # Step 4: Write output CSVs
    breadth_dir = os.path.join(data_dir, "breadth")
    os.makedirs(breadth_dir, exist_ok=True)

    advn_path = os.path.join(breadth_dir, "synthetic_advn.csv")
    decln_path = os.path.join(breadth_dir, "synthetic_decln.csv")

    advn_pairs = [(d, filtered[d][0]) for d in sorted_dates]
    decln_pairs = [(d, filtered[d][1]) for d in sorted_dates]

    write_breadth_csv(advn_path, advn_pairs)
    write_breadth_csv(decln_path, decln_pairs)

    print(f"\nWrote {advn_path} ({len(advn_pairs)} rows)")
    print(f"Wrote {decln_path} ({len(decln_pairs)} rows)")

    # Step 5: Validate against golden data
    golden_advn_path = os.path.join(breadth_dir, "nyse_advn.csv")
    golden_decln_path = os.path.join(breadth_dir, "nyse_decln.csv")

    if not os.path.exists(golden_advn_path):
        print(f"\nSkipping validation: {golden_advn_path} not found")
        return

    print("\n--- Validation against golden NYSE breadth data ---")

    golden_advn = load_golden_breadth(golden_advn_path)
    golden_decln = load_golden_breadth(golden_decln_path)

    # Build synthetic lookup by YYYYMMDD
    syn_advn = {format_date_yyyymmdd(d): filtered[d][0] for d in sorted_dates}
    syn_decln = {format_date_yyyymmdd(d): filtered[d][1] for d in sorted_dates}

    corr_a, mae_a, n_a = validate_against_golden(
        syn_advn, golden_advn, "Advances"
    )
    corr_d, mae_d, n_d = validate_against_golden(
        syn_decln, golden_decln, "Declines"
    )

    # Net breadth (advances - declines) correlation
    overlap_dates = sorted(
        set(syn_advn.keys())
        & set(golden_advn.keys())
        & set(syn_decln.keys())
        & set(golden_decln.keys())
    )
    if overlap_dates:
        syn_net = [syn_advn[d] - syn_decln[d] for d in overlap_dates]
        gold_net = [golden_advn[d] - golden_decln[d] for d in overlap_dates]
        net_corr = pearson_correlation(syn_net, gold_net)
        net_mae = mean_absolute_error(syn_net, gold_net)
        print(f"\n  Net breadth (advances - declines):")
        print(f"    Pearson correlation: {net_corr:.4f}")
        print(f"    Mean absolute error: {net_mae:.1f}")

    print("\n--- Summary ---")
    print(f"Advance correlation:    {corr_a:.4f} (n={n_a})")
    print(f"Decline correlation:    {corr_d:.4f} (n={n_d})")
    if overlap_dates:
        print(f"Net breadth correlation: {net_corr:.4f}")
    print()


if __name__ == "__main__":
    main()
