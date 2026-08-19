---
summary: Development environment on Windows — worktree init copying gitignored assets (battle backgrounds, tilesets), headless reimport after copying PNGs, concurrent-worktree git add hygiene, DebugOverlay autoload basics
tags: [environment, windows, worktree, git, powershell, debug]
---

# Development Environment

## Worktree Init: Gitignored Assets

- `make worktree-init` fails on Windows (uses Unix `cp`/`head`). Copy manually with PowerShell: `Copy-Item "$mainRepo\assets\battle_backgrounds\*" "$worktree\assets\battle_backgrounds" -Recurse -Force`
- After copying PNGs, run `godot_console --headless --import` — copied PNGs have no `.ctex` import cache in the worktree and will fail with "Unable to open file: .godot/imported/X.ctex"
- Also copy: `assets/tilesets/placeholder.png` (needed for map render)
- Windows glob note: use PowerShell `Remove-Item` with wildcards for stale cache deletion (bash `del` doesn't expand globs on Windows paths) — see [[scene-and-resource-serialization]]

## Concurrent-worktree git hygiene (observed issue #123, 2026-07-08)

- When another task is mid-flight editing different files in the same worktree, always `git add <specific files>` — never `-A`/`.` — and re-check `git status` right before committing, since the other task may commit its own files mid-session and change what shows as "modified"

## DebugOverlay autoload

- CanvasLayer at layer 100; `ConfigFile` at `user://debug.cfg` persists the toggle; `notify_position()` is a no-op when hidden
- Also hosts the DEV save driver (F5/F9/F10) — see [[save-system]]
- Test isolation: remove `user://debug.cfg` in `after_each()` — see [[gut-testing]]

## Related

- [[gut-testing]] — headless suite runs, reimport-before-GUT rule
- [[scene-and-resource-serialization]] — import cache behavior
