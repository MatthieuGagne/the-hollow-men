.DEFAULT_GOAL := assets

.PHONY: assets copy-art sync-tsx import worktree-init

assets: copy-art sync-tsx import

copy-art:
	rsync -a --include="*/" --include="*.png" --exclude="*" art/tilesets/ assets/tilesets/
	rsync -a --include="*/" --include="*.png" --exclude="*" art/objects/ assets/objects/
	rsync -a --include="*/" --include="*.png" --exclude="*" art/characters/ assets/sprites/characters/
	rsync -a --include="*/" --include="*.png" --exclude="*" art/enemies/ assets/sprites/enemies/
	rsync -a --include="*/" --include="*.png" --exclude="*" art/battle_backgrounds/ assets/battle_backgrounds/

# Patch each .tsx in maps/ so its tilecount/columns/width/height match the actual PNG on disk.
sync-tsx:
	python scripts/sync_tsx.py

import:
	@test -f .godot/mono/temp/bin/Debug/TheHollowMen.dll || \
		(echo "ERROR: C# assemblies not built. Run 'dotnet build' first." && exit 1)
	@test -f dialogue/iris.yarnproject.import || \
		(echo "ERROR: Dialogue not initialized. Run 'make worktree-init' first." && exit 1)
	godot_console --headless --editor --quit --path .

# Run once after creating a new worktree — copies gitignored build artifacts
# from the main repo that have no automated export pipeline yet, then imports.
# Deletes stale TMX import cache so the map reimports with the correct tileset PNG.
worktree-init:
	python scripts/worktree_init.py
	dotnet build
	$(MAKE) assets
