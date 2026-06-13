"""Cross-platform worktree init — copies gitignored build artifacts from the main repo."""
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> None:
    result = subprocess.run(
        ["git", "worktree", "list", "--porcelain"],
        capture_output=True, text=True, check=True
    )
    main_repo = Path(next(
        line.split(" ", 1)[1]
        for line in result.stdout.splitlines()
        if line.startswith("worktree")
    ))
    here = Path(__file__).resolve().parent.parent

    if main_repo.resolve() == here:
        print("Already in main repo — nothing to init.")
        sys.exit(0)

    print(f"Main repo : {main_repo}")
    print(f"Worktree  : {here}")

    shutil.copy2(
        main_repo / "assets/tilesets/placeholder.png",
        here / "assets/tilesets/placeholder.png",
    )
    print("Copied placeholder.png")

    for f in (main_repo / "dialogue").glob("*.import"):
        shutil.copy2(f, here / "dialogue" / f.name)
    print("Copied dialogue .import files")

    imported_src = main_repo / ".godot/imported"
    imported_dst = here / ".godot/imported"
    imported_dst.mkdir(parents=True, exist_ok=True)
    for pattern in ("*yarnproject-*", "*yarn-*"):
        for f in imported_src.glob(pattern):
            shutil.copy2(f, imported_dst / f.name)
    print("Copied yarnproject cache")

    for pattern in ("*.tmx-*.md5", "*.tmx-*.tscn"):
        for f in imported_dst.glob(pattern):
            f.unlink()
    print("Cleared stale TMX cache")


if __name__ == "__main__":
    main()
