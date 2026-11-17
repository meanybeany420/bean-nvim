import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "file_icons.py"


class FileIconsTest(unittest.TestCase):
    def test_decorates_nul_records_without_altering_paths(self):
        mapping = {
            "default": "",
            "files": {"makefile": "M"},
            "extensions": {"lua": "L", "py": "P", "tar.gz": "Z", "gz": "G"},
        }
        paths = [b"src/main.lua", b"TEST.PY", b"Makefile", b"x.tar.gz", b"tab\tline\nbreak.unknown", b"bad-\xff.lua"]
        expected = [b"L", b"P", b"M", b"Z", "".encode(), b"L"]
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "icons.json"
            config.write_text(json.dumps(mapping), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, os.fspath(SCRIPT), os.fspath(config)],
                input=b"\0".join(paths) + b"\0", capture_output=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stdout, b"".join(icon + b"\t" + path + b"\0" for icon, path in zip(expected, paths)))


if __name__ == "__main__":
    unittest.main()
