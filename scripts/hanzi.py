"""Build an offline stroke-centerline subset of Hanzi Writer Data 2.0.1."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import tarfile

archive_path = Path(sys.argv[1])
output = Path(sys.argv[2])
expected_sha = "72baf3d82b114e60d6e40ea05f24d2262a05cd39d544e2f322ba2fceb7beff15"
if hashlib.sha256(archive_path.read_bytes()).hexdigest() != expected_sha:
    raise SystemExit("Hanzi Writer Data checksum mismatch")

glyphs = {}
with tarfile.open(archive_path, "r:gz") as archive:
    license_text = archive.extractfile("package/ARPHICPL.TXT").read()
    for member in archive:
        name = PurePosixPath(member.name)
        if name.suffix != ".json" or len(name.stem) != 1:
            continue
        data = json.load(archive.extractfile(member))
        glyphs[name.stem] = data["medians"]

assert len(glyphs) > 9000
output.mkdir(parents=True, exist_ok=True)
(output / "ARPHICPL.TXT").write_bytes(license_text)
header = """// Hanzi Writer Data 2.0.1, derived from Make Me a Hanzi.
// Copyright 1999 Arphic Technology Co., Ltd. Copyright 2016 Shaunak Kishore.
// Under the Arphic Public License in ARPHICPL.TXT.
// Only stroke centerlines (medians) are retained. Their coordinates are unchanged.
"""
(output / "hanzi-strokes.js").write_text(
    header + "const hanziStrokes = " + json.dumps(glyphs, ensure_ascii=False, separators=(",", ":")) + ";\n",
    encoding="utf-8",
)
