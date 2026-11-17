import hashlib
import json
import os
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text())
home = Path(manifest["home"])
changed = []
for relative, record in manifest["files"].items():
    path = home / relative
    if "link" in record:
        matches = path.is_symlink() and os.readlink(path) == record["link"]
    else:
        matches = path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == record["sha256"]
    if not matches:
        changed.append(relative)
if changed:
    print("Original files changed:", *changed, sep="\n")
    raise SystemExit(1)
print(f"PASS original Neovim/theme preserved: {len(manifest['files'])} entries unchanged")
