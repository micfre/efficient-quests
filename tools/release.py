#!/usr/bin/env python3
"""Build the release zips: the core addon plus every distributable guide.

Usage: python3 tools/release.py --sources DIR [--output DIR]
                                  [--catalog FILE] [--date YYYY-MM-DD]

The release zips the core addon folder (dist/EfficientQuests) and, for every
catalog guide whose `distribute` flag is on, builds the guide plugin with the
real builder (tools/build_guide.py, including its extraction-audit gate) and
zips the plugin folder with its extraction-audit.json report inside. A guide
whose distribution flag is off is built for the release log but produces no
zip: the license gate holds it back, and local dev builds never depend on the
flag.

The source guide packages are never part of the repository. `--sources` names
the directory that holds them (locally the git-ignored prior_art copy); the
path is never assumed. A distributable guide whose source package is missing
fails the release before anything is built or zipped: a release that silently
ships less than the catalog promises is worse than an error. A held-back
guide that is missing, or that fails its build gate, only prints a note or a
warning; it never blocks the release because it never ships.

Zips land in the output directory (default: dist, git-ignored); the built
plugin folders stay beside them under `builds/`. Zip entries carry a fixed
timestamp and permissions, and files are added in sorted order, so a rerun
with the same `--date` produces byte-identical zips. Every EfficientQuests*
zip left in the output root by an earlier run is removed first, so after a
run the zips present are exactly the ones the current catalog distributes.

The release fails (exit 1) when the catalog is invalid, a distributable
source package is missing, a distributable guide fails its build gate, or the
core addon cannot be read.
"""
import argparse
import json
import re
import sys
import zipfile
from pathlib import Path

import build_guide  # tools/build_guide.py, the real builder

CORE = "EfficientQuests"
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = "dist"
CORE_DIR = REPO_ROOT / DEFAULT_OUTPUT / CORE
CORE_TOC = CORE_DIR / (CORE + ".toc")
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def core_version():
    """Read the addon version from the core TOC (the single version source)."""
    match = re.search(r"^##\s*Version\s*:\s*(\S+)$",
                      CORE_TOC.read_text(encoding="utf-8"), re.M)
    if not match:
        raise ValueError("The core TOC declares no ## Version.")
    return match.group(1)


def zip_folder(folder, arc_root, dest):
    """Zip one folder's files deterministically under arc_root/."""
    files = sorted(p for p in folder.rglob("*") if p.is_file())
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            info = zipfile.ZipInfo(
                arc_root + "/" + path.relative_to(folder).as_posix(),
                date_time=ZIP_TIMESTAMP)
            info.external_attr = 0o644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    return dest


def plugin_version(plugin_folder):
    """Read the built plugin's version from its extraction-audit report."""
    report = json.loads(
        (plugin_folder / build_guide.AUDIT_REPORT).read_text(encoding="utf-8"))
    return report["plugin_version"]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sources", type=Path, required=True,
                        help="directory holding the cataloged source packages")
    parser.add_argument("--output", type=Path, default=Path(DEFAULT_OUTPUT),
                        help="release output directory (default: %(default)s)")
    parser.add_argument("--catalog", type=Path, default=build_guide.DEFAULT_CATALOG,
                        help="catalog file (default: %(default)s)")
    parser.add_argument("--date", help="build date override, YYYY-MM-DD")
    args = parser.parse_args()
    try:
        entries = build_guide.load_catalog(args.catalog)
        if not args.sources.is_dir():
            raise ValueError("The sources directory does not exist: "
                             + str(args.sources))
        shipped = sorted((e for e in entries.values() if e["distribute"]),
                         key=lambda e: e["source_package"])
        missing = [e["source_package"] for e in shipped
                   if not (args.sources / e["source_package"]).is_dir()]
        if missing:
            raise ValueError("source package missing for distributable guide: "
                             + ", ".join(missing) + " (looked in " + str(args.sources) + ")")
        args.output.mkdir(parents=True, exist_ok=True)
        builds = args.output / "builds"

        # Build first, zip after: nothing is zipped unless every distributable
        # guide passed the builder's extraction-audit gate.
        zips, held, to_zip = [], [], []
        for entry in sorted(entries.values(), key=lambda e: e["source_package"]):
            plugin = entry["plugin"]
            source = args.sources / entry["source_package"]
            if not source.is_dir():
                # Only distributable guides are required (the preflight above);
                # a held-back guide that is absent locally simply does not ship.
                print("Note: source package " + entry["source_package"]
                      + " (" + plugin + ") is missing from " + str(args.sources)
                      + "; not shipped, release continues.")
                held.append(plugin)
                continue
            try:
                build_guide.build(source, entry, builds,
                                  build_guide.build_date(args.date))
            except ValueError as exc:
                if entry["distribute"]:
                    raise ValueError(plugin + " (" + entry["source_package"]
                                     + ") failed its build gate: " + str(exc))
                print("Warning: local-only guide " + plugin
                      + " failed its build gate and is not shipped; the"
                      + " release continues: " + str(exc))
                held.append(plugin)
                continue
            if entry["distribute"]:
                to_zip.append(entry)
            else:
                held.append(plugin)
                print("License gate: distribution flag is off for " + plugin
                      + "; built for the log, no zip.")

        # This script owns the EfficientQuests*.zip namespace in the output
        # root. Sweeping it keeps a flag flip from leaving the previous
        # release's zip behind: after a run, the zips present are exactly the
        # ones this catalog distributes. Unrelated files are never touched.
        for stale in sorted(args.output.glob(CORE + "*.zip")):
            stale.unlink()
            print("Removed stale release zip: " + stale.name)

        core_zip = zip_folder(CORE_DIR, CORE,
                              args.output / (CORE + "-" + core_version() + ".zip"))
        print("Core zip: " + str(core_zip))
        zips.append(core_zip.name)
        for entry in to_zip:
            plugin = entry["plugin"]
            folder = builds / plugin
            dest = zip_folder(folder, plugin, args.output
                              / (plugin + "-" + plugin_version(folder) + ".zip"))
            zips.append(dest.name)
            print("Guide zip: " + str(dest))
        print("Release zips in " + str(args.output) + ": " + ", ".join(zips))
        if held:
            print("Held back (distribution flag off): " + ", ".join(sorted(held)))
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print("Release: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
