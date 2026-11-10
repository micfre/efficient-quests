"""Exercise the local guide adaptation as an installed-guide user."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "tools" / "adapt_guide.py"


class GuideAdaptationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.package = Path(self.tmp.name) / "GuideLime_TUGs_Forever"
        self.package.mkdir()
        self.toc = self.package / "GuideLime_TUGs_Forever.toc"
        self.original_toc = (b"## Title: TUGs\r\n## Interface: 16001\r\n"
                             b"## Dependencies: Guidelime\r\n\r\nlisted.lua\r\n")
        self.toc.write_bytes(self.original_toc)
        self.source = self.package / "listed.lua"
        self.source.write_bytes(b'Guidelime.registerGuide([[Keep 5 apples.]], "TUGs")\r\n')
        (self.package / "unlisted.lua").write_text("do not load")

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(TOOL), *args, str(self.package)],
                              text=True, capture_output=True)

    def test_adaptation_preserves_guides_and_is_repeatable(self):
        source = self.source.read_bytes()
        result = self.run_tool("adapt")
        self.assertEqual(result.returncode, 0, result.stderr)
        toc = self.toc.read_bytes()
        self.assertIn(b"## Dependencies: EfficientQuests", toc)
        self.assertIn(b"## OptionalDeps: Guidelime", toc)
        self.assertLess(toc.index(b"EQ_Guide_Begin.lua"), toc.index(b"listed.lua"))
        self.assertGreater(toc.index(b"EQ_Guide_End.lua"), toc.index(b"listed.lua"))
        self.assertNotIn(b"unlisted.lua", toc)
        self.assertEqual(self.source.read_bytes(), source)
        self.assertEqual(self.run_tool("check").returncode, 0)
        self.assertEqual(self.run_tool("adapt").returncode, 0)
        self.assertEqual(self.toc.read_bytes(), toc)

    def test_check_detects_updated_guide_and_reapplication(self):
        self.assertEqual(self.run_tool("adapt").returncode, 0)
        self.toc.write_bytes(self.original_toc)
        self.assertNotEqual(self.run_tool("check").returncode, 0)
        self.assertEqual(self.run_tool("adapt").returncode, 0)
        self.assertEqual(self.run_tool("check").returncode, 0)
        self.source.write_text('Guidelime.registerGuide([[Updated]], "TUGs")')
        self.assertNotEqual(self.run_tool("check").returncode, 0)


if __name__ == "__main__":
    unittest.main()
