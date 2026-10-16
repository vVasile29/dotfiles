"""Install the pinned upstream GTK theme for this user; never overwrite a theme.

Usage: python3 tools/install-dracula-gtk.py [--archive /path/to/archive.tar.gz]
The optional archive must have the exact pinned checksum (useful offline).
Requires Python with tarfile's safe data extraction filter. No sudo or build step.
"""

import argparse
import hashlib
import io
import os
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request


REVISION = "71640b9456110f3bac2130d0b387a3154a9fb4d2"
SHA256 = "434013c854e82b509e633a03270b755f2d4b098c49d46680cafd4959502f3543"
URL = f"https://codeload.github.com/dracula/gtk/tar.gz/{REVISION}"
PARTS = ("assets", "gtk-2.0", "gtk-3.0", "gtk-3.20", "gtk-4.0", "index.theme", "LICENSE")
MAX_ARCHIVE = 20 * 1024 * 1024


def install(archive_path=None):
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    target = data_home / "themes/Dracula"
    if target.exists() or target.is_symlink():
        marker = target / ".dracula-revision"
        if marker.is_file() and marker.read_text().strip() == REVISION:
            print(f"Pinned Dracula theme already installed: {target}")
            return
        raise SystemExit(f"Refusing to overwrite existing theme: {target}")

    if archive_path:
        if archive_path.stat().st_size > MAX_ARCHIVE:
            raise SystemExit("Theme archive unexpectedly large")
        payload = archive_path.read_bytes()
    else:
        with urllib.request.urlopen(URL, timeout=45) as response:
            payload = response.read(MAX_ARCHIVE + 1)
    if len(payload) > MAX_ARCHIVE or hashlib.sha256(payload).hexdigest() != SHA256:
        raise SystemExit("Theme archive does not match the pinned SHA256")

    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".Dracula-install-", dir=target.parent) as temp:
        temp = Path(temp)
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
            if sum(member.size for member in archive.getmembers()) > 100 * 1024 * 1024:
                raise SystemExit("Extracted theme unexpectedly large")
            archive.extractall(temp / "source", filter="data")
        source = temp / "source" / f"gtk-{REVISION}"
        staged = temp / "Dracula"
        staged.mkdir()
        for part in PARTS:
            if (source / part).is_dir():
                shutil.copytree(source / part, staged / part, symlinks=True)
            else:
                shutil.copy2(source / part, staged / part)
        (staged / ".dracula-revision").write_text(REVISION + "\n")
        if target.exists() or target.is_symlink():
            raise SystemExit(f"Theme appeared during installation; leaving it untouched: {target}")
        staged.rename(target)
    print(f"Installed Dracula {REVISION[:7]}: {target}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    install(parser.parse_args().archive)
