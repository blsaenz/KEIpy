#!/usr/bin/env python3
"""One-shot: qualify REAL/INTEGER/LOGICAL/DOUBLE PRECISION with kei_kinds. Skips kei_kinds.f90."""

import re
from pathlib import Path

F90 = Path(__file__).resolve().parent
SKIP = {"kei_kinds.f90"}


def transform_line(line: str) -> str:
    """Transform a single source line (preserve comment suffix separately)."""
    if line.strip().startswith("!"):
        return line

    # Split trailing comment (naive: first unquoted !)
    comment = ""
    code = line
    in_str = False
    prev_q = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_str:
            in_str = True
            prev_q = True
        elif ch == "'" and in_str:
            in_str = False
        elif ch == "!" and not in_str and i > 0:
            code = line[:i]
            comment = line[i:]
            break

    orig_code = code

    # DOUBLE PRECISION first
    code = re.sub(r"\bDOUBLE\s+PRECISION\b", "REAL(r8)", code, flags=re.IGNORECASE)

    # REAL — not already real(…) or kind=
    def repl_real(m):
        return m.group(0) if m.group(1) else "real(r4)"

    # Match "real" only if not followed by '(' or '(' after optional space is already kind
    code = re.sub(r"\breal\b(?!\s*\()", "real(r4)", code, flags=re.IGNORECASE)

    # INTEGER — not integer( already
    code = re.sub(r"\binteger\b(?!\s*\()", "integer(i4)", code, flags=re.IGNORECASE)

    # LOGICAL
    code = re.sub(r"\blogical\b(?!\s*\()", "logical(kind=log_kind)", code, flags=re.IGNORECASE)

    # Collapse accidental double qualifies if script re-run
    code = re.sub(
        r"real\(r4\)\(r4\)", "real(r4)", code, flags=re.IGNORECASE
    )
    code = re.sub(r"integer\(i4\)\(i4\)", "integer(i4)", code, flags=re.IGNORECASE)
    code = re.sub(
        r"logical\(kind=log_kind\)\(kind=log_kind\)",
        "logical(kind=log_kind)",
        code,
        flags=re.IGNORECASE,
    )

    if code == orig_code:
        return line
    return code + comment


def ensure_use_kei_kinds(text: str, fname: str) -> str:
    if fname == "kei_kinds.f90":
        return text
    needs = bool(
        re.search(
            r"real\(r4\)|real\(r8\)|integer\(i4\)|logical\(kind=log_kind\)", text, re.I
        )
    )
    if not needs or re.search(r"^\s*use\s+kei_kinds\b", text, re.M):
        return text

    # Insert after module stmt first line
    m = re.search(r"^(module\s+\w+)\s*$", text, re.M | re.I)

    def ins(mm):
        return (
            mm.group(1)
            + "\n  use kei_kinds, only: i4, r4, r8, log_kind"
        )

    if m:
        return re.sub(
            r"^(module\s+\w+)\s*$",
            ins,
            text,
            count=1,
            flags=re.M | re.I,
        )
    # program or bare file
    if re.search(r"^(program\s+\w+)\s*$", text, re.M | re.I):
        return re.sub(
            r"^(program\s+\w+)\s*$",
            lambda mm: mm.group(1)
            + "\n  use kei_kinds, only: i4, r4, r8, log_kind",
            text,
            count=1,
            flags=re.M | re.I,
        )
    return text


def main():
    for path in sorted(F90.glob("*.f90")):
        if path.name in SKIP:
            continue
        if path.name.endswith(".f90") is False:
            continue
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        new_lines = [transform_line(ln) for ln in lines]
        text = "".join(new_lines)
        text = ensure_use_kei_kinds(text, path.name)
        path.write_text(text, encoding="utf-8")
        print(path.name)

    for path in sorted(F90.glob("*.F90")):
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        new_lines = [transform_line(ln) for ln in lines]
        text = "".join(new_lines)
        text = ensure_use_kei_kinds(text, path.name)
        path.write_text(text, encoding="utf-8")
        print(path.name)


if __name__ == "__main__":
    main()
