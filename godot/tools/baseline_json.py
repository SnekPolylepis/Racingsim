"""Turn raw suite output in docs/rebuild/baseline/*.txt into docs/rebuild/baseline.json.

Run from godot/:  python tools/baseline_json.py
Each PASS/FAIL line becomes {"status", "text", "values"} where values are the numbers in the line,
in order. Lap and showcase lines are parsed into named fields. The raw .txt files stay authoritative.
"""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "rebuild" / "baseline"
OUT = ROOT / "docs" / "rebuild" / "baseline.json"
# A minus sign counts only when it does not follow a word character, so "0-100" is 0 and 100.
NUM = re.compile(r"(?<![\w.])-?\d+(?:\.\d+)?|(?<=\w)\d+(?:\.\d+)?")
LAP = re.compile(r"^(Simulation|Simcade) (\S+) best=([\d.]+) offSteps=(\d+) ghost=(\d+) barriers=(\d+) contacts=(\d+)")


def parse(path):
    checks, laps, showcase, summary = [], [], [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith(("PASS ", "FAIL ")):
            text = line[4:].strip()
            checks.append({"status": line[:4], "text": text, "values": [float(v) for v in NUM.findall(text)]})
        elif m := LAP.match(line):
            laps.append(
                {
                    "model": m[1],
                    "track": m[2],
                    "best_s": float(m[3]),
                    "off_steps": int(m[4]),
                    "ghost_samples": int(m[5]),
                    "barrier_segments": int(m[6]),
                    "contacts": int(m[7]),
                }
            )
        elif line.startswith("SHOWCASE LAP "):
            showcase.append(json.loads(line[len("SHOWCASE LAP ") :]))
        elif line.startswith("VALIDATION RESULTS "):
            summary = json.loads(line[len("VALIDATION RESULTS ") :])
        elif re.search(r"\b(PASS|FAIL)\b", line) and not line.startswith("Godot Engine"):
            summary = line
    entry = {"checks": checks}
    if laps:
        entry["laps"] = laps
    if showcase:
        entry["showcase"] = showcase
    if summary is not None:
        entry["summary"] = summary
    entry["failures"] = [c["text"] for c in checks if c["status"] == "FAIL"]
    return entry


def main():
    suites = {p.stem: parse(p) for p in sorted(RAW.glob("*.txt"))}
    doc = {
        "captured": "2026-09-22",
        "git_tag": "pre-rebuild",
        "engine": "Godot 4.6.2.stable.official.71f334935",
        "note": "Pre-rebuild equivalence targets (REBUILD-PLAN.md section 6). Raw output in baseline/*.txt.",
        "suites": suites,
    }
    OUT.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    for name, s in suites.items():
        print(f"{name}: {len(s['checks'])} checks, {len(s['failures'])} failures, {len(s.get('laps', []))} laps")


if __name__ == "__main__":
    main()
