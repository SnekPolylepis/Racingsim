#!/usr/bin/env python3
"""
Triage failed gate suites: why did each one fail, and what should happen next?

Reads a gate log folder (tools/run_gates.ps1 writes tests/logs/gates/<stamp>/, tools/ci_gates.py writes
tests/logs/ci/), finds the failed suites with run_gates.ps1's pass rule as far as the logs show it (a
RESULTS line with no failures and an empty stderr; exit codes are not logged), and gives each a cause and an
action:

  SCRIPT_ERROR     GDScript parse/runtime error in the log (decided in code, no model call)
  REGRESSION       a behavioural check failed: fix the code, or queue a fix task
  PERF_CONTENTION  a timing check failed in a parallel run: re-run the suite alone with timing gated
  PERF_REGRESSION  a timing check failed when the suite ran alone: real slowdown, fix it
  BASELINE_DRIFT   a result moved slightly off a recorded baseline: decide fix or re-baseline
  STDERR_WARNING   every check passed but stderr has warnings: fix the warning or queue it
  ASSET_OR_IMPORT  a resource, file or import is missing or broken
  ENVIRONMENT      tooling, engine or machine problem rather than the project
  UNCLEAR          none of the above fit

Every cause except SCRIPT_ERROR comes from TypeSafe Jev (one Choice question per suite, all in one request).
An answer below --min-confidence is reported as "needs a person" rather than acted on. Jev never decides
whether a suite passed: that is the log's job.

Needs TYPESAFE_API_KEY in the environment (never written to logs). --dry-run prints the request instead.
Writes <logs>/triage.json. Exit 0 when nothing failed, 1 when something failed, 2 on usage or API errors.
"""

import argparse
import glob
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

API_URL = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"

CAUSES = {
    "REGRESSION": "A behavioural check failed: a physics, track, race or game result is wrong or out of "
    "tolerance in a way that points at the code under test.",
    "PERF_CONTENTION": "Only a timing or budget check (µs per tick, bake seconds) failed, and the suite ran "
    "in parallel with other suites, so the slow reading may come from machine load.",
    "PERF_REGRESSION": "A timing or budget check failed while the suite ran alone with timing gated, so the "
    "code really is slower than its budget.",
    "BASELINE_DRIFT": "A result differs by a small amount from a recorded baseline value (lap times, "
    "reference curves), and the check exists to catch drift rather than a broken behaviour.",
    "STDERR_WARNING": "Every check passed, but stderr contains warnings or errors that make the run count "
    "as failed.",
    "ASSET_OR_IMPORT": "A resource, scene, data file or import is missing, cannot be loaded, or is broken.",
    "ENVIRONMENT": "The failure comes from the machine or tooling: engine crash, missing executable or "
    "driver, out of memory, file permissions, a timeout with no sign of a project fault.",
    "UNCLEAR": "The evidence does not fit any other option or is too thin to tell.",
}

ACTIONS = {
    "SCRIPT_ERROR": "fix the script error (see stderr)",
    "REGRESSION": "fix the code, or add a fix row to QUEUE.md",
    "PERF_CONTENTION": "re-run alone with timing gated (run_gates.ps1 -Perf)",
    "PERF_REGRESSION": "profile and fix the slowdown",
    "BASELINE_DRIFT": "decide: fix the change, or re-record the baseline with a REBUILD-LOG note",
    "STDERR_WARNING": "fix the warning, or queue it with its cause",
    "ASSET_OR_IMPORT": "check the resource path and export include_filter",
    "ENVIRONMENT": "fix the machine or tooling, then re-run",
    "UNCLEAR": "needs a person",
}

SCRIPT_ERROR_RE = re.compile(r"SCRIPT ERROR|Parse Error|RESULTS aborted by a script error")
TIMING_RE = re.compile(r"µs|\bus per tick|budget", re.IGNORECASE)


def tail(text, lines, chars):
    kept = "\n".join(text.replace("\r\n", "\n").rstrip().splitlines()[-lines:])
    return kept[-chars:]


def read(path):
    if not os.path.isfile(path):
        return ""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def newest_logs(godot_dir):
    candidates = glob.glob(os.path.join(godot_dir, "tests", "logs", "gates", "*")) + [
        os.path.join(godot_dir, "tests", "logs", "ci")
    ]
    candidates = [c for c in candidates if os.path.isdir(c) and glob.glob(os.path.join(c, "*.out"))]
    return max(candidates, key=os.path.getmtime) if candidates else None


def load_suites(godot_dir):
    with open(os.path.join(godot_dir, "tools", "gates.json"), "r", encoding="utf-8") as f:
        manifest = json.load(f)
    return {re.sub(r"[^A-Za-z0-9_-]", "_", s["name"]): s for s in manifest.get("suites", [])}


