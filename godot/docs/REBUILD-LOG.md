# Rebuild log

Append-only. Newest entries at the bottom. One entry per claim, completion, pause, contract change or decision. Format:

```
## YYYY-MM-DD  <KIND> <task-id>  (<model or owner>)
What was done / decided, commands run, results (pass/fail counts, measurements), what is left.
```

KIND is one of `CLAIM`, `DONE`, `PAUSED`, `FAILED`, `CONTRACT`, `DECISION`, `NOTE`. See [REBUILD-PLAN.md](REBUILD-PLAN.md) §9.

---

## 2026-09-22  DECISION D1–D4  (owner)
Editor removed; 6-DOF chassis; authored 3D tracks; old track format, records and ghosts not carried forward. The CLAUDE.md "don't replace the custom solver" rule is withdrawn. D5–D10 proceed on the plan's defaults until the owner says otherwise.

## 2026-09-22  NOTE pre-rebuild state  (Claude Opus 5.5)
- The workspace is **not a git repository** (no `.git` in `godot/` or the root), although the docs cite commit hashes. P0-01 must resolve this first.
- `godot/.godot/` import cache was missing; regenerated with `--headless --import` (962 resources). Without it the parse check exits 0 but prints font preload errors to stderr.
- Suites on the current code: check-only clean; laps PASS (Monza 261.504 s, Spa 325.175 s); handling 23/0; dynamics 36/0; validation 103/0.
- `build/RacingSim.exe` re-exported 19:24 (110,258,384 bytes); exported `-- --features` 260 checks, 0 failures.
- `export_presets.cfg` references `tools/windows_debug_x86_64.exe`, which does not exist (release export unaffected).

## 2026-09-22  DONE P0-01  (Claude Opus 5.5)
No earlier history exists (the only other repo on the machine, `Desktop/Game`, is an unrelated Electron project with no commits), so this is a fresh repository at the workspace root, branch `main`.
- Commit `Pre-rebuild baseline`, annotated tag `pre-rebuild`. 307 tracked files. Local identity: Zain <zainyasin0723@gmail.com>. No remote.
- `.gitignore` excludes `.godot/`, engine binaries/templates/toolchains in `godot/tools/`, build exes/zips/`macos/`, generated test screenshots/logs/result JSON/capture rounds, root `godot/*.log`, and `godot/reference/` (copyrighted GT4/NFSU2 study images; not to be distributed).
- `.gitattributes` enforces LF (some files were CRLF; working copies re-checked-out as LF). Binary assets marked binary.
- After normalization: check-only clean (empty stderr), handling 23/0, dynamics 36/0.
- **Fresh clones need** Godot 4.6.2 at `godot/tools/Godot.exe` and the release template at `godot/tools/windows_release_x86_64.exe` (not in git), then `--headless --import`.
- Next: P0-03 (baseline capture), P0-04 (legacy exe copy). Pushing to a private remote (e.g. GitHub) is recommended so all models share one origin.

## 2026-09-22  DONE P0-02, P0-03, P0-04  (Claude Opus 5.5)
**P0-02:** `GEMINI.md` added at the root, pointing to `AGENTS.md` and this plan/log. `AGENTS.md` and `CLAUDE.md` already point here.

**P0-03:** baseline captured at tag `pre-rebuild`. Raw stdout is in `docs/rebuild/baseline/*.txt` (all stderr empty). `docs/rebuild/baseline.json` is generated from it by `python tools/baseline_json.py`. Each check keeps its text; `values` lists every number in the line in order, so car names like `f296gt3` contribute numbers too. Match on `text`.

| Suite | Result |
|---|---|
| dynamics (Simulation) | 36/0 |
| dynamics `-- --simcade` | 87 checks, **1 failure (pre-existing)**: roadster Simcade 100-0 38.372 m vs Simulation 42.282 m (−9.2%, band ±8%) |
| handling | 23/0 |
| laps Simulation | Monza 261.504 s, Spa 325.175 s, 0 off, 0 contacts |
| laps Simcade | Monza 261.812 s, Spa 325.687 s, 0 off, 0 contacts |
| showcase_laps (296 @ Spa) | PASS; Simulation-pad 302.44 s, Simcade-pad 302.07 s, keyboard 303.67 s, human-intervention 301.75 s |
| airborne / karussell / track3d / validation | 15/0, 11/0, 37/0, 103/0 |

The Simcade braking failure is not fixed here; it belongs to P2-07 (Simcade retune). It was present before any rebuild work (no source changes since the tag).

Headline flat targets for P2 flat equivalence (Simulation): roadster 0-100 8.24 s / 100-0 42.3 m / 0.72 g; GT 4.48 s / 29.5 m / 1.75 g; 296 GT3 4.12 s / 28.7 m / 1.99 g; tyre peaks 8.6°/0.16, 7.1°/0.13, 6.8°/0.12.

**P0-04:** `build/legacy/RacingSim-pre-rebuild.exe` (19:24 export, 260/0 features) and `RacingSim-macOS-pre-rebuild.zip` (17:07 build, not re-verified), git-ignored. Root launcher `Play Legacy (pre-rebuild).cmd`. **Caution:** the legacy and new builds share the same user data folder (`%APPDATA%/Godot/app_userdata/Racing Sim/`). Once the new build changes the settings/record/ghost formats, give it a different `config/name` or a custom user dir so the two don't overwrite each other's saves (P4-06).

