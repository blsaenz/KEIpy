"""Smoke tests for the f2py extension (`f90.kei`).

Build with the same interpreter you test under, e.g. ``make -C f90 kei PYTHON=python3.13``.
NumPy 2.x wraps Fortran via Meson-backed ``numpy.f2py`` (stdlib ``distutils`` is gone on 3.12+).
"""

from __future__ import annotations

import pytest


@pytest.mark.fortran
def test_import_fortran_module(fortran_kei):
    # Loaded as package submodule: "__name__" is "f90.kei"; top-level builds use "kei".
    assert fortran_kei.__name__ in ("kei", "f90.kei")


@pytest.mark.fortran
def test_exposed_parameter_block(fortran_kei):
    params = fortran_kei.kei_parameters
    # Match `f90/kei_parameters.f90` compile-time values
    assert int(params.nz) == 400
    assert int(params.nvel) == 2
    assert int(params.nsclr) == 2 + 24


@pytest.mark.fortran
def test_link_submodule_callable(fortran_kei):
    link = fortran_kei.link
    assert hasattr(link, "kei_param_init")
    assert hasattr(link, "set_param_int")
    # Should not raise; safe to call before a full simulation setup.
    link.kei_param_init()
