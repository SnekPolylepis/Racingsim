"""Fetch only Windows x64 templates from the official Godot ZIP using HTTP ranges.
No third-party Python packages; output stays in the project's tools directory.
"""
import io, json, pathlib, urllib.request, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
RELEASE = "https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.6.2-stable"
with urllib.request.urlopen(RELEASE, timeout=30) as r:
    release = json.load(r)
asset = next(a for a in release["assets"] if a["name"].endswith("export_templates.tpz"))

class RemoteZip(io.RawIOBase):
    def __init__(self):
        self.pos = 0
        self.size = asset["size"]
        self.url = asset["browser_download_url"]
        self.transferred = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else (self.pos if whence == 1 else self.size) + offset
        return self.pos
    def read(self, n=-1):
        n = self.size-self.pos if n < 0 else min(n, self.size-self.pos)
        if not n: return b""
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{self.pos+n-1}"})
        with urllib.request.urlopen(req, timeout=120) as r:
            if r.status != 206:
                raise RuntimeError("Server did not honor byte-range request; refusing full archive download")
            self.url = r.url
            data = r.read()
        if len(data) != n: raise RuntimeError("Incomplete template download")
        self.pos += n; self.transferred += n
        return data

remote = RemoteZip()
with zipfile.ZipFile(remote) as archive:
    for name in ["windows_release_x86_64.exe", "windows_debug_x86_64.exe"]:
        entry = next(i for i in archive.infolist() if i.filename.endswith("/"+name))
        output = ROOT / "tools" / name
        output.parent.mkdir(exist_ok=True)
        output.write_bytes(archive.read(entry))  # ZipFile verifies the member CRC.
        print("Saved", name, output.stat().st_size, flush=True)
print("Downloaded bytes:", remote.transferred)
