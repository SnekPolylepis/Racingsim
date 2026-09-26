# Godot arguments for windowed test runs (visual review, the features gate): no audio, and the window on the
# rightmost monitor so it stays off the owner's working screens. Don't minimise the window instead: a
# minimised Godot window stops rendering, and every capture after that is the same frozen frame.
# Dot-source it, then add (Get-TestWindowArgs) to the Godot argument list. On a single monitor it only mutes.
function Get-TestWindowArgs {
    $window = @("--audio-driver", "Dummy")
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $screens = [System.Windows.Forms.Screen]::AllScreens
        if ($screens.Count -gt 1) {
            $target = $screens | Sort-Object { $_.Bounds.X } | Select-Object -Last 1
            $x = $target.WorkingArea.X + 40
            $y = $target.WorkingArea.Y + 40
            $window += @("--position", "$x,$y")
        }
    } catch {
    }
    return $window
}
