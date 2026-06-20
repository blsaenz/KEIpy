# Installation

KEIPy has two parts: a Python package (`keipy`) and a Fortran extension (`f90/kei`).
The Python package installs normally via pip, but the Fortran extension requires a
compiler and LAPACK library that must come from **conda-forge** — they cannot be
installed by pip alone.

## Prerequisites

- [Miniforge](https://github.com/conda-forge/miniforge) or Mamba (recommended)
- gfortran (provided by conda-forge `compilers`)
- OpenBLAS / LAPACK (provided by conda-forge `liblapack`)
- Meson + Ninja (required for NumPy f2py on Python ≥ 3.12)

## Step 1 — Create the conda environment

From the repo root:

```bash
mamba env create -f environment.yml
mamba activate py313
```

This installs all compiler toolchain and Python dependencies in one step.
See `environment.yml` for the full package list.

## Step 2 — Build the Fortran extension

The extension must be compiled against the Python interpreter in your active environment:

```bash
make -C f90 kei PYTHON=$(which python)
```

This produces `f90/kei.cpython-<ver>-<platform>.so`.  Rebuild after any change to the
Fortran source files (`.f90`).

To do a clean rebuild (e.g. after switching Python versions):

```bash
make -C f90 clean kei PYTHON=$(which python)
```

## Step 3 — Install the Python package

```bash
pip install -e .
```

Editable mode (`-e`) means changes to `keipy/` take effect immediately without reinstalling.

## Verify

```python
import keipy
print(keipy.kei_available())   # True if extension is built and importable
```

## Troubleshooting

**`kei_available()` returns False** — the extension wasn't found on `sys.path`.
Ensure you ran `make -C f90 kei` inside the activated conda environment and that
`pip install -e .` was run from the repo root.

**`make` errors about missing `meson` or `ninja`** — activate the conda environment
first (`mamba activate py313`), or pass the full path: `make -C f90 kei PYTHON=/path/to/env/bin/python`.

**`Runtime YAML: unknown section 'kei_ecocommon'`** — the extension was compiled
without `kei_ecocommon.f90` on the f2py source list.  Run `make -C f90 clean kei`.

**`kei.kei_common.dtsec` reads as 0.0** — stale build from before the split-declaration
fix.  Run `make -C f90 clean kei`.
