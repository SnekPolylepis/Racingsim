#!/usr/bin/env python3
"""
Headless gate runner for GitHub Actions CI and local testing.
Reads godot/tools/gates.json and runs every headless suite with RACINGSIM_PERF_GATES=0.
Logs stdout and stderr per suite to godot/tests/logs/ci/<safe_name>.out and .err.
"""

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import time


def find_godot(explicit_path=None, godot_dir=None):
    if explicit_path and os.path.isfile(explicit_path):
        return os.path.abspath(explicit_path)
    env_godot = os.environ.get("RACINGSIM_GODOT")
    if env_godot and os.path.isfile(env_godot):
        return os.path.abspath(env_godot)
    which_godot = shutil.which("godot")
    if which_godot:
        return os.path.abspath(which_godot)
    if godot_dir:
        candidates = [
            os.path.join(godot_dir, "tools", "Godot.exe"),
            os.path.join(godot_dir, "tools", "Godot.app", "Contents", "MacOS", "Godot"),
            os.path.join(godot_dir, "Godot.exe"),
        ]
        for c in candidates:
            if os.path.isfile(c):
                return os.path.abspath(c)
    return None


def dicts_close(d1, d2, rel_tol=0.02, abs_tol=5):
    if d1.keys() != d2.keys():
        return False
    for k in d1:
        v1, v2 = d1[k], d2[k]
        if isinstance(v1, dict) and isinstance(v2, dict):
            if not dicts_close(v1, v2, rel_tol, abs_tol):
                return False
        elif isinstance(v1, (int, float)) and isinstance(v2, (int, float)):
            if not (abs(v1 - v2) <= max(abs_tol, rel_tol * max(abs(v1), abs(v2)))):
                return False
        elif v1 != v2:
            return False
    return True


def match_legacy_baseline(got_text, want_text):
    got_norm = got_text.replace("\r\n", "\n").strip()
    want_norm = want_text.replace("\r\n", "\n").strip()
    if got_norm == want_norm:
        return True, "identical to baseline"

    got_lines = got_norm.splitlines()
    want_lines = want_norm.splitlines()
    if len(got_lines) != len(want_lines):
        return False, f"line count mismatch: got {len(got_lines)}, want {len(want_lines)}"

    for i, (g, w) in enumerate(zip(got_lines, want_lines)):
        if g == w:
            continue
        if g.startswith("SHOWCASE LAP ") and w.startswith("SHOWCASE LAP "):
            try:
                jg = json.loads(g[len("SHOWCASE LAP ") :])
                jw = json.loads(w[len("SHOWCASE LAP ") :])
                if dicts_close(jg, jw):
                    continue
            except Exception:
                pass
            return False, f"line {i+1} JSON mismatch"

        g_toks = g.split()
        w_toks = w.split()
        if len(g_toks) != len(w_toks):
            return False, f"line {i+1} token count mismatch"

        for tg, tw in zip(g_toks, w_toks):
            if tg == tw:
                continue
            clean_g = re.sub(r"[,;°%]", "", tg)
            clean_w = re.sub(r"[,;°%]", "", tw)
            try:
                fg, fw = float(clean_g), float(clean_w)
                if abs(fg - fw) <= max(0.02, 0.05 * max(abs(fg), abs(fw))):
                    continue
            except ValueError:
                pass
            return False, f"line {i+1} token mismatch: '{tg}' vs '{tw}'"

    return True, "matches baseline (within platform float tolerance)"


