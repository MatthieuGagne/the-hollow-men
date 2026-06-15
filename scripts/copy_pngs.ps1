#requires -Version 7
<#
.SYNOPSIS
    Recursively copy every *.png under -Src into -Dest, preserving the relative
    subfolder structure. PowerShell replacement for the former
    `rsync -a --include="*/" --include="*.png" --exclude="*"` calls.
#>
param(
    [Parameter(Mandatory)][string]$Src,
    [Parameter(Mandatory)][string]$Dest
)

$ErrorActionPreference = 'Stop'

# Mirror rsync's silent no-op when the source tree is absent.
if (-not (Test-Path -LiteralPath $Src)) {
    return
}

$srcRoot = (Resolve-Path -LiteralPath $Src).Path
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

Get-ChildItem -LiteralPath $Src -Recurse -File -Filter *.png | ForEach-Object {
    $rel = $_.FullName.Substring($srcRoot.Length).TrimStart('\', '/')
    $target = Join-Path $Dest $rel
    $targetDir = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
}
