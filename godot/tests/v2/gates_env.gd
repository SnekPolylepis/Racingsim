extends RefCounted
## Test-run settings shared by the v2 suites.


## Timing budgets (µs per tick) gate unless RACINGSIM_PERF_GATES=0. tools/run_gates.ps1 sets it to 0 when
## it runs many suites in parallel (they share the CPU, so timings are not the car's), and re-runs the
## timing suites alone in its -Perf pass with the gates on.
static func perf() -> bool:
	return OS.get_environment("RACINGSIM_PERF_GATES") != "0"


## Label suffix for a timing check that is not gating in this run.
static func perf_note() -> String:
	return "" if perf() else " [timing not gated: parallel run]"


## `--car key` on the command line keeps only that car preset (tools/run_gates.ps1 splits long suites
## by car); no argument keeps them all.
static func only_car(presets: Dictionary) -> Dictionary:
	var args = OS.get_cmdline_user_args()
	var i = args.find("--car")
	if i < 0 or i + 1 >= args.size():
		return presets
	var key = args[i + 1]
	return {key: presets[key]} if presets.has(key) else presets


## `--part name` on the command line; "" when absent.
static func part() -> String:
	var args = OS.get_cmdline_user_args()
	var i = args.find("--part")
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""