P0 is complete except the remote: GitHub CLI is not installed; pushing to a private remote is up to the owner.

## 2026-09-22  DONE P0-remote  (GPT-6 Sol)

Pushed `main` and tag `pre-rebuild` to [https://github.com/SnekPolylepis/Racingsim](https://github.com/SnekPolylepis/Racingsim) (private). Upstream tracking set.

## 2026-09-22  CLAIM P1  (Gemini 3.8 Flash)
Claiming Phase P1: remove the in-game circuit editor (tasks P1-01, P1-02, P1-03).

## 2026-09-22  DONE P1  (Gemini 3.8 Flash)
Removed the in-game circuit editor, outline importer, and editor workflows/bindings/UI (tasks P1-01, P1-02, P1-03).
- Deleted files: `scripts/editor.gd`, `editor.gd.uid`, `scripts/outline_import.gd`, `outline_import.gd.uid`, `tests/import.gd`, `import.gd.uid`.
- Scope expanded per review to include `retro_renderer.gd`, `retro_flare.gd`, `showcase_review.gd`, and `showcase_benchmark.gd` to remove live editor references.
- In `game.gd`: removed `editing`, `editor`, `test_from_editor` variables; removed `set_editor`, `new_track`, `save_track`, `save_track_as`, `write_track_named`, `import_track_data`, `choose_outline`, `import_outline`, `start_editor`, and `rename_file`. Cleaned `choose_file` to support only setups and ghosts. Cleaned `delete_file`. Removed saved 2D track read path in `game.gd::refresh_tracks()` so user tracks are no longer listed or loaded, leaving user files untouched on disk.
- Preserved `storage.validate_track()` in `storage.gd` to validate bundled circuits at runtime and in tests.
- In `interface.gd`: removed top toolbar, mode button, pause menu editor entry, outline/JSON import/export/rename/delete/folder buttons. Retained dummy `track_picker` and `car_picker` properties for caller compatibility.
- In `front_end.gd`: removed Circuit editor option from circuits page, removed editor branches in `back()`, `_draw()`, and `_process()`.
- In `instruments.gd`: removed `app.editing` check in `_draw()`.
- In `verification.gd`: removed editor interaction helpers (`click_editor`, `drag_editor`), removed editor test block (retaining track validation and safe name checks), updated bundled circuits check to >= 3, updated handbook chapters check to >= 7.
- Updated documentation and play guides: `docs/PLAYER-GUIDE.md` (removed 3 editor chapters and stray mentions), `build/PLAY.txt`, `packaging/PLAY-MACOS.txt`, `docs/LLM-GUIDE.md`.
- Formatted all modified files with `tools/python-packages/bin/gdformat.exe -l 110`.
- All checks pass:
  - `.\tools\Godot.exe --headless --path . --script scripts/game.gd --check-only` (exit 0, empty stderr)
  - `tests/laps.gd`: Simulation Monza best=261.504 s (0 offSteps, 0 contacts), Spa best=325.175 s (0 offSteps, 0 contacts) (exit 0, empty stderr)
  - `tests/handling.gd`: 23 checks, 0 failures (exit 0, empty stderr)
  - `tests/dynamics.gd`: 36 checks, 0 failures (exit 0, empty stderr)
  - `.\tools\Godot.exe -- --features`: 211 checks, 0 failures (exit 0)
  - Re-exported `build/RacingSim.exe` via `Godot.exe --headless --path . --export-release "Windows Desktop" build/RacingSim.exe`
  - Exported `./build/RacingSim.exe -- --features`: 211 checks, 0 failures (exit 0)
- Ready for owner review and merge to main.

## 2026-09-22  DONE P1-review-fix  (Gemini 3.8 Flash)
Addressed P1 review findings on `rb/P1-remove-editor`:
1. Restored folder selection in `scripts/game.gd` (`choose_folder()`) and `scripts/interface.gd` (`open_library()` "Choose folder…" button) to connect portable racing data folders for setups, ghosts, and records. Kept "Local saves" (`use_local_storage()`). Preserved the removal of user track loading/modifying.
2. Cleaned `godot/README.md`, `godot/docs/TESTING.md`, and `godot/docs/MACOS.md`: removed editor instructions, keybindings, section, and commands for deleted `tests/import.gd`. Preserved dated historical test evidence.
3. Formatted modified scripts with `tools/python-packages/bin/gdformat.exe -l 110`.
4. Verification:
   - Headless check-only: `.\tools\Godot.exe --headless --path . --script scripts/game.gd --check-only` (exit 0, empty stderr).
   - Laps suite: `.\tools\Godot.exe --headless --path . --script tests/laps.gd` (Simulation Monza 261.504 s, Spa 325.175 s; 0 offSteps, 0 contacts; exit 0, empty stderr).
   - Handling suite: `.\tools\Godot.exe --headless --path . --script tests/handling.gd` (23 checks, 0 failures; exit 0, empty stderr).
   - Dynamics suite: `.\tools\Godot.exe --headless --path . --script tests/dynamics.gd` (36 checks, 0 failures; exit 0, empty stderr).
   - Windowed feature gates: `.\tools\Godot.exe --path . -- --features` (211 checks, 0 failures; exit 0; stderr contains expected engine shutdown leaks and synthetic input duplicate warning, 0 script errors).
   - Re-exported executable: `.\build\RacingSim.exe -- --features` (211 checks, 0 failures; exit 0; stderr contains expected engine shutdown leaks, 0 script errors).


