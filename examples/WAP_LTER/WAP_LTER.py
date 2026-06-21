"""
WAP-LTER example: run KEIPy with seaweed module enabled.

Demonstrates the canonical West Antarctic Peninsula (WAP) LTER forcing setup
from Czajka et al.  Forcing data is read from the repo's ``test_data/`` directory;
tuned parameters are in ``WAP.yml`` (this folder).

Usage (from any directory)::

    python examples/WAP_LTER/WAP_LTER.py

The Fortran extension must be compiled first::

    make -C f90 kei
"""

from pathlib import Path
import numpy as np
import keipy

# ── Paths (resolved relative to this file, works from any CWD) ───────────────
_HERE      = Path(__file__).parent
_REPO_ROOT = _HERE.parent.parent

FORCING_NC   = _REPO_ROOT / 'test_data' / 'kf_200_100_2000.nc'
RUNTIME_YAML = _HERE / 'WAP.yml'
OUTPUT_DIR   = _HERE / 'output'
RUN_NAME     = 'WAP_LTER'

# ── Build forcing dataset ─────────────────────────────────────────────────────
ds = keipy.load_forcing(
    str(FORCING_NC),
    start_date='2000-01-01',
    freq='h',
    legacy_nc=True,
)

# Add fields not present in the legacy NetCDF; replace with real data where available.
nt = ds.sizes['f_time']
nz = ds.sizes['zm']

# Seaweed-module forcing (constant placeholder values)
ds['swh']  = ('f_time'), np.full(nt, 0.5)   # swell height [m]
ds['mwp']  = ('f_time'), np.full(nt, 30.)   # mean wave period [s]
ds['cmag'] = ('f_time'), np.full(nt, 0.05)  # current magnitude [m/s]

# Iron inputs (Plan C): zero = no iron from glacial runoff or ice melt
ds['runoff'] = ('f_time'), np.zeros(nt)      # glacial iron runoff flux [mmol Fe m-2 s-1]
ds['icefe']  = ('f_time'), np.zeros(nt)      # sea-ice iron flux [mmol Fe m-2 s-1]

# POC initial condition (Plan B): zero for spinup [mmol C m-3]
ds['POC'] = ('zm'), np.zeros(nz)

# ── Create and run simulation ─────────────────────────────────────────────────
sim = keipy.Simulation(
    ds,
    runtime_yaml=str(RUNTIME_YAML),
    t_start='2000-01-15',
    t_end='2000-02-15',
)

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
sim.compute(
    str(OUTPUT_DIR),
    run_name=RUN_NAME,
)
