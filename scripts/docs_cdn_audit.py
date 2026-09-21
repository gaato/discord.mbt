#!/usr/bin/env python3
"""Audit src/util/cdn.mbt against the CDN Endpoints table in the Discord docs.

Every row of the table in developers/reference.mdx must have a URL builder
whose path matches, so a route Discord adds later is reported instead of
waiting for a bot to need it.

Usage: scripts/docs_cdn_audit.py [DOCS_REPO]   (default ~/ghq/github.com/discord/discord-api-docs)
Exceptions live in scripts/docs_cdn_audit.allow ("Type name  # reason").
Exit status is 1 when an unexplained row remains.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    pathlib.Path.home() / "ghq/github.com/discord/discord-api-docs")
ALLOW = ROOT / "scripts/docs_cdn_audit.allow"


def docs_rows():
    lines = (DOCS / "developers/reference.mdx").read_text().splitlines()
    start = next(i for i, line in enumerate(lines) if "**CDN Endpoints**" in line)
    rows = []
    for line in lines[start + 1:]:
        if not line.startswith("|"):
            if rows:
                break
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if cells[0] == "Type" or set(cells[0]) <= set("-: "):
            continue
        path = re.sub(r"\\\*", "", cells[1]).strip()
        path = re.sub(r"\[[^\]]*\]\([^)]*\)", "{}", path)
        path = re.sub(r"\.png$", "", path)
        # The Store Page Asset row names its placeholder without a link.
        path = re.sub(r"/[a-z_]+$", "/{}", path)
        rows.append((cells[0], path))
    return rows


def main():
    source = (ROOT / "src/util/cdn.mbt").read_text()
    source = re.sub(r"\\\{[^}]*\}", "{}", source)
    allowed = set()
    if ALLOW.exists():
        for line in ALLOW.read_text().splitlines():
            name = line.split("#")[0].strip()
            if name:
                allowed.add(name)
    missing = []
    for name, path in docs_rows():
        directory = path[:-3] if path.endswith("/{}") else None
        found = path in source or (directory and f'"{directory}"' in source)
        if found and name in allowed:
            print(f"STALE ALLOW  {name}")
            missing.append(name)
        elif not found and name not in allowed:
            print(f"MISSING  {name}  {path}")
            missing.append(name)
    if missing:
        sys.exit(1)
    print("CDN endpoints: OK")


if __name__ == "__main__":
    main()
