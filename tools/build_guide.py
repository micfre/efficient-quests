#!/usr/bin/env python3
"""Build a guide plugin folder from a cataloged source guide package.

Usage: python3 tools/build_guide.py SOURCE_DIR [--output DIR] [--catalog FILE]
                                 [--date YYYY-MM-DD] | --check-catalog [--catalog FILE]

The builder reads a source guide package directory (a Guidelime-style addon
with a `<name>.toc` and Lua files calling `Guidelime.registerGuide`) plus the
package's entry in the catalog (tools/catalog.json). It writes a ready-to-zip
plugin folder under the output directory; the source package is never changed.

Plugin naming rule: strip the leading Guidelime prefix (either capitalization),
delete the remaining underscores, prefix `EfficientQuests_` (mirroring
Guidelime's own plugin naming). For example `GuideLime_TUGs_Forever` becomes
`EfficientQuests_TUGsForever` and `Guidelime_Bethink` becomes
`EfficientQuests_Bethink`. A name that derives an empty tail is rejected.

The catalog is the supported-guide list, the collision guard, and the release
build list. Each entry holds: `source_package` (the source directory name),
`plugin` (the derived plugin name), `license` (license status string),
`distribute` (release distribution flag; local builds never depend on it), and
`build_suffix` (appended to the source version so rebuilds can be told apart).

The plugin folder contains the generated `<plugin>.toc` manifest and exactly
one Lua file (`Guides.lua`) replaying every source registration call verbatim
as `EfficientQuests_RegisterGuide("<plugin>", <text>, <author>)`. Guide text
and author are copied byte-for-byte; the builder never interprets guide markup.

Manifest fields: `Dependencies: EfficientQuests` (load-order critical),
`X-EfficientQuests-Guide: 1` (the core reads it at login),
`X-EfficientQuests-API: 1` (reserved API marker; emitted, never read),
`Title:` (display name; underscores become spaces), `Version:` (source version
plus the catalog build suffix), and provenance: source name, source version,
source checksum, and build date. The source checksum is the sha256 over each
TOC-listed file's name, digest, and the TOC itself, in TOC order. Rebuilds are
byte-identical when `--date` pins the build date.

A license file found in the package root (LICENSE, LICENCE, COPYING, with or
without .txt, matched case-insensitively) is copied into the plugin unchanged.

The build fails when the TOC lists no files, lists a file outside the package,
contains no registration calls, or declares no version.

Every build then runs the extraction audit (tools/audit_extraction.lua) over
the built plugin itself and writes a per-guide report,
`<plugin>/extraction-audit.json`, into the plugin folder. The audit needs a
Lua 5.1 interpreter: the builder uses `lua5.1` or `lua` from the PATH when
present, otherwise Docker with the same image the Lua suites use. Set
EQ_AUDIT_LUA to force a specific interpreter command.
"""
import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

CORE = "EfficientQuests"
WRAPPER = "Guides.lua"
DEFAULT_CATALOG = Path(__file__).resolve().parent / "catalog.json"
DEFAULT_OUTPUT = "dist"
LICENSE_NAMES = {"license", "license.txt", "licence", "licence.txt", "copying", "copying.txt"}

AUDIT_TOOL = "tools/audit_extraction.lua"
AUDIT_REPORT = "extraction-audit.json"
AUDIT_IMAGE = "nickblah/lua:5.1"
LUA_INTERPRETERS = ("lua5.1", "lua")
AUDIT_TIMEOUT = 300
REPO_ROOT = Path(__file__).resolve().parent.parent

# One pass over every registration call, in file and call order. The author
# argument is optional; text and author are captured as raw bytes so the
# replay stays byte-for-byte. This mirrors the patterns in
# tools/audit_extraction.lua (lines 79 and 83).
CALL = re.compile(rb'Guidelime\.registerGuide\s*\(\s*\[\[(.*?)\]\]\s*(?:,\s*"([^"]*)")?', re.S)

REQUIRED_ENTRY_FIELDS = ("source_package", "plugin", "license", "distribute", "build_suffix")


