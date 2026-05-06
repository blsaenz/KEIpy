#!/usr/bin/env python3
"""Wrap kei_fluxes.f90 in module kei_fluxes; strip redundant USE from procedures."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "kei_fluxes.f90"

HEADER = """module kei_fluxes
  use kei_kinds, only: i4, r4, r8, log_kind
  use kei_parameters
  use kei_common
  use kei_icecommon
  use kei_hacks, only: ic_conform
  implicit none
  private
  public :: calflx, atmflx, o2iflx, topflx, ntflx, init_flx, swdk

contains

"""

USE_LINE = re.compile(
    r"^[ \t]*use[ \t]+kei_(kinds|parameters|common|icecommon|hacks)\b.*\n",
    re.IGNORECASE | re.MULTILINE,
)

IFACE_SWDK = re.compile(
    r"[ \t]*interface\s*\n"
    r"[ \t]*(?:FUNCTION|function)\s+SWDK\s*\([^)]*\)\s*\n"
    r".*?"
    r"[ \t]*end\s+function\s+SWDK\s*\n"
    r"[ \t]*end\s+interface\s*\n",
    re.DOTALL | re.IGNORECASE,
)


def main() -> None:
    text = SRC.read_text().lstrip()
    upper = text.upper()
    if upper.startswith("SUBROUTINE"):
        text = HEADER + text
        text = text.rstrip() + "\n\nend module kei_fluxes\n"
    elif not upper.startswith("MODULE KEI_FLUXES"):
        raise SystemExit(
            "expected kei_fluxes.f90 to start with SUBROUTINE or module kei_fluxes"
        )

    parts = text.split("contains", 1)
    if len(parts) != 2:
        raise SystemExit("expected module body with contains")
    head, tail = parts
    tail = USE_LINE.sub("", tail)
    text = head + "contains" + tail
    text = IFACE_SWDK.sub("", text)
    SRC.write_text(text)
    print("Updated", SRC)


if __name__ == "__main__":
    main()
