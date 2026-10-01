$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $installation) { throw 'Install Visual Studio C++ Build Tools and a Windows SDK to rebuild the wheel helper.' }
$vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
Push-Location $PSScriptRoot
try {
    $object = Join-Path $env:TEMP 'racingsim-wheel-bridge.obj'
    & cmd /c "`"$vcvars`" >nul && cl /nologo /EHsc /O2 /MT wheel_bridge.cpp /Fe:wheel_bridge.exe /Fo:`"$object`""
    if ($LASTEXITCODE -ne 0) { throw 'Wheel helper compilation failed.' }
} finally { Pop-Location }
