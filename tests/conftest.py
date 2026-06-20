"""Shared pytest configuration for keipy."""

from __future__ import annotations

import pytest


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "fortran: needs compiled `f90/kei` extension (built with Makefile `make kei`).",
    )
    config.addinivalue_line(
        "markers",
        "slow: long integration tests (full KEI run via keipy.Simulation).",
    )


@pytest.fixture(scope="session")
def fortran_kei():
    """Session-scoped Fortran extension module (``f90.kei``), or skip if missing."""
    try:
        from f90 import kei as _kei
    except ImportError as e:
        pytest.skip(f"Fortran extension not importable (build with `make -C f90 kei`): {e}")

    yield _kei


@pytest.fixture(scope="session")
def kei_py():
    """The top-level keipy package."""
    try:
        import keipy
        return keipy
    except ImportError:
        pytest.skip("Could not import keipy")


@pytest.fixture(scope="session")
def fortran_kei_importable() -> bool:
    try:
        from f90 import kei  # noqa: F401
        return True
    except ImportError:
        return False