def run_suite(godot_bin, godot_dir, suite, logs_dir, timeout, allow_spa_roadster):
    name = suite["name"]
    safe_name = re.sub(r"[^A-Za-z0-9_-]", "_", name)
    out_file = os.path.join(logs_dir, f"{safe_name}.out")
    err_file = os.path.join(logs_dir, f"{safe_name}.err")

    kind = suite.get("kind", "v2")
    cmd = [godot_bin, "--headless", "--path", godot_dir]

    if kind == "parse":
        cmd.extend(["--script", suite["script"], "--check-only"])
    else:
        cmd.extend(["--script", suite["script"]])
        args = suite.get("args")
        if args:
            cmd.append("--")
            cmd.extend(args)

    env = os.environ.copy()
    env["RACINGSIM_PERF_GATES"] = "0"

    t0 = time.time()
    timed_out = False
    exit_code = -1

    try:
        with open(out_file, "w", encoding="utf-8", errors="replace") as out_fp, open(
            err_file, "w", encoding="utf-8", errors="replace"
        ) as err_fp:
            proc = subprocess.Popen(cmd, stdout=out_fp, stderr=err_fp, env=env, cwd=godot_dir)
            try:
                proc.wait(timeout=timeout)
                exit_code = proc.returncode
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                timed_out = True
    except Exception as e:
        secs = round(time.time() - t0, 1)
        return {
            "name": name,
            "ok": False,
            "allowed": False,
            "secs": secs,
            "note": f"Exception starting process: {e}",
            "out": out_file,
            "err": err_file,
        }

    secs = round(time.time() - t0, 1)

    if timed_out:
        return {
            "name": name,
            "ok": False,
            "allowed": False,
            "secs": secs,
            "note": f"TIMEOUT after {timeout} s",
            "out": out_file,
            "err": err_file,
        }

    out_text = ""
    if os.path.isfile(out_file):
        with open(out_file, "r", encoding="utf-8", errors="replace") as f:
            out_text = f.read()

    err_text = ""
    if os.path.isfile(err_file):
        with open(err_file, "r", encoding="utf-8", errors="replace") as f:
            err_text = f.read()

    if kind == "legacy":
        baseline_file = os.path.join(godot_dir, "docs", "rebuild", "baseline", suite["baseline"])
        if not os.path.isfile(baseline_file):
            return {
                "name": name,
                "ok": False,
                "allowed": False,
                "secs": secs,
                "note": f"baseline file missing: {baseline_file}",
                "out": out_file,
                "err": err_file,
            }
        with open(baseline_file, "r", encoding="utf-8", errors="replace") as f:
            want = f.read()

        matched, match_note = match_legacy_baseline(out_text, want)
        want_exit = int(suite.get("exit", 0))
        ok = matched and (exit_code == want_exit)
        note = match_note
        if exit_code != want_exit:
            note += f", exit {exit_code} (want {want_exit})"
        return {
            "name": name,
            "ok": ok,
            "allowed": False,
            "secs": secs,
            "note": note,
            "out": out_file,
            "err": err_file,
        }

    if kind == "parse":
        ok = exit_code == 0
        note = "clean" if ok else f"exit {exit_code}, see {err_file}"
        return {
            "name": name,
            "ok": ok,
            "allowed": False,
            "secs": secs,
            "note": note,
            "out": out_file,
            "err": err_file,
        }

    # v2 suites: find last line with RESULTS {json}
    lines = [ln for ln in out_text.splitlines() if " RESULTS {" in ln]
    if not lines:
        return {
            "name": name,
            "ok": False,
            "allowed": False,
            "secs": secs,
            "note": f"no RESULTS line (exit {exit_code}); see {out_file}",
            "out": out_file,
            "err": err_file,
        }

    last_line = lines[-1]
    json_start = last_line.find("{")
    try:
        results_data = json.loads(last_line[json_start:])
    except Exception as e:
        return {
            "name": name,
            "ok": False,
            "allowed": False,
            "secs": secs,
            "note": f"malformed RESULTS json: {e}; see {out_file}",
            "out": out_file,
            "err": err_file,
        }

    failures = results_data.get("failures", [])
    checks = results_data.get("checks", 0)

    # Check for known allowed failure: laps.gd "spa roadster simulation"
    is_allowed = False
    if allow_spa_roadster and suite.get("script") == "tests/v2/laps.gd":
        if failures and all("spa roadster simulation" in str(f) for f in failures):
            is_allowed = True

    if (exit_code == 0 and len(failures) == 0) or is_allowed:
        ok = True
        if is_allowed:
            note = f"{checks} checks; ALLOWED failure: spa roadster simulation (P4-07b)"
        else:
            note = f"{checks} checks, 0 failures"
    else:
        ok = False
        note = f"{checks} checks, {len(failures)} failures"
        if exit_code != 0:
            note += f", exit {exit_code}"
        if failures:
            sample = " | ".join(str(f)[:60] for f in failures[:2])
            note += f": {sample}"

    return {
        "name": name,
        "ok": ok,
        "allowed": is_allowed,
        "secs": secs,
        "note": note,
        "out": out_file,
        "err": err_file,
    }


