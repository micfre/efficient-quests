"""Exercise the guide plugin builder as a release builder (seam 1: subprocess)."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "tools" / "build_guide.py"
REAL_CATALOG = Path(__file__).resolve().parents[1] / "tools" / "catalog.json"
BUILD_DATE = "2026-11-10"


class BuilderFixture(unittest.TestCase):
    """A synthetic source package styled after the TUG package (BOM, CRLF, backslashes)."""

    source_name = "GuideLime_Fixture_One"
    plugin_name = "EfficientQuests_FixtureOne"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / self.source_name
        (self.source / "chapters").mkdir(parents=True)
        self.toc = self.source / (self.source_name + ".toc")
        self.toc.write_bytes(b"\xef\xbb\xbf## Title: Fixture Guide\r\n"
                             b"## Notes: Fixture notes\r\n"
                             b"## Author: Fixture Author\r\n"
                             b"## Interface: 16001\r\n"
                             b"## Version: 1.28\r\n"
                             b"## Dependencies: Guidelime\r\n"
                             b"\r\n"
                             b"chapters\\one.lua\r\n"
                             b"chapters\\two.lua\r\n")
        (self.source / "chapters" / "one.lua").write_bytes(
            b'Guidelime.registerGuide(\r\n[[\r\n[GA Alliance]\r\n[N1 Something]\r\n'
            b'Keep 5 apples.\r\n]],\r\n"Fixture")\r\n')
        (self.source / "chapters" / "two.lua").write_bytes(
            b'Guidelime.registerGuide([[Pick 2 flowers]], "Fixture")\n'
            b'Guidelime.registerGuide([[No author here]])\n')
        (self.source / "chapters" / "unlisted.lua").write_bytes(
            b'Guidelime.registerGuide([[Do not load me]], "Nobody")\n')
        self.catalog = self.write_catalog([
            {"source_package": self.source_name, "plugin": self.plugin_name,
             "license": "All rights reserved", "distribute": False,
             "build_suffix": "-eq1"}])
        self.out = self.root / "out"

    def write_catalog(self, entries):
        path = self.root / ("catalog_%d.json" % len(list(self.root.glob("catalog_*.json"))))
        path.write_text(json.dumps({"version": 1, "guides": entries},
                                   indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return path

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(TOOL), *args],
                              text=True, capture_output=True)

    def build(self, source=None, catalog=None):
        return self.run_tool(str(source or self.source), "--catalog", str(catalog or self.catalog),
                             "--output", str(self.out), "--date", BUILD_DATE)


class BuildOutputTests(BuilderFixture):
    def test_build_emits_plugin_folder_with_derived_name(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        plugin = self.out / self.plugin_name
        self.assertTrue(plugin.is_dir(), str(list(self.out.iterdir())))
        self.assertEqual({p.name for p in plugin.iterdir()},
                         {self.plugin_name + ".toc", "Guides.lua"})


if __name__ == "__main__":
    unittest.main()
