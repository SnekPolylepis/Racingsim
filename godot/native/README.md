# Windows wheel bridge

Uses Windows DirectInput, with no additional runtime dependency. `build.ps1`
rebuilds the checked-in x64 helper with installed Visual Studio C++ Build Tools
and the Windows SDK. The executable uses the static C++ runtime.

The owner's connected CSL DD exposes VID 0EB7 / PID 0020 and two HID collections.
COL01 supplies the real steering/buttons/force-feedback driver; COL02 advertises
FFB but rejects constant-force creation. Prefer COL01, regardless of enumeration
order. USB mBooster with the attached CRP2 throttle is VID 346E / PID 0008.
Throttle axis 4 and brake axis 3 were physically exercised on 2026-09-30, from
0 to 65535. Right paddle is button 4, left is button 5. Steering uses axis 0 with
linear input and no speed-dependent lock or Simcade steering cap.

GDScript exchanges fixed-size binary packets with the helper on ephemeral
loopback UDP ports. Each poll drains its packet batch and replies once; replying
inside the drain loop can starve the game frame when the helper responds quickly.
It reads both devices independently and never sends force
to the Moza pedals. Constant-force effects last 100 ms; pause/focus loss/disabled
FFB sends a stop, and the helper checks game foreground ownership itself. A
stalled/dead parent ends the helper after at most three seconds; force expires
earlier. Normal shutdown restores the driver's original autocenter property.

Windows exports embed the helper in the PCK and extract it to user://wheel_bridge.exe
when launched. macOS continues to use standard gamepad input/rumble. Switching
the wheelbase USB mode or unplugging/reconnecting requires restarting the game.

Zero-force hardware check (windowed, both devices connected):

    godot/tools/Godot.exe --path godot --script res://tools/wheel_check.gd

Live-hardware menu clicks (Race, Settings and Close, without driving/force):

    godot/tools/Godot.exe --path godot --script res://tools/wheel_check.gd -- --menu-clicks

This verifies device reads and creation/update of a real constant-force effect
at zero magnitude. It does not establish subjective torque direction, strength
or driving quality. Headless normalization/stop checks are `tests/v2/wheel.gd`.

API references: [Microsoft DirectInput](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ee418273%28v%3Dvs.85%29),
[cooperative levels](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ee416848%28v%3Dvs.85%29).