def collect_failures(logs_dir, suites):
    """One entry per failed log pair, judged with run_gates.ps1's rule."""
    failed = []
    for out_path in sorted(glob.glob(os.path.join(logs_dir, "*.out"))):
        stem = os.path.basename(out_path)[: -len(".out")]
        alone = stem.endswith(".perf")
        safe = stem[: -len(".perf")] if alone else stem
        suite = suites.get(safe)
        if suite is None:
            continue  # import.out and other non-suite logs
        out_text = read(out_path)
        err_text = read(out_path[: -len(".out")] + ".err")

        failures = None
        checks = None
        if suite.get("kind") != "parse":
            lines = [ln for ln in out_text.splitlines() if " RESULTS {" in ln]
            if lines:
                try:
                    data = json.loads(lines[-1][lines[-1].find("{") :])
                    failures = [str(x) for x in data.get("failures", [])]
                    checks = data.get("checks")
                except ValueError:
                    pass
        stderr_empty = not err_text.strip()
        if suite.get("kind") == "parse":
            ok = stderr_empty
        else:
            ok = failures is not None and not failures and stderr_empty
        if ok:
            continue

        failed.append(
            {
                "suite": suite["name"] + (" (alone, timing gated)" if alone else ""),
                "evidence": {
                    "suite": suite["name"],
                    "kind": suite.get("kind", "v2"),
                    "has_timing_checks": bool(suite.get("perf")),
                    "ran_alone_with_timing_gated": alone,
                    "checks": checks,
                    "results_line_found": failures is not None,
                    "failed_checks": (failures or [])[:12],
                    "stderr_tail": tail(err_text, 30, 3000),
                    "stdout_tail": "" if failures else tail(out_text, 20, 2000),
                },
            }
        )
    return failed


def build_request(pending):
    questions = {}
    for i, item in enumerate(pending):
        questions["q%d" % i] = {
            "type": "choice",
            "instructions": (
                "Why did the Godot test suite in `suites.s%d` fail? Use its failed checks and log tails. "
                "`ran_alone_with_timing_gated` true means timing was measured with no other suites running. "
                "Pick the single most likely cause." % i
            ),
            "criteria": CAUSES,
        }
    state = {
        "project": "Racing Sim, a Godot 4 racing game with a fixed 240 Hz physics step",
        "suites": {"s%d" % i: item["evidence"] for i, item in enumerate(pending)},
    }
    return {"state": state, "model": MODEL, "questions": questions}


def ask_jev(body, key, attempts=4):
    data = json.dumps(body).encode("utf-8")
    for i in range(attempts):
        req = urllib.request.Request(
            API_URL,
            data=data,
            headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code in (429, 529) and i < attempts - 1:
                time.sleep(2**i)
                continue
            raise RuntimeError("TypeSafe HTTP %d: %s" % (e.code, e.read().decode(errors="replace")[:300]))
        except urllib.error.URLError as e:
            raise RuntimeError("TypeSafe unreachable: %s" % e.reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("logs", nargs="?", help="gate log folder (default: newest under tests/logs)")
    parser.add_argument("--path", default=None, help="godot project dir (default: this script's parent)")
    parser.add_argument("--min-confidence", type=float, default=0.6, help="below this, report 'needs a person'")
    parser.add_argument("--dry-run", action="store_true", help="print the TypeSafe request and stop")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    godot_dir = os.path.abspath(args.path) if args.path else os.path.dirname(script_dir)
    logs_dir = os.path.abspath(args.logs) if args.logs else newest_logs(godot_dir)
    if not logs_dir or not os.path.isdir(logs_dir):
        print("ERROR: no gate logs found; run the gates first or pass a log folder.", file=sys.stderr)
        sys.exit(2)

    failed = collect_failures(logs_dir, load_suites(godot_dir))
    print("Triage of %s: %d failed suite(s)" % (logs_dir, len(failed)))
    if not failed:
        sys.exit(0)

    pending = []
    for item in failed:
        ev = item["evidence"]
        if SCRIPT_ERROR_RE.search(ev["stderr_tail"] + ev["stdout_tail"]):
            item.update(cause="SCRIPT_ERROR", confidence=1.0, source="log")
        else:
            pending.append(item)

    if pending:
        body = build_request(pending)
        if args.dry_run:
            print(json.dumps(body, indent=2, ensure_ascii=False))
            sys.exit(0)
        key = os.environ.get("TYPESAFE_API_KEY")
        if not key:
            print("ERROR: TYPESAFE_API_KEY is not set (or use --dry-run).", file=sys.stderr)
            sys.exit(2)
        try:
            answers = ask_jev(body, key)["answers"]
        except RuntimeError as e:
            print("ERROR: %s" % e, file=sys.stderr)
            sys.exit(2)
        for i, item in enumerate(pending):
            a = answers["q%d" % i]
            item.update(cause=a["choice"], confidence=a["confidence"], probabilities=a["probabilities"], source="jev")

    for item in failed:
        sure = item["confidence"] >= args.min_confidence
        item["action"] = ACTIONS[item["cause"]] if sure else "needs a person (low confidence)"
        # A timing failure measured alone is not machine load, whatever the evidence looked like.
        if item["cause"] == "PERF_CONTENTION" and item["evidence"]["ran_alone_with_timing_gated"]:
            item["action"] = ACTIONS["PERF_REGRESSION"]
        # Re-running alone only helps a suite that has timing checks and failed on them.
        if item["cause"] == "PERF_CONTENTION" and not (
            item["evidence"]["has_timing_checks"] and TIMING_RE.search(" ".join(item["evidence"]["failed_checks"]))
        ):
            item["action"] = "needs a person (timing cause without a failed timing check)"
        print(
            "  %-16s %.2f  %-40s -> %s"
            % (item["cause"], item["confidence"], item["suite"][:40], item["action"])
        )

    report = os.path.join(logs_dir, "triage.json")
    with open(report, "w", encoding="utf-8") as f:
        json.dump(failed, f, indent=2, ensure_ascii=False)
    print("Wrote %s" % report)
    sys.exit(1)


if __name__ == "__main__":
    main()
