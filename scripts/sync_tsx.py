"""Patch every maps/*.tsx so tilecount/columns/width/height match the actual PNG."""
import re
import sys
from pathlib import Path
from PIL import Image

MAPS = Path("maps")
ROOT = Path(".")


def sync(tsx: Path) -> None:
    text = tsx.read_text()
    m = re.search(r'<image source="([^"]+)"', text)
    if not m:
        return

    png = (tsx.parent / m.group(1)).resolve()
    if not png.exists():
        print(f"  skip {tsx.name}: PNG not found at {png}", file=sys.stderr)
        return

    img = Image.open(png)
    tw = int(re.search(r'tilewidth="(\d+)"', text).group(1))
    th = int(re.search(r'tileheight="(\d+)"', text).group(1))
    cols = img.width // tw
    tilecount = cols * (img.height // th)

    def patch(attr, value):
        return re.sub(rf'{attr}="\d+"', f'{attr}="{value}"', text)

    patched = text
    patched = re.sub(r'tilecount="\d+"', f'tilecount="{tilecount}"', patched)
    patched = re.sub(r'columns="\d+"', f'columns="{cols}"', patched)
    patched = re.sub(
        r'(<image[^>]+) width="\d+" height="\d+"',
        rf'\1 width="{img.width}" height="{img.height}"',
        patched,
    )

    if patched != text:
        tsx.write_text(patched)
        print(f"  updated {tsx.name}: {img.width}x{img.height} → {cols} cols, {tilecount} tiles")
    else:
        print(f"  ok {tsx.name}")


for tsx in sorted(MAPS.glob("*.tsx")):
    sync(tsx)
