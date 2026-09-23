"""Install pinned official Godot tools locally; Python 3, no third-party packages.

Fetch only the macOS member of the large all-platform template archive.
ZIP reads verify CRCs; the editor also uses GitHub's SHA-256 when provided.
Never modifies system applications or user game data.
"""

import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request
import zipfile

VERSION = "4.6.2"
ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
RELEASE = (
    "https://api.github.com/repos/godotengine/godot-builds/releases/tags/"
    + VERSION + "-stable"
)


class RemoteZip(io.RawIOBase):
    def __init__(self, asset):
        self.pos = 0
        self.size = asset["size"]
        self.url = asset["browser_download_url"]

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else (self.pos if whence == 1 else self.size) + offset
        return self.pos

    def read(self, size=-1):
        size = self.size - self.pos if size < 0 else min(size, self.size - self.pos)
        if size <= 0:
            return b""
        request = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{self.pos + size - 1}"}
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Server refused byte ranges; use manual template installation")
            data = response.read()
        if len(data) != size:
            raise RuntimeError("Incomplete template download")
        self.pos += size
        return data


def main():
    TOOLS.mkdir(exist_ok=True)
    with urllib.request.urlopen(RELEASE, timeout=30) as response:
        assets = json.load(response)["assets"]
    editor = next(a for a in assets if a["name"] == f"Godot_v{VERSION}-stable_macos.universal.zip")
    template = next(a for a in assets if a["name"].endswith("export_templates.tpz"))
    if not (TOOLS / "Godot.app").exists():
        print("Downloading official Godot editor…", flush=True)
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "godot.zip"
            urllib.request.urlretrieve(editor["browser_download_url"], archive)
            digest = editor.get("digest")
            if digest and digest.startswith("sha256:"):
                if hashlib.sha256(archive.read_bytes()).hexdigest() != digest[7:]:
                    raise RuntimeError("Editor SHA-256 mismatch")
            subprocess.run(["/usr/bin/ditto", "-x", "-k", str(archive), str(TOOLS)], check=True)
    if not (TOOLS / "macos.zip").exists():
        print("Downloading official macOS template…", flush=True)
        with zipfile.ZipFile(RemoteZip(template)) as archive:
            data = archive.read("templates/macos.zip")
        partial = TOOLS / "macos.zip.partial"
        partial.write_bytes(data)
        partial.replace(TOOLS / "macos.zip")
    print("Ready: bash godot/packaging/build-macos.sh")


if __name__ == "__main__":
    main()
