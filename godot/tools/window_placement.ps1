# Godot arguments for windowed test runs (visual review, the features gate): no audio, and the window on the
# rightmost monitor so it stays off the owner's working screens. Don't minimise the window instead: a
# minimised Godot window stops rendering, and every capture after that is the same frozen frame.
# Dot-source it, add (Get-TestWindowArgs) to the Godot arguments, and pass the user argument --mute-audio after
# "--" (game.gd mutes the Master bus). The Dummy audio driver would also be silent, but it leaks an ObjectDB
# instance at exit and fails the features gate. On a single monitor this only places nothing.
function Get-TestWindowArgs {
    $window = @()
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
