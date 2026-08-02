# Prints the real path of the Godot console binary.
#
# `godot_console` on PATH is a symlink in WinGet\Links\. Godot's .NET build
# locates its bundled GodotSharp/Api/Debug/ assemblies relative to the
# executable it was launched from, so invoking the symlink makes it look in
# WinGet\Links\ (no GodotSharp there) and fail with ".NET: Assemblies not
# found" followed by a signal-11 crash. Resolving the link first fixes it.
#
# Usage:  & (& scripts/godot_path.ps1) --headless --editor --quit --path .
$ErrorActionPreference = 'Stop'

$exe = (Get-Command godot_console -CommandType Application).Source
$item = Get-Item -LiteralPath $exe
if ($item.LinkType -eq 'SymbolicLink' -and $item.Target) {
    $target = $item.Target
    if ($target -is [array]) { $target = $target[0] }
    if (-not [System.IO.Path]::IsPathRooted($target)) {
        $target = Join-Path (Split-Path -Parent $exe) $target
    }
    if (Test-Path -LiteralPath $target) { $exe = $target }
}

Write-Output $exe
