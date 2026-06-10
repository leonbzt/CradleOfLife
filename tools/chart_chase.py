#!/usr/bin/env python3
"""Summarise / chart the chase-curve CSV dumped by tests/economy_test.gd.

This is the SANCTIONED use of Python in this project: charting and analysis only.
The economy itself lives in one place — the GDScript resolve()/accrue(). This
script never models the economy; it only reads what the harness produced.

Usage:
    python3 tools/chart_chase.py /path/to/chase.csv
The path is printed by the economy harness (it writes to Godot's user:// dir).
"""
import csv
import sys


def percentile(values, q):
    if not values:
        return 0
    s = sorted(values)
    idx = int(q * (len(s) - 1))
    return s[idx]


def sparkline(values):
    bars = "▁▂▃▄▅▆▇█"
    if not values:
        return ""
    lo, hi = min(values), max(values)
    span = (hi - lo) or 1
    return "".join(bars[min(len(bars) - 1, (v - lo) * (len(bars) - 1) // span)] for v in values)


def main(path):
    events, legendaries, dry_streaks = [], 0, []
    streak = 0  # check-ins since the last legendary (computed, not read from the CSV)
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            events.append(int(row["events"]))
            legs = int(row["legendaries"])
            legendaries += legs
            streak += 1
            for _ in range(legs):
                dry_streaks.append(streak)
                streak = 0

    n = len(events)
    print(f"check-ins:            {n}")
    print(f"mean events/check-in: {sum(events) / n:.2f}   (min {min(events)}, max {max(events)})")
    print(f"total legendaries:    {legendaries}")
    if dry_streaks:
        print(
            "dry streak (check-ins between legendaries): "
            f"p10={percentile(dry_streaks, 0.1)} "
            f"p50={percentile(dry_streaks, 0.5)} "
            f"p90={percentile(dry_streaks, 0.9)} "
            f"max={max(dry_streaks)}"
        )
    else:
        print("no legendaries in window — chase ceiling may be too high")

    # Compress to ~60 columns so the shape is visible at a glance.
    step = max(1, n // 60)
    compressed = [sum(events[i:i + step]) // step for i in range(0, n, step)]
    print("\nevents/check-in over time:")
    print("  " + sparkline(compressed))
    print("\nThe chase is healthy when this line stays roughly level (never decays")
    print("toward flat) and the dry-streak p90 stays inside a tolerable wait.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1])