def plugin_name_for(source_name):
    """Apply the naming rule: strip Guidelime, drop underscores, add the prefix.

    The prefix keeps one underscore, mirroring Guidelime's own plugin naming:
    GuideLime_TUGs_Forever -> EfficientQuests_TUGsForever.
    """
    stripped = re.sub(r"^guidelime", "", source_name, flags=re.I)
    tail = stripped.replace("_", "")
    if not tail:
        raise ValueError("The source name " + source_name + " derives an empty plugin name.")
    return CORE + "_" + tail


def load_catalog(path):
    """Read the catalog and enforce the naming rule and the collision guard."""
    data = json.loads(path.read_text(encoding="utf-8"))
    entries, by_plugin = {}, {}
    for entry in data.get("guides", []):
        missing = [f for f in REQUIRED_ENTRY_FIELDS if f not in entry]
        if missing:
            raise ValueError("A catalog entry is missing fields: " + ", ".join(missing) + ".")
        source, plugin = entry["source_package"], entry["plugin"]
        expected = plugin_name_for(source)
        if plugin != expected:
            raise ValueError("Catalog plugin name " + plugin + " does not match the naming rule ("
                             + expected + ") for " + source + ".")
        if plugin in by_plugin:
            raise ValueError("Catalog collision: " + source + " and "
                             + by_plugin[plugin] + " both derive " + plugin + ".")
        by_plugin[plugin] = source
        entries[source] = entry
    if not entries:
        raise ValueError("The catalog lists no guides.")
    return entries


def locate_toc(package):
    """Find the package TOC: <dirname>.toc, else the sole .toc in the root.

    Bethink ships only Guidelime_Bethink_Camelot.toc, so the directory name
    alone cannot identify the TOC. Several candidates are an error.
    """
    exact = package / (package.name + ".toc")
    if exact.is_file():
        return exact
    candidates = sorted(p for p in package.iterdir() if p.is_file() and p.suffix == ".toc")
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        raise ValueError("The guide's TOC file is missing.")
    raise ValueError("The guide package has several TOC files ("
                     + ", ".join(p.name for p in candidates)
                     + "); pass the package with one <dirname>.toc.")


def parse_toc(package):
    """Return (toc name, raw toc bytes, metadata fields, listed files)."""
    toc = locate_toc(package)
    raw = toc.read_bytes()
    text = raw.decode("utf-8-sig")
    fields, files = {}, []
    for line in text.splitlines():
        name = line.strip()
        if not name:
            continue
        if name.startswith("##"):
            match = re.match(r"^##\s*([A-Za-z-]+)\s*:\s*(.*)$", name)
            if match:
                fields.setdefault(match.group(1).lower(), match.group(2).strip())
            continue
        if name.startswith("#"):
            continue
        normalized = name.replace("\\", "/")
        relative = PurePosixPath(normalized)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe path in guide TOC: " + name)
        path = package.joinpath(*relative.parts)
        if not path.is_file() or not path.resolve().is_relative_to(package.resolve()):
            raise ValueError("Listed guide file is missing or outside the package: " + name)
        files.append((normalized, path))
    if not files:
        raise ValueError("The guide TOC lists no files.")
    return toc.name, raw, fields, files


def extract_calls(files):
    """Capture (text, author-or-None) for every registration call, byte-for-byte."""
    calls = []
    for _, path in files:
        for match in CALL.finditer(path.read_bytes()):
            calls.append((match.group(1), match.group(2)))
    if not calls:
        raise ValueError("The source package contains no Guidelime.registerGuide calls.")
    return calls


def source_checksum(toc_name, toc_raw, files):
    """Hash the package shape: each listed file's name and digest, then the TOC."""
    digest = hashlib.sha256()

    def add(name, data):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(data).hexdigest().encode("ascii"))
        digest.update(b"\0")

    for name, path in files:
        add(name, path.read_bytes())
    add(toc_name, toc_raw)
    return digest.hexdigest()


def find_license(package):
    """Find a license file in the package root, case-insensitively."""
    for entry in sorted(p for p in package.iterdir() if p.is_file()):
        if entry.name.lower() in LICENSE_NAMES:
            return entry
    return None


