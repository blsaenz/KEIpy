"""Tiny synthetic forcings for tests (no NetCDF)."""

from __future__ import annotations

import numpy as np
import pandas as pd

import keipy.util as util


def minimal_forcing_dict(*, nz: int = 48, nt: int = 4) -> dict:
    """Build ``f_dict`` suitable for ``keipy.load_forcing(..., f_dict=...)``."""

    zm = -np.linspace(1.0, float(nz), nz, dtype=np.float32)
    f_time = pd.date_range("2000-01-01", periods=nt, freq="h")

    f_dict: dict = {
        "f_time": f_time,
        "zm": zm,
    }

    # Surface / column forcings indexed by `f_time`
    for name in util.forcing_idx:
        if name == "date":
            f_dict[name] = np.arange(nt, dtype=np.float32)
        else:
            f_dict[name] = np.zeros(nt, dtype=np.float32)

    # Initial physical fields on `zm`
    f_dict["u"] = np.zeros(nz, dtype=np.float32)
    f_dict["v"] = np.zeros(nz, dtype=np.float32)
    f_dict["t"] = np.full(nz, -1.0, dtype=np.float32)
    f_dict["s"] = np.full(nz, 34.0, dtype=np.float32)

    for name in util.init_vars_eco:
        f_dict[name] = np.zeros(nz, dtype=np.float32)

    return f_dict
