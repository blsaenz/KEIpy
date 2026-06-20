"""Lightweight checks for ``keipy.util`` data structures."""

from __future__ import annotations

import numpy as np
import pandas as pd
import xarray as xr

import keipy.util as u


def test_forcing_index_alignment():
    """Indices must stay consistent with the Fortran packing order."""
    keys = list(u.forcing_idx.keys())
    assert len(keys) == 21
    for i, k in enumerate(keys):
        assert u.forcing_idx[k] == i


def test_reindex_forcing_copies_surface_fields():
    nz, nt = 8, 6
    zm = np.linspace(-1.0, -float(nz), nz)
    f_time = pd.date_range("2020-01-01", periods=nt, freq="D")

    src = xr.Dataset(coords={"f_time": f_time, "zm": zm})
    src["tau_x"] = ("f_time", np.arange(nt, dtype="f4"))
    out = u.reindex_forcing(src, f_time, zm)
    assert "tau_x" in out
    assert tuple(out["tau_x"].shape) == (nt,)