def main():
    parser = argparse.ArgumentParser(description="Headless gate runner for CI")
    parser.add_argument("--godot", default=None, help="Path to Godot executable")
    parser.add_argument("--path", default=None, help="Path to godot project dir")
    parser.add_argument(
        "--jobs",
        type=int,
        default=min(8, max(1, os.cpu_count() or 4)),
        help="Number of concurrent suites to run",
    )
    parser.add_argument("--timeout", type=int, default=300, help="Per-suite timeout in seconds")
    parser.add_argument("--only", default=None, help="Comma-separated suite names to run")
    parser.add_argument(
        "--no-allow-spa-roadster",
        action="store_true",
        help="Disallow known spa roadster simulation failure",
    )

    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    godot_dir = os.path.abspath(args.path) if args.path else os.path.dirname(script_dir)

    godot_bin = find_godot(args.godot, godot_dir)
    if not godot_bin:
        print("ERROR: Godot executable not found. Specify via --godot or RACINGSIM_GODOT.", file=sys.stderr)
        sys.exit(2)

    manifest_path = os.path.join(script_dir, "gates.json")
    if not os.path.isfile(manifest_path):
        print(f"ERROR: gates manifest not found at {manifest_path}", file=sys.stderr)
        sys.exit(2)

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    logs_dir = os.path.join(godot_dir, "tests", "logs", "ci")
    os.makedirs(logs_dir, exist_ok=True)

    # Initial import if .godot cache does not exist
    dot_godot = os.path.join(godot_dir, ".godot")
    if not os.path.exists(dot_godot):
        print("Importing project (no .godot cache)...", flush=True)
        import_out = os.path.join(logs_dir, "import.out")
        import_err = os.path.join(logs_dir, "import.err")
        with open(import_out, "w", encoding="utf-8") as out_fp, open(
            import_err, "w", encoding="utf-8"
        ) as err_fp:
            p = subprocess.run(
                [godot_bin, "--headless", "--path", godot_dir, "--import"],
                stdout=out_fp,
                stderr=err_fp,
                timeout=300,
            )
            if p.returncode != 0:
                print(f"ERROR: project import failed with code {p.returncode}; see {import_err}", file=sys.stderr)
                sys.exit(2)

    only_filter = [x.strip() for x in args.only.split(",")] if args.only else []

    selected = []
    skipped = []
    for s in manifest.get("suites", []):
        name = s["name"]
        script = s.get("script")

        # Skip windowed/feature suites
        if s.get("kind") == "features" or s.get("window"):
            skipped.append(f"{name} (windowed)")
            continue

        # Skip if script is missing from disk
        if script and not os.path.isfile(os.path.join(godot_dir, script)):
            skipped.append(f"{name} (missing script)")
            continue

        # Apply --only filter if given
        if only_filter:
            if not any(name.startswith(o) for o in only_filter):
                skipped.append(name)
                continue

        selected.append(s)

    print(f"Gates CI: {len(selected)} selected, {len(skipped)} skipped. Logs: {logs_dir}", flush=True)
    print(f"Running up to {args.jobs} suites concurrently using {godot_bin}\n", flush=True)

    t_start = time.time()
    results = []

    allow_spa = not args.no_allow_spa_roadster

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        future_to_suite = {
            executor.submit(
                run_suite, godot_bin, godot_dir, s, logs_dir, args.timeout, allow_spa
            ): s
            for s in selected
        }
        for future in concurrent.futures.as_completed(future_to_suite):
            res = future.result()
            results.append(res)
            mark = "ALLOW" if res.get("allowed") else ("PASS " if res["ok"] else "FAIL ")
            print(f"{mark} {res['name']:<36} {res['secs']:>5}s  {res['note']}", flush=True)

    wall_secs = round(time.time() - t_start, 1)

    passed_count = sum(1 for r in results if r["ok"] and not r.get("allowed"))
    allowed_count = sum(1 for r in results if r.get("allowed"))
    failed_count = sum(1 for r in results if not r["ok"])

    print("\n" + "=" * 70, flush=True)
    status_str = "ALL GATES PASSED" if failed_count == 0 else "GATES FAILED"
    print(
        f"{status_str}: {len(results)} run ({passed_count} pass, {allowed_count} allowed failure, {failed_count} failed) in {wall_secs}s wall clock",
        flush=True,
    )
    print("=" * 70, flush=True)

    if failed_count > 0:
        print("\nFailed suites:", file=sys.stderr)
        for r in results:
            if not r["ok"]:
                print(f"  FAIL  {r['name']} ({r['secs']}s): {r['note']}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
