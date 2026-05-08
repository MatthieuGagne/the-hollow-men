.DEFAULT_GOAL := assets

MAIN_REPO := $(shell git worktree list --porcelain | head -1 | awk '{print $$2}')

.PHONY: assets copy-art sync-tsx import worktree-init

assets: copy-art sync-tsx import

copy-art:
	rsync -a --include="*/" --include="*.png" --exclude="*" art/tilesets/ assets/tilesets/
	rsync -a --include="*/" --include="*.png" --exclude="*" art/objects/ assets/objects/

# Patch each .tsx in maps/ so its tilecount/columns/width/height match the actual PNG on disk.
sync-tsx:
	python3 scripts/sync_tsx.py

import:
	DISPLAY=:0 godot --headless --editor --quit --path .

# Run once after creating a new worktree — copies gitignored build artifacts
# from the main repo that have no automated export pipeline yet, then imports.
# Deletes stale TMX import cache so the map reimports with the correct tileset PNG.
worktree-init:
	cp $(MAIN_REPO)/assets/tilesets/placeholder.png assets/tilesets/
	rm -f .godot/imported/*.tmx-*.md5 .godot/imported/*.tmx-*.tscn
	$(MAKE) assets
