#!/usr/bin/env python3
"""Summarise traced kerb observations and compare Spa with its road profile."""

import json
from collections import Counter
from pathlib import Path


DATA = Path(__file__).resolve().parent.parent


def merge_ranges(ranges, gap=0.0):
    merged = []
    for start, end in sorted(ranges):
        if merged and start <= merged[-1][1] + gap:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    return merged


def uncovered_ranges(ranges, covered):
    """Return portions of ranges that do not overlap any covered interval."""
    result = []
    for start, end in ranges:
        pieces = [(start, end)]
        for cover_start, cover_end in covered:
            next_pieces = []
            for left, right in pieces:
                if cover_end <= left or cover_start >= right:
                    next_pieces.append((left, right))
                else:
                    if cover_start > left:
                        next_pieces.append((left, cover_start))
                    if cover_end < right:
                        next_pieces.append((cover_end, right))
            pieces = next_pieces
        result.extend(pieces)
    return result


def report(track):
    path = DATA / track / "kerbs.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    kerbs = data["kerbs"]
    types = Counter(item["type"] for item in kerbs)
    confidence = Counter(item["confidence"] for item in kerbs)
    length = sum(item["s_end"] - item["s_start"] for item in kerbs)
    print(f"{track}: {len(kerbs)} observations; {length:.0f} m total")
    print("  by type: " + ", ".join(f"{key}={types[key]}" for key in sorted(types)))
    print("  by confidence: " + ", ".join(f"{key}={confidence[key]}" for key in sorted(confidence)))


def spa_disagreements():
    observations = json.loads((DATA / "spa/kerbs.json").read_text(encoding="utf-8"))["kerbs"]
    profile = json.loads((DATA / "spa/road-profile.json").read_text(encoding="utf-8"))["stations"]
    step = min(b["s"] - a["s"] for a, b in zip(profile, profile[1:]))
    print("Spa disagreements >20 m (profile kerb vs orthophoto trace):")
    found = False
    for side, key in (("left", "kerb_left"), ("right", "kerb_right")):
        traced = merge_ranges(
            [(item["s_start"], item["s_end"]) for item in observations if item["side"] == side]
        )
        positive = [station for station in profile if station[key] > 0]
        profile_ranges = merge_ranges(
            [(station["s"] - step / 2, station["s"] + step / 2) for station in positive],
            gap=step,
        )
        for label, ranges in (("profile-only", uncovered_ranges(profile_ranges, traced)),
                              ("photo-only", uncovered_ranges(traced, profile_ranges))):
            for start, end in merge_ranges(ranges):
                if end - start > 20:
                    found = True
                    print(f"  {side} {label}: {start:.0f}-{end:.0f} m ({end-start:.0f} m)")
    if not found:
        print("  none")


if __name__ == "__main__":
    report("spa")
    report("nordschleife")
    spa_disagreements()
