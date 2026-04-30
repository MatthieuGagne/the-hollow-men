.DEFAULT_GOAL := assets

.PHONY: assets copy-art import

assets: copy-art import

copy-art:
	rsync -a --include="*.png" --exclude="*" art/tilesets/ assets/tilesets/

import:
	DISPLAY=:0 godot --headless --editor --quit --path .
