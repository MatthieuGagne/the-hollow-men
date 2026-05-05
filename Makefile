.DEFAULT_GOAL := assets

MAIN_REPO := $(shell git worktree list --porcelain | head -1 | awk '{print $$2}')

.PHONY: assets copy-art import worktree-init

assets: copy-art import

copy-art:
	rsync -a --include="*/" --include="*.png" --exclude="*" art/tilesets/ assets/tilesets/

import:
	DISPLAY=:0 godot --headless --editor --quit --path .

# Run once after creating a new worktree — copies gitignored build artifacts
# from the main repo that have no automated export pipeline yet, then imports.
worktree-init:
	cp $(MAIN_REPO)/assets/tilesets/placeholder.png assets/tilesets/
	$(MAKE) assets
