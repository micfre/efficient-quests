#!/usr/bin/env python3
"""Adapt a locally installed TUG Forever guide without changing its guide text."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath

PACKAGE = "GuideLime_TUGs_Forever"
BEGIN = "EQ_Guide_Begin.lua"
END = "EQ_Guide_End.lua"
MANIFEST = "EQ_Guide_Adaptation.json"
MARKER = "## X-EfficientQuests-Adaptation: 1"

# The temporary proxy exists only while this addon's TOC is being loaded.
# OptionalDeps ensures a real Guidelime, when enabled, loads before the proxy.
BEGIN_LUA = '''-- Efficient Quests guide adapter, version 1.
local original = _G.Guidelime
local proxy = {}
setmetatable(proxy, { __index = original })
proxy.registerGuide = function(...)
    if _G.EfficientQuests_RegisterGuide then
        _G.EfficientQuests_RegisterGuide("GuideLime_TUGs_Forever", ...)
    end
    if original and original.registerGuide then
        return original.registerGuide(...)
    end
end
_G.EfficientQuests_GuideAdapterOriginal = original or false
_G.Guidelime = proxy
'''
END_LUA = '''-- Restore the real Guidelime global after this guide has loaded.
_G.Guidelime = _G.EfficientQuests_GuideAdapterOriginal or nil
_G.EfficientQuests_GuideAdapterOriginal = nil
'''


def digest(data):
    return hashlib.sha256(data).hexdigest()


def locate(package):
    if package.name != PACKAGE or not package.is_dir():
        raise ValueError("Select the installed GuideLime_TUGs_Forever folder.")
    toc = package / (PACKAGE + ".toc")
    if not toc.is_file():
        raise ValueError("The guide's TOC file is missing.")
    return toc


def files_from_toc(package, lines):
    files = []
    for line in lines:
        name = line.strip()
        if not name or name.startswith("#") or name in (BEGIN, END):
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
    return files


def adapted_toc(raw):
    text = raw.decode("utf-8-sig")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines()
    result, required, optional = [], [], []
    for line in lines:
        stripped = line.strip()
        if stripped in (MARKER, BEGIN, END):
            continue
        match = re.match(r"^\s*##\s*(Dependencies|RequiredDeps|OptionalDeps)\s*:\s*(.*)$", line, re.I)
        if match:
            target = optional if match.group(1).lower() == "optionaldeps" else required
            target.extend(v.strip() for v in re.split(r"[,;]", match.group(2)) if v.strip())
        else:
            result.append(line)
    required = [x for x in required if x.lower() not in ("guidelime", "efficientquests")]
    optional = [x for x in optional if x.lower() not in ("guidelime", "efficientquests")]
    required.append("EfficientQuests")
    optional.append("Guidelime")
    metadata = [MARKER, "## Dependencies: " + ", ".join(required),
                "## OptionalDeps: " + ", ".join(optional)]
    # Insert before the first file: metadata must precede file entries.
    first = next((i for i, line in enumerate(result)
                  if line.strip() and not line.lstrip().startswith("#")), len(result))
    result[first:first] = metadata + [BEGIN]
    result.append(END)
    return (newline.join(result) + newline).encode("utf-8")


def inventory(package, toc_bytes):
    lines = toc_bytes.decode("utf-8-sig").splitlines()
    files = files_from_toc(package, lines)
    checksums = {name: digest(path.read_bytes()) for name, path in files}
    checksums[package.name + ".toc"] = digest(toc_bytes)
    checksums[BEGIN] = digest((package / BEGIN).read_bytes())
    checksums[END] = digest((package / END).read_bytes())
    return {"version": 1, "checksums": checksums}


def adapt(package):
    toc = locate(package)
    updated = adapted_toc(toc.read_bytes())
    files_from_toc(package, updated.decode("utf-8").splitlines())
    (package / BEGIN).write_text(BEGIN_LUA, encoding="utf-8")
    (package / END).write_text(END_LUA, encoding="utf-8")
    toc.write_bytes(updated)
    manifest = inventory(package, updated)
    (package / MANIFEST).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("Guide adapted. Restart the game or reload addons.")


def check(package):
    toc = locate(package)
    manifest_path = package / MANIFEST
    if not manifest_path.is_file():
        raise ValueError("Guide adaptation is missing; run adapt.")
    expected = json.loads(manifest_path.read_text(encoding="utf-8"))
    raw = toc.read_bytes()
    if MARKER not in raw.decode("utf-8-sig") or inventory(package, raw) != expected:
        raise ValueError("Guide adaptation or source changed; run adapt again.")
    print("Guide adaptation is current.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("adapt", "check"))
    parser.add_argument("package", type=Path, help="installed GuideLime_TUGs_Forever directory")
    args = parser.parse_args()
    try:
        {"adapt": adapt, "check": check}[args.action](args.package)
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print("Guide adaptation: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
