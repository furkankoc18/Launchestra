#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parent.parent
IGNORED = {".git", ".build", "DerivedData"}
LINK = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")


def markdown_files() -> list[Path]:
    return sorted(
        path
        for path in ROOT.rglob("*.md")
        if not any(part in IGNORED for part in path.relative_to(ROOT).parts)
    )


def local_target(raw: str) -> str | None:
    target = raw.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    target = target.split("#", 1)[0]
    if not target or "://" in target or target.startswith("mailto:"):
        return None
    return unquote(target)


errors: list[str] = []
for document in markdown_files():
    text = document.read_text(encoding="utf-8")
    for match in LINK.finditer(text):
        raw = match.group(1)
        target = local_target(raw)
        if target is None:
            continue
        resolved = (document.parent / target).resolve()
        if not resolved.exists():
            line = text.count("\n", 0, match.start()) + 1
            errors.append(f"{document.relative_to(ROOT)}:{line}: missing {raw}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)

print(f"Checked {len(markdown_files())} Markdown files; local links resolve.")
