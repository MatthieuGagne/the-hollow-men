.DEFAULT_GOAL := assets

# All recipes (and the Test-Path checks below) run through PowerShell 7 (pwsh).
SHELL := pwsh.exe
.SHELLFLAGS := -NoProfile -Command

.PHONY: assets copy-art sync-tsx import worktree-init

assets: copy-art sync-tsx import

# Copy source PNGs (recursively, preserving subfolders) into the gitignored
# assets/ build dirs. Replaces the former rsync calls.
copy-art:
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/copy_pngs.ps1 -Src art/tilesets           -Dest assets/tilesets
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/copy_pngs.ps1 -Src art/objects            -Dest assets/objects
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/copy_pngs.ps1 -Src art/characters         -Dest assets/sprites/characters
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/copy_pngs.ps1 -Src art/enemies            -Dest assets/sprites/enemies
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/copy_pngs.ps1 -Src art/battle_backgrounds -Dest assets/battle_backgrounds

# Patch each .tsx in maps/ so its tilecount/columns/width/height match the actual PNG on disk.
sync-tsx:
	python scripts/sync_tsx.py

import:
	if (-not (Test-Path .godot/mono/temp/bin/Debug/TheHollowMen.dll)) { Write-Host 'ERROR: .NET assemblies not built. Run: dotnet build'; exit 1 }
	if (-not (Test-Path dialogue/iris.yarnproject.import)) { Write-Host 'ERROR: dialogue not initialized. Run: make worktree-init'; exit 1 }
	godot_console --headless --editor --quit --path .

# Run once after creating a new worktree — copies gitignored build artifacts
# from the main repo that have no automated export pipeline yet, then imports.
# Deletes stale TMX import cache so the map reimports with the correct tileset PNG.
worktree-init:
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/worktree_init.ps1
	dotnet build
	$(MAKE) assets
