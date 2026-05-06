"""Shared pytest configuration for keipy."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Repo root contains kei.py, kei_util.py, and the `f90` package.
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "fortran: needs compiled `f90/kei` extension (built with Makefile `make kei`).",
    )
    config.addinivalue_line(
        "markers",
        "slow: long integration tests (full KEI run from kei.py __main__ block).",
    )


@pytest.fixture(scope="session")
def fortran_kei():
    """Session-scoped Fortran extension module (`f90.kei`), or skip if missing."""
    try:
        from f90 import kei as _kei
    except ImportError as e:
        pytest.skip(f"Fortran extension not importable (build with `make -C f90 kei`): {e}")

    yield _kei


@pytest.fixture(scope="session")
def kei_py():
    """The top-level Python driver (`kei.py` as imported module `kei`)."""
    try:
        import kei as pykei  # pylint: disable=import-outside-toplevel
        return pykei
    except ImportError:
        pytest.skip("Could not import kei Python module")


@pytest.fixture(scope="session")
def fortran_kei_importable() -> bool:
    try:
        from f90 import kei  # pylint: disable=import-outside-toplevel,unused-import  # noqa: F401

        return True
    except ImportError:
        return False
