#!/usr/bin/env python3
"""Lists the texts that have no English translation yet.

Reads the .xcloc folders that `xcodebuild -exportLocalizations -exportLanguage en` writes (one for the
app, one for each package) and prints every unit without an English target as a GitHub warning, so a
Turkish text added without its translation shows up on the run. Never fails the build.
"""
import pathlib
import sys
import xml.etree.ElementTree as ET

NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}


def main(root: str) -> None:
    missing = []
    for xliff in sorted(pathlib.Path(root).rglob("*.xliff")):
        for file in ET.parse(xliff).getroot().findall("x:file", NS):
            original = file.get("original", "")
            for unit in file.iter(f"{{{NS['x']}}}trans-unit"):
                source = unit.find("x:source", NS)
                target = unit.find("x:target", NS)
                if target is None or not (target.text or "").strip() or target.get("state") in ("new", "needs-translation"):
                    missing.append((original, unit.get("id", ""), source.text if source is not None else ""))
    for original, uid, source in missing:
        print(f"::warning title=No English translation::{original}: {uid!r} (Turkish: {source!r})")
    print(f"{len(missing)} text(s) without an English translation.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/loc")
