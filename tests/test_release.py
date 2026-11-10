"""Exercise the release script as a release builder (seam 1: subprocess)."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "tools" / "release.py"
REPO = Path(__file__).resolve().parents[1]
CORE = "EfficientQuests"
CORE_VERSION = "0.2.0"  # mirrors ## Version in EfficientQuests/EfficientQuests.toc
BUILD_DATE = "2026-11-10"


class ReleaseFixture(unittest.TestCase):
    """A synthetic sources directory holding cataloged guide packages."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sources = self.root / "sources"
        self.sources.mkdir()
        self.out = self.root / "dist"
        self.entries = []

    def add_package(self, source_name, distribute, *, licensed=False,
                    version="1.28", build_suffix="-eq1", body=b"Keep 5 apples.\n"):
        """Write one synthetic guide package into the sources directory."""
        package = self.sources / source_name
        package.mkdir()
        lines = ["## Title: " + source_name, "## Interface: 16001",
                 "## Version: " + version]
        if licensed:
            lines.append("## X-License: Fixture license")
            (package / "LICENSE").write_bytes(
                b"Synthetic fixture license. Not third-party text.\n")
        toc = "\n".join(lines) + "\n\nguide.lua\n"
        (package / (source_name + ".toc")).write_text(toc, encoding="utf-8")
        (package / "guide.lua").write_bytes(
            b'Guidelime.registerGuide([[' + body + b']], "Fixture")\n')
        plugin = "EfficientQuests_" + source_name.replace("_", "")[
            source_name.lower().find("guidelime") + len("guidelime"):]
        self.entries.append(
            {"source_package": source_name, "plugin": plugin,
             "license": "Fixture license" if licensed else "All rights reserved",
             "distribute": distribute, "build_suffix": build_suffix})
        return self.entries[-1]

    def write_catalog(self):
        path = self.root / "catalog.json"
        path.write_text(json.dumps({"version": 1, "guides": self.entries},
                                   indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return path

    def release(self, *args):
        return subprocess.run(
            [sys.executable, str(TOOL), "--sources", str(self.sources),
             "--catalog", str(self.write_catalog()), "--output", str(self.out),
             "--date", BUILD_DATE, *args],
            text=True, capture_output=True)


class ReleaseTests(ReleaseFixture):
    def test_sources_argument_is_required(self):
        result = subprocess.run([sys.executable, str(TOOL)], text=True,
                                capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--sources", result.stderr)

    def test_ships_core_and_flagged_guide_with_audit_report(self):
        self.add_package("GuideLime_Flagged", True, licensed=True,
                         version="2.0", build_suffix="-eq3")
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stderr)
        core_zip = self.out / ("EfficientQuests-" + CORE_VERSION + ".zip")
        guide_zip = self.out / "EfficientQuests_Flagged-2.0-eq3.zip"
        self.assertTrue(core_zip.is_file(), str(list(self.out.iterdir())))
        self.assertTrue(guide_zip.is_file(), str(list(self.out.iterdir())))
        # The shipped guide zip carries the plugin folder with its audit
        # report and the bundled license inside.
        with zipfile.ZipFile(guide_zip) as zf:
            self.assertEqual(set(zf.namelist()), {
                "EfficientQuests_Flagged/EfficientQuests_Flagged.toc",
                "EfficientQuests_Flagged/Guides.lua",
                "EfficientQuests_Flagged/LICENSE",
                "EfficientQuests_Flagged/extraction-audit.json"})
        # The core zip holds exactly the shipped addon files, nothing else.
        with zipfile.ZipFile(core_zip) as zf:
            self.assertEqual(zf.namelist(), sorted(
                CORE + "/" + p.name for p in (REPO / CORE).iterdir() if p.is_file()))

    def test_unflagged_guide_builds_but_produces_no_zip(self):
        flagged = self.add_package("GuideLime_Flagged", True, licensed=True,
                                   version="2.0", build_suffix="-eq3")
        unflagged = self.add_package("GuideLime_Unflagged", False)
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stderr)
        # The unflagged guide is still built and audited for the log...
        report = (self.out / "builds" / unflagged["plugin"]
                  / "extraction-audit.json")
        self.assertTrue(report.is_file(), result.stdout)
        # ...but the only zips in the release are the core and the flagged one.
        self.assertEqual(sorted(p.name for p in self.out.glob("*.zip")),
                         ["EfficientQuests-" + CORE_VERSION + ".zip",
                          flagged["plugin"] + "-2.0-eq3.zip"])
        self.assertFalse(any("Unflagged" in p.name for p in self.out.glob("*.zip")))

    def test_missing_flagged_source_fails_the_release_before_building(self):
        self.add_package("GuideLime_Flagged", True, licensed=True)
        self.write_catalog()
        # The flagged source package exists nowhere: its directory is absent.
        shutil.rmtree(self.sources / "GuideLime_Flagged")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GuideLime_Flagged", result.stderr)
        self.assertIn("distributable", result.stderr)
        # The failure is a preflight: not even the core zip may exist.
        self.assertFalse(self.out.exists() or any(self.out.glob("*.zip")),
                         "a failed release must produce nothing")

    def test_missing_unflagged_source_is_a_note_not_an_error(self):
        flagged = self.add_package("GuideLime_Flagged", True, licensed=True)
        self.add_package("GuideLime_Unflagged", False)
        self.write_catalog()
        shutil.rmtree(self.sources / "GuideLime_Unflagged")
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("GuideLime_Unflagged", result.stdout)
        self.assertTrue((self.out / (flagged["plugin"] + "-1.28-eq1.zip")).is_file())

    def test_stale_zip_of_now_unflagged_guide_is_swept(self):
        """A flag flip must not leave last release's zip behind in dist."""
        self.add_package("GuideLime_Flagged", True, licensed=True)
        unflagged = self.add_package("GuideLime_Unflagged", False)
        self.out.mkdir(parents=True)
        stale = self.out / (unflagged["plugin"] + "-1.28-eq1.zip")
        stale.write_bytes(b"stale release artifact from an earlier catalog")
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Removed stale", result.stdout)
        self.assertFalse(stale.exists())

    def test_rerun_with_same_date_is_byte_identical(self):
        self.add_package("GuideLime_Flagged", True, licensed=True,
                         version="2.0", build_suffix="-eq3")
        self.assertEqual(self.release().returncode, 0)
        first = {p.name: p.read_bytes() for p in self.out.glob("*.zip")}
        shutil.rmtree(self.out)
        self.assertEqual(self.release().returncode, 0)
        second = {p.name: p.read_bytes() for p in self.out.glob("*.zip")}
        self.assertEqual(first, second)

    NO_ADVICE_BODY = (b"\n[GA Alliance]\n[N1 Empty]\n"
                      b"Just walk north and enjoy the view.\n")

    def test_failing_unflagged_guide_warns_but_release_continues(self):
        flagged = self.add_package("GuideLime_Flagged", True, licensed=True)
        self.add_package("GuideLime_Unflagged", False,
                         body=self.NO_ADVICE_BODY)
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("EfficientQuests_Unflagged", result.stdout)
        self.assertIn("not shipped", result.stdout)
        self.assertTrue((self.out / (flagged["plugin"] + "-1.28-eq1.zip")).is_file())

    def test_failing_flagged_guide_fails_the_release_with_no_zips(self):
        self.add_package("GuideLime_Flagged", True, licensed=True,
                         body=self.NO_ADVICE_BODY)
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EfficientQuests_Flagged", result.stderr)
        # Nothing ships when a distributable guide fails its gate.
        self.assertFalse(any(self.out.glob("*.zip")),
                         str(list(self.out.glob("*"))))


if __name__ == "__main__":
    unittest.main()