def build_date(value):
    if value:
        datetime.strptime(value, "%Y-%m-%d")
        return value
    return datetime.now(timezone.utc).date().isoformat()


def compose_toc(package_name, plugin, fields, plugin_version, checksum, date):
    lines = []

    def field(name, value):
        if value:
            lines.append("## " + name + ": " + value)

    field("Interface", fields.get("interface"))
    lines.append("## Title: " + plugin.replace("_", " "))
    field("Notes", fields.get("notes"))
    field("Author", fields.get("author"))
    lines.append("## Version: " + plugin_version)
    lines.append("## Dependencies: " + CORE)
    lines.append("## X-EfficientQuests-Guide: 1")
    lines.append("## X-EfficientQuests-API: 1")
    lines.append("## X-EfficientQuests-Source-Name: " + package_name)
    lines.append("## X-EfficientQuests-Source-Version: " + fields["version"])
    lines.append("## X-EfficientQuests-Source-Checksum: " + checksum)
    lines.append("## X-EfficientQuests-Build-Date: " + date)
    lines.append("")
    lines.append(WRAPPER)
    return ("\n".join(lines) + "\n").encode("utf-8")


def compose_wrapper(plugin, calls):
    parts = []
    for text, author in calls:
        call = (b'EfficientQuests_RegisterGuide("' + plugin.encode("ascii")
                + b'", [[' + text + b']]')
        if author is not None:
            call += b', "' + author + b'"'
        parts.append(call + b")\n")
    return b"".join(parts)


def audit_command(plugin):
    """Build the command line that runs the audit over a built plugin folder.

    A Lua 5.1 interpreter on the PATH (lua5.1, then lua; or the command in
    EQ_AUDIT_LUA) is preferred. Without one, the audit runs under Docker with
    the same image the Lua suites use: the worktree is mounted at /w and the
    plugin, when it lives outside the worktree, is mounted at /eqout.
    """
    plugin = plugin.resolve()
    tail = [AUDIT_TOOL, None, "--json"]
    forced = os.environ.get("EQ_AUDIT_LUA")
    if forced:
        tail[1] = str(plugin)
        return shlex.split(forced) + tail, REPO_ROOT
    for interpreter in LUA_INTERPRETERS:
        if shutil.which(interpreter):
            tail[1] = str(plugin)
            return [interpreter] + tail, REPO_ROOT
    if shutil.which("docker"):
        mounts = ["--volume", str(REPO_ROOT) + ":/w"]
        try:
            inside = str(plugin.relative_to(REPO_ROOT))
        except ValueError:
            mounts += ["--volume", str(plugin.parent) + ":/eqout"]
            inside = "/eqout/" + plugin.name
        tail[1] = inside
        return (["docker", "run", "--rm"] + mounts
                + ["--workdir", "/w", AUDIT_IMAGE, "lua"] + tail), REPO_ROOT
    raise ValueError("No Lua 5.1 interpreter or Docker found; the extraction"
                     " audit cannot run. Install lua5.1 or Docker, or set EQ_AUDIT_LUA.")


def run_audit(plugin):
    """Run the extraction audit over the built plugin and return its result."""
    command, cwd = audit_command(plugin)
    try:
        completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True,
                                   timeout=AUDIT_TIMEOUT)
    except (OSError, subprocess.SubprocessError) as exc:
        raise ValueError("The extraction audit could not run (" + " ".join(command[:3])
                         + "): " + str(exc))
    if completed.returncode != 0:
        raise ValueError("The extraction audit exited with status "
                         + str(completed.returncode) + ": " + _detail(completed))
    try:
        document = json.loads(completed.stdout)
    except ValueError as exc:
        raise ValueError("The extraction audit produced no readable report: "
                         + _detail(completed))
    packages = document.get("packages", [])
    if len(packages) != 1 or packages[0].get("error"):
        raise ValueError("The extraction audit did not audit the built plugin: "
                         + _detail(completed))
    return packages[0]


