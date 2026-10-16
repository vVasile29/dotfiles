"""Offline installer safety checks; no live theme/settings changes or network."""

import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "tools/install-dracula-gtk.py"
spec = importlib.util.spec_from_file_location("theme_installer", SOURCE)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class ThemeInstaller(unittest.TestCase):
    def setUp(self):
        approved_tmp = Path("/tmp/opencode")
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-theme-", dir=approved_tmp if approved_tmp.is_dir() else None)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / "theme.tar.gz"
        prefix = f"gtk-{installer.REVISION}/"
        with tarfile.open(self.archive, "w:gz") as archive:
            for name in ["assets/test.svg", "gtk-2.0/gtkrc", "gtk-3.0/gtk.css", "gtk-3.20/gtk.css",
                         "gtk-4.0/gtk.css", "index.theme", "LICENSE"]:
                content = b"test fixture\n"
                info = tarfile.TarInfo(prefix + name)
                info.size = len(content)
                archive.addfile(info, io.BytesIO(content))
            link = tarfile.TarInfo(prefix + "gtk-2.0/assets/test.svg")
            link.type, link.linkname = tarfile.SYMTYPE, "../../assets/test.svg"
            archive.addfile(link)
        self.target = self.root / "data/themes/Dracula"
        self.enterContext(patch.dict("os.environ", {"XDG_DATA_HOME": str(self.root / "data")}))
        self.enterContext(patch.object(installer, "SHA256", hashlib.sha256(self.archive.read_bytes()).hexdigest()))
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))

    def test_install_and_idempotence(self):
        installer.install(self.archive)
        self.assertTrue((self.target / "gtk-3.0/gtk.css").is_file())
        self.assertTrue((self.target / "gtk-2.0/assets/test.svg").is_file())
        marker = self.target / ".dracula-revision"
        modified = marker.stat().st_mtime_ns
        installer.install(self.archive)
        self.assertEqual(marker.stat().st_mtime_ns, modified)

    def test_refuses_existing_theme(self):
        self.target.mkdir(parents=True)
        original = self.target / "user-theme.txt"
        original.write_text("keep me")
        with self.assertRaises(SystemExit):
            installer.install(self.archive)
        self.assertEqual(original.read_text(), "keep me")

    def test_rejects_bad_checksum(self):
        self.archive.write_bytes(b"not the pinned archive")
        with self.assertRaises(SystemExit):
            installer.install(self.archive)
        self.assertFalse(self.target.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
