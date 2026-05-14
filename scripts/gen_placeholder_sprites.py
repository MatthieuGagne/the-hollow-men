#!/usr/bin/env python3
from PIL import Image
import numpy as np

REID_PATH = "assets/sprites/characters/reid.png"

def tint(src_path: str, dst_path: str, color: tuple) -> None:
    src = Image.open(src_path).convert("RGBA")
    arr = np.array(src, dtype=np.float32)
    arr[..., 0] *= color[0]
    arr[..., 1] *= color[1]
    arr[..., 2] *= color[2]
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(dst_path)

# Karim: white mage — blue tint (matches current KARIM_MODULATE: 0.6, 0.85, 1.0)
tint(REID_PATH, "assets/sprites/characters/karim_battle.png", (0.6, 0.85, 1.0))
# Margot: black mage — purple tint (matches current MARGOT_MODULATE: 0.85, 0.6, 1.0)
tint(REID_PATH, "assets/sprites/characters/margot_battle.png", (0.85, 0.6, 1.0))
print("Done.")