def _detail(completed, limit=400):
    note = (completed.stderr or "").strip() or (completed.stdout or "").strip()
    return " ".join(note.split())[:limit]


def evaluate_gates(audit):
    """Turn one audit result into build failures and warnings.

    Failures: the audit extracted no advice record from any character
    context. Warnings: none yet.
    """
    failures = []
    if audit["advice_records"] == 0:
        failures.append("the audit extracted no advice records from any context")
    return failures, []


def compose_report(plugin, package_name, fields, plugin_version, date, audit):
    """The per-guide extraction audit report shipped inside the plugin."""
    failures, warnings = evaluate_gates(audit)
    return {
        "plugin": plugin,
        "source_package": package_name,
        "source_version": fields["version"],
        "plugin_version": plugin_version,
        "build_date": date,
        "audit": {
            "guides": audit["guides"],
            "lines": audit["lines"],
            "candidate_lines": audit["candidate_lines"],
            "withheld_lines": audit["withheld_lines"],
            "advice_records": audit["advice_records"],
            "records_by_kind": audit["records_by_kind"],
            "associations": audit["associations"],
            "per_context": audit["per_context"],
            "findings": audit["findings"],
            "findings_by_severity": audit["findings_by_severity"],
        },
        "gates": {"failures": failures, "warnings": warnings},
    }


def build(source, entry, output, date):
    toc_name, raw, fields, files = parse_toc(source)
    if not fields.get("version"):
        raise ValueError("The source TOC declares no ## Version.")
    calls = extract_calls(files)
    plugin = entry["plugin"]
    plugin_version = fields["version"] + entry["build_suffix"]
    checksum = source_checksum(toc_name, raw, files)
    toc = compose_toc(source.name, plugin, fields, plugin_version, checksum, date)
    wrapper = compose_wrapper(plugin, calls)

    target = output / plugin
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    (target / (plugin + ".toc")).write_bytes(toc)
    (target / WRAPPER).write_bytes(wrapper)
    license_source = find_license(source)
    if license_source:
        shutil.copyfile(license_source, target / license_source.name)
    try:
        audit = run_audit(target)
    except ValueError:
        shutil.rmtree(target, ignore_errors=True)
        raise
    failures, warnings = evaluate_gates(audit)
    if failures:
        shutil.rmtree(target, ignore_errors=True)
        raise ValueError("extraction audit gate: " + "; ".join(failures))
    (target / AUDIT_REPORT).write_text(
        json.dumps(compose_report(plugin, source.name, fields, plugin_version, date, audit),
                   indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for warning in warnings:
        print("Guide plugin build: warning: " + warning, file=sys.stderr)
    print("Built " + plugin + " " + plugin_version + " (" + str(len(calls))
          + " guides) in " + str(target))
    print("Extraction audit: " + str(audit["guides"]) + " guides, "
          + str(audit["advice_records"]) + " advice records, "
          + str(len(audit["findings"])) + " findings.")
    if license_source:
        print("Bundled license file " + license_source.name + ".")
    if not entry["distribute"]:
        print("Distribution flag is off; keep this build local.")
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("source", nargs="?", type=Path,
                       help="source guide package directory")
    group.add_argument("--check-catalog", action="store_true",
                       help="validate the catalog and exit")
    parser.add_argument("--output", type=Path, default=Path(DEFAULT_OUTPUT),
                        help="output directory (default: %(default)s)")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG,
                        help="catalog file (default: %(default)s)")
    parser.add_argument("--date", help="build date override, YYYY-MM-DD")
    args = parser.parse_args()
    try:
        entries = load_catalog(args.catalog)
        if args.check_catalog:
            for name in sorted(entries):
                entry = entries[name]
                print(name + " -> " + entry["plugin"] + " (" + entry["license"] + ")")
            return 0
        if not args.source.is_dir():
            raise ValueError("The source package directory does not exist: " + str(args.source))
        if args.source.name not in entries:
            raise ValueError(args.source.name + " is not in the catalog.")
        build(args.source, entries[args.source.name], args.output, build_date(args.date))
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print("Guide plugin build: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
