.DEFAULT_GOAL := assets

MAIN_REPO := $(shell git worktree list --porcelain | head -1 | awk '{print $$2}')

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
	python3 scripts/sync_tsx.py

import:
	@test -f .godot/mono/temp/bin/Debug/TheHollowMen.dll || \
		(echo "ERROR: C# assemblies not built. Run 'dotnet build' first." && exit 1)
	@test -f dialogue/iris.yarnproject.import || \
		(echo "ERROR: Dialogue not initialized. Run 'make worktree-init' first." && exit 1)
	DISPLAY=:0 godot --headless --editor --quit --path .

# Run once after creating a new worktree — copies gitignored build artifacts
# from the main repo that have no automated export pipeline yet, then imports.
# Deletes stale TMX import cache so the map reimports with the correct tileset PNG.
worktree-init:
	cp $(MAIN_REPO)/assets/tilesets/placeholder.png assets/tilesets/
	cp $(MAIN_REPO)/dialogue/*.import dialogue/
	rsync -a --include="*.yarnproject-*" --include="*.yarn-*" --exclude="*" $(MAIN_REPO)/.godot/imported/ .godot/imported/
	rm -f .godot/imported/*.tmx-*.md5 .godot/imported/*.tmx-*.tscn
	dotnet build
	$(MAKE) assets
