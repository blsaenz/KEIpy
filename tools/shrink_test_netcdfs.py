#!/usr/bin/env python3
"""Shrink test_data NetCDFs for smaller git checkouts.

1. kf_200_100_2000.nc — crop ``time`` to 2000-01-01 … 2000-03-01 (hourly, inclusive),
   matching ``date`` as fractional days since index 0 (= first hour of sequence).

2. test_output.nc — keep only variables compared in tests/test_kei_main_block.py:
   T, ALK, NO3 plus coordinates zm and f_time.

Re-run after replacing reference outputs if pytest comparisons change.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import xarray as xr

REPO = Path(__file__).resolve().parents[1]
TEST_DATA = REPO / "test_data"
KF_NAME = "kf_200_100_2000.nc"
REF_NAME = "test_output.nc"

# Jan 1 … Mar 1 (2000 leap year): 31 + 29 + 1 = 61 days × 24 h = 1464 hourly records.
N_HOURS_JAN_THROUGH_MAR1 = 1464

KEEP_OUTPUT_VARS = ("T", "ALK", "NO3")


def _zlib(ds: xr.Dataset) -> dict[str, dict]:
    enc: dict[str, dict] = {}
    for v in list(ds.data_vars) + list(ds.coords):
        enc[v] = {"zlib": True, "complevel": 5, "shuffle": True}
    return enc


def _write_dataset_atomic(ds: xr.Dataset, path: Path, *, encoding: dict[str, dict]) -> None:
    """Write to a sibling ``*.tmp`` then replace ``path`` (avoids clobbering an open file)."""
    tmp = path.with_suffix(path.suffix + ".tmp")
    try:
        ds.to_netcdf(tmp, encoding=encoding)
        tmp.replace(path)
    except Exception:
        if tmp.is_file():
            tmp.unlink()
        raise


def shrink_kf(path: Path, *, dry_run: bool) -> None:
    ds = xr.open_dataset(path)
    n = min(N_HOURS_JAN_THROUGH_MAR1, ds.sizes.get("time", 0))
    if n < N_HOURS_JAN_THROUGH_MAR1:
        ds.close()
        raise SystemExit(
            f"{path}: need at least {N_HOURS_JAN_THROUGH_MAR1} time steps, got {ds.sizes.get('time')}"
        )
    cropped = ds.isel(time=slice(0, N_HOURS_JAN_THROUGH_MAR1))
    print(
        f"{path.name}: time {ds.sizes['time']} -> {cropped.sizes['time']}; "
        f"date ends ~ day {float(cropped['date'].values[-1]):.4f}"
    )
    if dry_run:
        ds.close()
        return
    cropped.load()
    ds.close()
    _write_dataset_atomic(cropped, path, encoding=_zlib(cropped))


def shrink_reference(path: Path, *, dry_run: bool) -> None:
    ds = xr.open_dataset(path)
    missing = [v for v in KEEP_OUTPUT_VARS if v not in ds]
    if missing:
        ds.close()
        raise SystemExit(f"{path}: missing variables {missing}")
    slim = ds[list(KEEP_OUTPUT_VARS)]
    print(
        f"{path.name}: data_vars {len(ds.data_vars)} -> {len(slim.data_vars)} "
        f"(keeping {list(KEEP_OUTPUT_VARS)})"
    )
    if dry_run:
        ds.close()
        return
    slim.load()
    ds.close()
    _write_dataset_atomic(slim, path, encoding=_zlib(slim))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="print planned changes only",
    )
    args = ap.parse_args()

    kf = TEST_DATA / KF_NAME
    ref = TEST_DATA / REF_NAME
    if not kf.is_file():
        raise SystemExit(f"missing {kf}")
    if not ref.is_file():
        raise SystemExit(f"missing {ref}")

    shrink_kf(kf, dry_run=args.dry_run)
    shrink_reference(ref, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
