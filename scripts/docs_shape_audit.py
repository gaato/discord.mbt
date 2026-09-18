#!/usr/bin/env python3
"""Audit receive-side model shapes against the official Discord docs tables.

For every `pub(all) struct` in src/model, find the docs field table (a table
whose first header is "Field") whose field set matches best, then report fields whose optionality or
nullability is stricter in the model than in the docs:

  NULLABLE  docs type is `?T` but the model field is not `Nullable[...]`
  OPTIONAL  docs field is `name?` but the model field is not `T?`

Usage: scripts/docs_shape_audit.py [DOCS_REPO]   (default ~/ghq/github.com/discord/discord-api-docs)
Exceptions live in scripts/docs_shape_audit.allow ("Struct.field KIND  # reason").
Exit status is 1 when an unexplained finding remains.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    pathlib.Path.home() / "ghq/github.com/discord/discord-api-docs")
ALLOW = ROOT / "scripts/docs_shape_audit.allow"
MIN_SCORE = 0.6
MIN_SHARED = 3


def docs_tables():
    tables = {}
    for path in sorted((DOCS / "developers").rglob("*.mdx")):
        lines = path.read_text().splitlines()
        i = 0
        while i < len(lines):
            m = re.match(r"#{4,6}\s+(.*)$", lines[i])
            if not m:
                i += 1
                continue
            title = m.group(1).strip()
            j = i + 1
            while j < len(lines) and not lines[j].startswith("|"):
                if lines[j].startswith("#"):
                    break
                j += 1
            fields = {}
            header = True
            while j < len(lines) and lines[j].startswith("|"):
                cells = [c.strip() for c in lines[j].strip("|").split("|")]
                j += 1
                if header:
                    header = False
                    if cells[0].lower() != "field":
                        break
                    continue
                if set(cells[0]) <= set("-: "):
                    continue
                if len(cells) < 2:
                    continue
                raw = cells[0].replace("\\", "")
                name = re.sub(r"[*]+", "", raw).strip()
                optional = name.endswith("?")
                name = name.rstrip("?").strip()
                if not re.fullmatch(r"[a-z0-9_]+", name):
                    continue
                typ = cells[1].replace("\\", "").strip()
                fields[name] = (optional, typ.startswith("?"))
            if fields:
                key = f"{path.relative_to(DOCS)}#{title}"
                tables[key] = fields
            i = j
    return tables


FIELD_RE = re.compile(r"^\s{2}([a-z_][a-z0-9_]*)\s*:\s*(.+?)\s*$")


def model_structs():
    structs = {}
    for path in sorted((ROOT / "src/model").glob("*.mbt")):
        if path.name.endswith(("_test.mbt", "_wbtest.mbt")):
            continue
        text = path.read_text()
        for m in re.finditer(r"pub\(all\) struct (\w+)(?:\[[^\]]*\])? \{\n(.*?)\n\}(.*?)\n", text, re.S):
            name, body, derive = m.group(1), m.group(2), m.group(3)
            if "FromJson" not in derive and "FromJson" not in text[m.end():m.end() + 400]:
                continue
            renames = dict(re.findall(r"(\w+)\(rename=\"(\w+)\"\)", text[m.end():m.end() + 600]))
            fields = {}
            # Join multi-line field types (`x : Map[\n  K,\n  V,\n]?`).
            joined, depth = [], 0
            for line in body.splitlines():
                if depth > 0:
                    joined[-1] += line.strip()
                else:
                    joined.append(line)
                depth += line.count("[") - line.count("]")
            for line in joined:
                fm = FIELD_RE.match(line)
                if not fm:
                    continue
                field, typ = fm.group(1), fm.group(2).rstrip(",")
                wire = renames.get(field, field)
                fields[wire] = typ
            if fields:
                structs[name] = (path.name, fields)
    return structs


def norm(name):
    name = re.sub(r"(Structure|Extra Fields|Fields|Object)", "", name)
    name = re.sub(r"\bEvent\b|Event$", "", name)
    return re.sub(r"[^a-z]", "", name.lower())


def best_table(struct, fields, tables):
    names = set(fields)
    for key, doc in tables.items():
        if norm(key.split("#", 1)[1]) == norm(struct) and names & set(doc):
            return key, 1.0
    best, best_score = None, 0.0
    for key, doc in tables.items():
        shared = names & set(doc)
        if len(shared) < MIN_SHARED:
            continue
        score = len(shared) / len(names | set(doc))
        if score > best_score:
            best, best_score = key, score
    return best, best_score


def main():
    allow = {}
    if ALLOW.exists():
        for line in ALLOW.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if line:
                entry, kind = line.split()
                allow[(entry, kind)] = False
    tables = docs_tables()
    unexplained = 0
    for struct, (file, fields) in sorted(model_structs().items()):
        key, score = best_table(struct, fields, tables)
        if key is None or score < MIN_SCORE:
            continue
        doc = tables[key]
        for wire, typ in fields.items():
            if wire not in doc:
                continue
            optional, nullable = doc[wire]
            findings = []
            if nullable and "Nullable[" not in typ and "Json" not in typ:
                findings.append("NULLABLE")
            if optional and not typ.endswith("?"):
                findings.append("OPTIONAL")
            for kind in findings:
                entry = f"{struct}.{wire}"
                if (entry, kind) in allow:
                    allow[(entry, kind)] = True
                    continue
                unexplained += 1
                print(f"{kind:8} {entry:48} {typ:28} {file}  <- {key} ({score:.2f})")
    for (entry, kind), used in sorted(allow.items()):
        if not used:
            print(f"STALE    {entry} {kind} (allow entry no longer matches)")
    print(f"{unexplained} unexplained finding(s)")
    return 1 if unexplained else 0


if __name__ == "__main__":
    sys.exit(main())
