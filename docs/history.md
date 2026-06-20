===================== Work Notes: 2026-06-19

I am getting an error with apply_runtime_yaml(), where is seems kei_ecocommon is not exposesed. "Runtime YAML: unknown section 'kei_ecocommon' (no kei.kei_ecocommon)" Can you understand this?  I am running the code at the bottom of kei.py, under __main__

Here is what was going wrong and what we changed.

Cause
NumPy f2py only creates Python attributes for Fortran modules whose .f90 sources are passed on the f2py -c command line (F901D in f90/Makefile).

kei_ecocommon was only present as a precompiled kei_ecocommon.o inside OBJ1D. That pulls the module into the link, but f2py never parses kei_ecocommon.f90, so it does not build a kei_ecocommon object on the Python module. You get kei.link, kei.kei_common, etc., but no kei.kei_ecocommon.

So apply_runtime_yaml() is behaving as written; the extension simply never exposed that submodule.

Fix (in f90/Makefile)
kei_ecocommon.f90 added to F901D so f2py compiles it and exposes kei.kei_ecocommon (same idea as kei_common.f90 / kei_parameters.f90).

kei_ecocommon.o removed from the f2py link list via OBJ1D_F2PY so the module is not linked twice (once from make’s .o and once from f2py’s compile of kei_ecocommon.f90).

kei_ecocommon.o is still built as a prerequisite of other objects (kei_eco.o, etc.); it is just not passed into the final f2py link.

What you should do
Rebuild the extension with the env you use for KEI (the one that has NumPy / gfortran), for example:

make -C f90 clean kei PYTHON="$(which python)"
(or your conda env’s python).

Then in Python you should see:

from f90 import kei
assert hasattr(kei, "kei_ecocommon")
After that, apply_runtime_yaml() and the eco_common: block in kei_runtime_params.yml should apply without the “unknown section” warning.

(Local make kei failed here only because the default python3 had no NumPy; your conda env should be fine.)

=====================  Work Notes: 2026-06-18

Inside kei_simulation.compute(), kei.kei_common.dtsec seems to always be 0.0, even after calling kei.link.kei_param_init(). Can you infer why? dtsec is commented out in my yaml parameter file, so it should be using the default.

Tracing Fortran initialization and how f2py exposes dtsec:

Fixing a likely f2py bug: consecutive REAL(r8) module variables declared on one line (time, dtsec) can be mis-exported to Python (wrong pointer or wrong scalar). Splitting the declarations and adding get_data_real('dtsec') so we read the live Fortran value through link.

		! times
		REAL(r8), save :: &
			time,dtsec
      value = time
    elseif (param == 'dtsec') then
      value = REAL(dtsec, r4)
    !elseif (param == 'day') then
def _resample_dt_seconds(kei_mod):
    """Python forcing resample interval from Fortran ``kei_common.dtsec``."""
    return float(_yaml_runtime_scalar(kei_mod.kei_common.dtsec))
    """Python forcing resample interval from Fortran ``dtsec`` (via ``link``, not ``kei_common.dtsec``).
def _resample_dt_seconds(kei_mod):
    """Python forcing resample interval from Fortran ``dtsec`` (via ``link``, not ``kei_common.dtsec``).
    """Timestep [s] for Python resampling: read ``dtsec`` from Fortran via ``link.get_data_real``.
Why kei.kei_common.dtsec looked like 0.0
NumPy f2py often mishandles two real(r8) module variables declared on the same line:


kei_common.f90
Lines 15-16
		REAL(r8), save :: time
		REAL(r8), save :: dtsec
Before the fix, time and dtsec were declared together as REAL(r8), save :: time, dtsec. That pattern can produce a bad Python binding for the second name (so kei.kei_common.dtsec reads as 0.0 even though Fortran init_constants_params sets dtsec = 3600.0). This is not because YAML omitted dtsec; Fortran still had the right value internally.

What we changed
kei_common.f90 — Split time and dtsec into separate declarations so f2py can bind them correctly after you rebuild.

kei_link.f90 — Extended get_data_real with param == 'dtsec' so Python reads dtsec through link (same module memory Fortran uses).

kei.py — _resample_dt_seconds now uses kei.link.get_data_real('dtsec'), with fallbacks to the f2py scalar and finally 3600.0 if needed.

Rebuild the extension so the new get_data_real branch and the split declaration are in your .so:


make -C f90 clean kei PYTHON="$(which python)"
After that, kei.kei_common.dtsec in Python should match Fortran once the extension is rebuilt; for driving logic, prefer get_data_real('dtsec') as in _resample_dt_seconds.