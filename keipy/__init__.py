"""
KEIPy — KPP-Ecosystem-Ice model, Python driver.

Typical usage::

    import keipy

    ds  = keipy.load_forcing('kf_200_100_2000.nc', start_date='2000-01-01', freq='h', legacy_nc=True)
    sim = keipy.Simulation(ds, t_start='2000-01-15', t_end='2000-08-15')
    sim.compute('/path/to/output', run_name='my_run')

The Fortran extension (``f90/kei``) must be compiled first::

    make -C f90 kei
"""

from keipy.simulation import (
    Simulation,
    Output,
    load_forcing,
    kei_available,
    DEFAULT_RUNTIME_YAML_PATH,
    _load_runtime_yaml,
    _deep_merge_runtime_yaml,
    _apply_runtime_yaml_doc,
)
validate_forcing = Simulation.validate_forcing
from keipy.util import (
    forcing_idx,
    init_vars_ocn,
    init_vars_eco,
    ocn_output_meta,
    ice_output_meta,
    sw_output_meta,
    ecosys_output_meta,
    forcing_output_meta_block,
    sw_output_meta_block,
    ecosys_output_meta_block,
    output_meta,
    doy_from_datetime64,
)
from keipy import util

__all__ = [
    # Core API
    "Simulation",
    "Output",
    "load_forcing",
    "validate_forcing",
    "kei_available",
    "DEFAULT_RUNTIME_YAML_PATH",
    # Metadata / utilities
    "util",
    "forcing_idx",
    "init_vars_ocn",
    "init_vars_eco",
    "ocn_output_meta",
    "ice_output_meta",
    "sw_output_meta",
    "ecosys_output_meta",
    "forcing_output_meta_block",
    "sw_output_meta_block",
    "ecosys_output_meta_block",
    "output_meta",
    "doy_from_datetime64",
]
