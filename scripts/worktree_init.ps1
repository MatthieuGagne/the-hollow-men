#requires -Version 7
<#
.SYNOPSIS
    Copy gitignored build artifacts from the main worktree into the current
    (freshly-created) worktree, then drop stale TMX import caches. PowerShell
    replacement for the former `cp`/`rm` worktree-init recipe lines.

    Run via `make worktree-init`, which then runs `dotnet build` and `make assets`.
#>

$ErrorActionPreference = 'Stop'

# The first entry of `git worktree list` is always the main worktree, regardless
# of the cwd, so this resolves the source repo even when run from a linked tree.
$mainRepo = ((git worktree list --porcelain | Select-Object -First 1) -replace '^worktree\s+', '').Trim()
if (-not $mainRepo) { throw 'Could not determine the main worktree path from `git worktree list`.' }
$mainRepo = $mainRepo -replace '\\', '/'

# assets/ and .godot/imported/ are gitignored and absent in a fresh worktree.
New-Item -ItemType Directory -Force -Path assets/tilesets | Out-Null
New-Item -ItemType Directory -Force -Path .godot/imported | Out-Null

# Placeholder tileset PNG (no export pipeline yet).
Copy-Item -Path "$mainRepo/assets/tilesets/placeholder.png" -Destination assets/tilesets/ -Force

# Compiled dialogue .import descriptors.
Copy-Item -Path "$mainRepo/dialogue/*.import" -Destination dialogue/ -Force

# Yarn import caches — regenerated on import, but copied to avoid a cold first
# build. Tolerate absence (the main repo may not have imported yet).
Copy-Item -Path "$mainRepo/.godot/imported/*yarnproject-*" -Destination .godot/imported/ -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$mainRepo/.godot/imported/*yarn-*"        -Destination .godot/imported/ -Force -ErrorAction SilentlyContinue

# Drop stale TMX import cache so the map reimports against the correct tileset PNG.
Remove-Item -Path .godot/imported/*.tmx-*.md5  -Force -ErrorAction SilentlyContinue
Remove-Item -Path .godot/imported/*.tmx-*.tscn -Force -ErrorAction SilentlyContinue

Write-Host "worktree-init: copied build artifacts from $mainRepo"
