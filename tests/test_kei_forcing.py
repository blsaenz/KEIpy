"""Tests for `kei_forcing` dataset assembly (pure Python + xarray)."""

from __future__ import annotations

import numpy as np

import kei as keipy

from .helpers_forcing import minimal_forcing_dict


def test_kei_forcing_builds_dataset_from_dict():
    f_dict = minimal_forcing_dict(nz=48, nt=5)
    ds = keipy.kei_forcing(f_dict=f_dict)

    assert "f_time" in ds.variables
    assert "zm" in ds.variables
    assert "dm" in ds.variables
    assert "hm" in ds.variables
    assert ds.sizes["zm"] == 48
    assert ds.sizes["f_time"] == 5

    for name in keipy.forcing_idx:
        assert name in ds.variables
        assert ds[name].dims == ("f_time",)

    for v in keipy.init_vars_ocn + keipy.init_vars_eco:
        assert v in ds.variables
        assert ds[v].dims == ("zm",)


def test_kei_parameters_class_updates():
    p = keipy.kei_parameters()
    assert p.p["dt"] == 3600.0
    p.update({"dt": 1800.0, "lsw": 1})
    assert p.p["dt"] == 1800.0
    assert p.p["lsw"] == 1
