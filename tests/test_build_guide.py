"""Exercise the guide plugin builder as a release builder (seam 1: subprocess)."""
import json
import re
import shutil
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
                         {self.plugin_name + ".toc", "Guides.lua",
                          "extraction-audit.json"})

    def test_manifest_fields(self):
        self.assertEqual(self.build().returncode, 0)
        toc = (self.out / self.plugin_name / (self.plugin_name + ".toc")).read_text()
        expected = {
            "Interface": "16001",
            "Title": "Fixture Guide",
            "Notes": "Fixture notes",
            "Author": "Fixture Author",
            "Version": "1.28-eq1",
            "Dependencies": "EfficientQuests",
            "X-EfficientQuests-Guide": "1",
            "X-EfficientQuests-API": "1",
            "X-EfficientQuests-Source-Name": "GuideLime_Fixture_One",
            "X-EfficientQuests-Source-Version": "1.28",
            "X-EfficientQuests-Build-Date": BUILD_DATE,
        }
        for field, value in expected.items():
            self.assertIn("## " + field + ": " + value, toc, field)
        self.assertIsNotNone(
            re.search(r"^## X-EfficientQuests-Source-Checksum: [0-9a-f]{64}$", toc, re.M),
            "source checksum field must be a sha256 hex digest")
        file_lines = [l.strip() for l in toc.splitlines()
                      if l.strip() and not l.strip().startswith("#")]
        self.assertEqual(file_lines, ["Guides.lua"])
        self.assertNotIn("OptionalDeps", toc)
        self.assertNotIn("Guidelime,", toc)

    def test_title_falls_back_to_derived_name_when_source_declares_none(self):
        self.toc.write_bytes(self.toc.read_bytes().replace(b"## Title: Fixture Guide\r\n", b""))
        self.assertEqual(self.build().returncode, 0)
        toc = (self.out / self.plugin_name / (self.plugin_name + ".toc")).read_text()
        self.assertIn("## Title: EfficientQuests FixtureOne", toc)

    def test_wrapper_replays_calls_verbatim(self):
        self.assertEqual(self.build().returncode, 0)
        wrapper = (self.out / self.plugin_name / "Guides.lua").read_bytes()
        self.assertEqual(wrapper.count(b"EfficientQuests_RegisterGuide("), 3)
        # Text and author are byte-for-byte: CRLF bodies stay CRLF, and the
        # author-less call is replayed without an author argument.
        self.assertIn(b'EfficientQuests_RegisterGuide("EfficientQuests_FixtureOne", '
                      b'[[\r\n[GA Alliance]\r\n[N1 Something]\r\nKeep 5 apples.\r\n]], '
                      b'"Fixture")', wrapper)
        self.assertIn(b'EfficientQuests_RegisterGuide("EfficientQuests_FixtureOne", '
                      b'[[Pick 2 flowers]], "Fixture")', wrapper)
        self.assertIn(b'EfficientQuests_RegisterGuide("EfficientQuests_FixtureOne", '
                      b'[[No author here]])', wrapper)
        self.assertNotIn(b"Do not load me", wrapper)
        self.assertNotIn(b"Guidelime.registerGuide", wrapper)

    def test_source_package_is_never_modified(self):
        before = {p: p.read_bytes() for p in self.source.rglob("*") if p.is_file()}
        self.assertEqual(self.build().returncode, 0)
        after = {p: p.read_bytes() for p in self.source.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_rebuild_is_byte_identical(self):
        self.assertEqual(self.build().returncode, 0)
        first = {p.relative_to(self.out): p.read_bytes() for p in self.out.rglob("*") if p.is_file()}
        shutil.rmtree(self.out)
        self.assertEqual(self.build().returncode, 0)
        second = {p.relative_to(self.out): p.read_bytes() for p in self.out.rglob("*") if p.is_file()}
        self.assertEqual(first, second)


class LicensedFixture(unittest.TestCase):
    """A synthetic package styled after Bethink (lowercase prefix, LF, GPLv3 LICENSE)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / "Guidelime_Licensed"
        self.source.mkdir()
        (self.source / "Guidelime_Licensed.toc").write_bytes(
            b"## Title: Licensed Guide\n## Interface: 16001\n## Version: 2.0\n"
            b"## X-License: GPLv3\n\nguide.lua\n")
        (self.source / "guide.lua").write_bytes(
            b'Guidelime.registerGuide([[Buy 1 sword]], "Someone")\n')
        self.license_bytes = b"GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007\n"
        (self.source / "LICENSE").write_bytes(self.license_bytes)
        self.catalog = self.root / "catalog.json"
        self.catalog.write_text(json.dumps({"version": 1, "guides": [
            {"source_package": "Guidelime_Licensed", "plugin": "EfficientQuests_Licensed",
             "license": "GPLv3", "distribute": True, "build_suffix": "-eq3"}]},
            indent=2, sort_keys=True) + "\n", encoding="utf-8")
        self.out = self.root / "out"

    def build(self):
        return subprocess.run(
            [sys.executable, str(TOOL), str(self.source), "--catalog", str(self.catalog),
             "--output", str(self.out), "--date", BUILD_DATE],
            text=True, capture_output=True)

    def test_license_is_copied_and_version_carries_suffix(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        plugin = self.out / "EfficientQuests_Licensed"
        self.assertEqual((plugin / "LICENSE").read_bytes(), self.license_bytes)
        toc = (plugin / "EfficientQuests_Licensed.toc").read_text()
        self.assertIn("## Version: 2.0-eq3", toc)
        self.assertNotIn("X-License", toc)


class GuardTests(BuilderFixture):
    """The builder refuses unsafe or unsupported inputs with a non-zero exit."""

    def test_path_traversal_in_toc_is_rejected(self):
        self.toc.write_bytes(self.toc.read_bytes().replace(b"chapters\\one.lua", b"../escape.lua"))
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe", result.stderr.lower())

    def test_absolute_path_in_toc_is_rejected(self):
        self.toc.write_bytes(self.toc.read_bytes().replace(b"chapters\\one.lua", b"/etc/hosts"))
        result = self.build()
        self.assertNotEqual(result.returncode, 0)

    def test_missing_listed_file_is_rejected(self):
        (self.source / "chapters" / "one.lua").unlink()
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing or outside", result.stderr)

    def test_catalog_collision_is_rejected(self):
        # Underscore variants of one name both derive the same plugin name.
        catalog = self.write_catalog([
            {"source_package": self.source_name, "plugin": self.plugin_name,
             "license": "All rights reserved", "distribute": False, "build_suffix": "-eq1"},
            {"source_package": "GuideLime_FixtureOne", "plugin": self.plugin_name,
             "license": "GPLv3", "distribute": True, "build_suffix": "-eq1"}])
        result = self.build(catalog=catalog)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("collision", result.stderr.lower())

    def test_uncatalogued_source_is_rejected(self):
        result = self.build(catalog=self.write_catalog([
            {"source_package": "GuideLime_Other", "plugin": "EfficientQuests_Other",
             "license": "GPLv3", "distribute": True, "build_suffix": "-eq1"}]))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("catalog", result.stderr.lower())
        self.assertFalse((self.out / self.plugin_name).exists())

    def test_zero_registration_calls_is_rejected(self):
        (self.source / "chapters" / "one.lua").write_bytes(b"-- no calls here\n")
        (self.source / "chapters" / "two.lua").write_bytes(b"-- none here either\n")
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no Guidelime.registerGuide calls", result.stderr)

    def test_missing_source_version_is_rejected(self):
        self.toc.write_bytes(self.toc.read_bytes().replace(b"## Version: 1.28\r\n", b""))
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Version", result.stderr)

    def test_uniquely_named_toc_is_used_when_dirname_toc_is_absent(self):
        """Bethink ships Guidelime_Bethink_Camelot.toc, not Guidelime_Bethink.toc."""
        self.toc.rename(self.source / "GuideLime_Fixture_Camelot.toc")
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.out / self.plugin_name / "Guides.lua").is_file())

    def test_ambiguous_tocs_are_rejected(self):
        self.toc.rename(self.source / "GuideLime_Fixture_Camelot.toc")
        (self.source / "GuideLime_Fixture_Modern.toc").write_bytes(
            b"## Version: 1.28\r\nlisted.lua\r\n")
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("toc", result.stderr.lower())


class AuditGateTests(BuilderFixture):
    """The extraction gate: every build audits the built plugin itself."""

    def report(self):
        return json.loads((self.out / self.plugin_name / "extraction-audit.json")
                          .read_text(encoding="utf-8"))

    def set_single_guide(self, body):
        """Rewrite the fixture source with one guide chapter of the given bytes."""
        (self.source / "chapters" / "one.lua").write_bytes(
            b'Guidelime.registerGuide([[' + body + b']], "Fixture")\n')
        (self.source / "chapters" / "two.lua").write_bytes(b"")

    def test_healthy_build_writes_extraction_audit_report(self):
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["plugin"], self.plugin_name)
        self.assertEqual(report["source_package"], self.source_name)
        self.assertEqual(report["plugin_version"], "1.28-eq1")
        self.assertEqual(report["build_date"], BUILD_DATE)
        audit = report["audit"]
        # The audit read the built wrapper: all three replayed calls,
        # including the author-less one, registered as guides.
        self.assertEqual(audit["guides"], 3)
        self.assertGreater(audit["advice_records"], 0)
        self.assertEqual(audit["findings"], [])

    def test_zero_advice_guide_fails_the_build_with_no_artifact(self):
        self.set_single_guide(b"\n[GA Alliance]\n[N1 Empty]\n"
                              b"Just walk north and enjoy the view.\n")
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no advice", result.stderr.lower())
        self.assertFalse((self.out / self.plugin_name).exists())

    def test_safety_screen_trip_fails_the_build_with_no_artifact(self):
        # The conditional-prefix path of the extraction can carry a screened
        # phrase into the visible text; the ROUTE finding must stop the build.
        self.set_single_guide(b"\n[GA Alliance]\n[N1 Route]\n"
                              b"If you are done with this guide, buy 5 apples. "
                              b"Also save 10 silks.\n")
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ROUTE", result.stderr)
        self.assertFalse((self.out / self.plugin_name).exists())

    def test_low_yield_guide_builds_with_a_warning(self):
        # Three of four candidate lines are withheld (route-dependent and
        # progression shopping); a majority-withheld guide warns, not fails.
        self.set_single_guide(b"\n[GA Alliance]\n[N1 Yield]\n"
                              b"Keep 5 apples.\n"
                              b"Last chance to buy arrows.\n"
                              b"Keep an eye out for rare spawns.\n"
                              b"Buy a skinning knife.\n")
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("yield", result.stderr.lower())
        self.assertIn("3 of 4", result.stderr)
        report = self.report()
        self.assertEqual(report["gates"]["warnings"],
                         ["low yield: the audit withheld 3 of 4 candidate advice lines"])


class GateScreenTests(unittest.TestCase):
    """The safety screen fails closed at the evaluate_gates seam.

    The audit tool has a closed severity vocabulary, so a severity name
    that the builder does not know yet cannot come out of a real audit
    run. That unknown name is exactly what the screen must catch, so the
    screen is proven here against a synthetic finding.
    """

    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(TOOL.parent))
        cls.build_guide = __import__("build_guide")

    @classmethod
    def tearDownClass(cls):
        sys.path.remove(str(TOOL.parent))

    def audit_with(self, severity):
        return {"guides": 1, "lines": 1, "advice_records": 1,
                "records_by_kind": {}, "associations": {}, "per_context": {},
                "findings_by_severity": {severity: 1},
                "findings": [{"severity": severity, "where": "Guides.lua:1",
                              "id": "G1", "detail": "synthetic finding"}],
                "candidate_lines": 4, "withheld_lines": 1}

    def test_unknown_severity_fails_the_safety_screen(self):
        failures, _ = self.build_guide.evaluate_gates(self.audit_with("FUTURE"))
        self.assertTrue(failures,
                        "a severity the builder does not know must fail the build")

    def test_watch_stays_advisory(self):
        failures, _ = self.build_guide.evaluate_gates(self.audit_with("WATCH"))
        self.assertEqual(failures, [])

    def test_report_names_the_advisory_severities(self):
        report = self.build_guide.compose_report(
            "EfficientQuests_X", "GuideLime_X", {"version": "1"}, "1-eq1",
            BUILD_DATE, self.audit_with("WATCH"))
        self.assertEqual(report["gates"]["advisory_severities"], ["WATCH"])


class CatalogTests(unittest.TestCase):
    """The shipped catalog must stay valid and list the ticket's two guides."""

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(TOOL), *args],
                              text=True, capture_output=True)

    def test_real_catalog_is_valid_and_lists_both_guides(self):
        result = self.run_tool("--check-catalog")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("GuideLime_TUGs_Forever -> EfficientQuests_TUGsForever", result.stdout)
        self.assertIn("Guidelime_Bethink -> EfficientQuests_Bethink", result.stdout)
        entries = {e["source_package"]: e
                   for e in json.loads(REAL_CATALOG.read_text(encoding="utf-8"))["guides"]}
        self.assertFalse(entries["GuideLime_TUGs_Forever"]["distribute"])
        self.assertTrue(entries["Guidelime_Bethink"]["distribute"])
        self.assertEqual(entries["Guidelime_Bethink"]["license"], "GPLv3")

    def test_empty_derived_name_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            catalog = Path(tmp) / "catalog.json"
            catalog.write_text(json.dumps({"version": 1, "guides": [
                {"source_package": "Guidelime", "plugin": "EfficientQuests_",
                 "license": "GPLv3", "distribute": True, "build_suffix": "-eq1"}]}), encoding="utf-8")
            result = self.run_tool("--check-catalog", "--catalog", str(catalog))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("empty", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
