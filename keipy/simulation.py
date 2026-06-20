'''
!     ==================================================================
!     KPP-Ecosystem-Ice (KEI, pronounced 'key') Model
!     ==================================================================
!
!     Version History (please add a version modification line below
!     if code is edited)
!     ------------------------------------------------------------------
!     Version: 0.9 (2022-01-05, Benjamin Saenz, blsaenz@gmail.com)
!
!     This model derives from Large et al. [1994], Doney et al. [1996](KPP mixing),
!     Ukita and Martinson [2001](Mixed layer - ice interactions), Saenz and Arrigo
!     [2012 and 2014] (SIESTA sea ice model), Hunke and Lipscomb [2008] (CICE v4),
!     Moore et al. [2002,2004] (CESM ecosystem model).


'''
import os, sys, shutil, csv, copy, pickle, math, time, datetime
from calendar import isleap
import numpy as np
from numpy import asfortranarray, ascontiguousarray
import xarray as xr
import pandas as pd

try:
    import cftime
except ImportError:
    cftime = None  # type: ignore

from . import util
from .util import forcing_idx, init_vars_ocn, init_vars_eco
from .util import ocn_output_meta, ice_output_meta, sw_output_meta, ecosys_output_meta
from .util import forcing_output_meta_block, sw_output_meta_block, ecosys_output_meta_block
from .util import output_meta, doy_from_datetime64

try:
    from f90 import kei
except ImportError:
    kei = None


def kei_available() -> bool:
    """Return True if the compiled Fortran extension (``f90.kei``) is importable."""
    return kei is not None


def _require_fortran_kei():
    if kei is None:
        raise RuntimeError(
            'The compiled Fortran extension `f90.kei` is not available. '
            'Build it with `make -C f90 kei` using this Python environment.'
        )


def _scalar_int32_from_fortran(raw):
    """Fortran ``integer(i4)`` scalars from f2py can surface as float NaN; avoid ``np.int32(nan)``."""
    a = np.asarray(raw).reshape(())
    if np.issubdtype(a.dtype, np.floating):
        v = float(a)
        if not math.isfinite(v):
            return np.int32(-99999)
        return np.int32(int(v))
    return np.int32(int(a.item()))


# --- Runtime YAML (`kei_runtime_params.yml`): top-level keys -> ``kei.<f90 submodule>`` ---

DEFAULT_RUNTIME_YAML_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'kei_runtime_params.yml',
)


def _yaml_runtime_scalar(val):
    if isinstance(val, np.generic):
        return val.item()
    return val


def _load_runtime_yaml(path):
    try:
        import yaml
    except ImportError as e:
        raise RuntimeError(
            'Reading runtime YAML requires PyYAML. '
            'Install with conda `pyyaml` or pip `pyyaml>=6`.'
        ) from e
    with open(path, encoding='utf-8') as f:
        doc = yaml.safe_load(f)
    if doc is None:
        return {}
    if not isinstance(doc, dict):
        raise ValueError('Runtime YAML root must be a mapping (dict), got %r' % type(doc))
    return doc


def _deep_merge_runtime_yaml(base, overrides):
    """Deep-merge runtime YAML mappings (top-level sections are dicts)."""
    out = copy.deepcopy(base)
    for k, v in overrides.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = _deep_merge_runtime_yaml(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def _coerce_kei_common_value(name, val):
    """YAML numbers for Fortran logicals ``lice`` / ``leco`` / ``lsw`` → Python bool."""
    val = _yaml_runtime_scalar(val)
    if name in ('lice', 'leco', 'lsw'):
        return bool(int(val))
    return val


def _apply_runtime_yaml_doc(kei_mod, doc, warn=None):
    """Apply nested runtime YAML: each top-level key selects ``kei.<module>``"""
    if warn is None:
        warn = print
    for section_key, mapping in doc.items():
        if not isinstance(section_key, str) or section_key.startswith('#'):
            continue
        if not isinstance(mapping, dict):
            warn('Runtime YAML: skip non-dict section %r' % (section_key,))
            continue
        mod_name = section_key
        try:
            mod = getattr(kei_mod, mod_name)
        except AttributeError:
            warn('Runtime YAML: unknown section %r (no kei.%s)' % (section_key, mod_name))
            continue
        for name, raw_val in mapping.items():
            if not isinstance(name, str) or name.startswith('#'):
                continue
            if mod_name == 'kei_common':
                val = _coerce_kei_common_value(name, raw_val)
                try:
                    for cand in (name, name.lower(), name.upper()):
                        if hasattr(mod, cand):
                            setattr(mod, cand, val)
                            break
                    else:
                        raise AttributeError(name)
                except AttributeError:
                    warn('Runtime YAML: kei_common has no attribute %r (skipped)' % (name,))
            else:
                val = _yaml_runtime_scalar(raw_val)
                try:
                    setattr(mod, name, val)
                except AttributeError:
                    warn('Runtime YAML: %s has no attribute %r (skipped)' % (mod_name, name))


def _resample_dt_seconds(kei_mod):
    """Python forcing resample interval from Fortran ``kei_common.dtsec``."""
    return float(kei_mod.link.get_data_real('dtsec'))


def _kei_common_flag_int(kei_mod, name):
    """0/1 for output/API from a Fortran logical on ``kei_common`` (try lower case first)."""
    for attr in (name.lower(), name.upper()):
        if hasattr(kei_mod.kei_common, attr):
            v = getattr(kei_mod.kei_common, attr)
            if isinstance(v, np.ndarray):
                v = v.reshape(()).item()
            return int(bool(v))
    raise AttributeError('kei_common has no logical %r' % (name,))


nf = len(forcing_idx)

grid_vars = ['dm', 'hm', 'zm', 'f_time']  # midpoint depth of cells, at least needed for xarray

month_doy = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]


def _matlab_day_hour_from_f_time(f_time_da):
    """Calendar day + fraction-of-day for each time, without xarray ``.dt`` math.

    ``f_time`` may use ``cftime`` (``xr.date_range(..., use_cftime=True)``); adding multiple
    ``.dt.*`` expressions can trigger heavy xarray alignment. Reading scalar
    fields from each instant avoids that.
    """
    tvals = np.asarray(f_time_da.values)
    hour = np.empty(tvals.shape, dtype=np.float64)
    day = np.empty(tvals.shape, dtype=np.float64)
    for idx, t in np.ndenumerate(tvals):
        if isinstance(t, np.generic) and hasattr(t, "item"):
            try:
                t = t.item()
            except (ValueError, TypeError):
                pass
        if isinstance(t, np.datetime64):
            ts = pd.Timestamp(t)
            h = (
                ts.hour
                + ts.minute / 60.0
                + ts.second / 3600.0
                + ts.microsecond / 3.6e9
            ) / 24.0
            dm = float(ts.day)
        elif cftime is not None and isinstance(t, cftime.datetime):
            h = (
                t.hour
                + t.minute / 60.0
                + t.second / 3600.0
                + getattr(t, "microsecond", 0) / 3.6e9
            ) / 24.0
            dm = float(t.day)
        elif hasattr(t, "hour") and hasattr(t, "day"):
            h = (
                int(t.hour)
                + int(t.minute) / 60.0
                + int(t.second) / 3600.0
                + int(getattr(t, "microsecond", 0)) / 3.6e9
            ) / 24.0
            dm = float(t.day)
        else:
            ts = pd.Timestamp(t)
            h = (
                ts.hour
                + ts.minute / 60.0
                + ts.second / 3600.0
                + ts.microsecond / 3.6e9
            ) / 24.0
            dm = float(ts.day)
        hour[idx] = h
        day[idx] = dm
    return hour, day


def load_forcing(nc_file=None, f_dict={}, start_date=None, freq=None, legacy_nc=False):
    '''Reads and assembles forcing data into an XArray dataset for use with Simulation.

    All variables fed into this function should be 1D numpy arrays, except those
    that come from reading a netcdf file.

    f_time must be a pandas/xarray time series.
    Currently, all forcing vars must have similar timing.
    '''

    if nc_file is not None:
        ds_in = xr.open_dataset(nc_file)
        if legacy_nc:
            if start_date is None or freq is None:
                raise ValueError('f_time is not provided, and start_date and/or time_delta are not provided; need one of them')
            else:
                f_time_len = len(ds_in['tz'][...])
                f_time = xr.date_range(
                    start=start_date, periods=f_time_len, freq=freq, use_cftime=True
                )
                zm = ds_in['zm'][0:-1].data
            ds = util.reindex_forcing(ds_in, f_time, zm)
            ds['msl'][...] = ds['msl'][...] * 0.01  # many old forcing netCDF files are in Pa, need mbar
        else:
            ds = ds_in
    elif f_dict is not None:
        ds = xr.Dataset()
        ds['f_time'] = ('f_time'), pd.to_datetime(f_dict['f_time'])
    else:
        raise ValueError('load_forcing: No data given. An input NC file or f_dict must be supplied.')

    for k, v in f_dict.items():
        print("Adding: ", k)
        if k == 'f_time':
            pass
        elif k in grid_vars:
            ds[k] = (k), v
        elif k in list(forcing_idx.keys()):
            ds[k] = ('f_time'), v
        elif k in init_vars_ocn + init_vars_eco:
            ds[k] = ('zm'), v

    if not 'date' in ds.variables:
        td = pd.to_datetime(ds['f_time'].values[1]) - pd.to_datetime(ds['f_time'].values[0])
        ds['date'] = ('f_time'), np.arange(len(ds['f_time'])) / (td.total_seconds() * 86400.)
    if not 'dm' in ds.variables:
        dm = [0.0]
        zmp = ds['zm'].values * (-1.0)
        for i in range(len(ds['zm']) - 1):
            midpoint_dist = zmp[i + 1] - zmp[i]
            dm.append(dm[i] + midpoint_dist)
        ds['dm'] = ('zm'), dm
    if not 'hm' in ds.variables:
        dm = ds['dm'].values
        hm = [dm[i + 1] - dm[i] for i in range(len(dm) - 1)]
        hm.append(hm[-1])
        ds['hm'] = ('zm'), hm

    return ds


class Output(object):

    flx_vars = ['fatm', 'fao', 'fai', 'fio', 'focn']

    def __init__(self, out_vars, f_time, zm, nflx, nni, nns):

        self.out_vars = out_vars

        self.out_ds = xr.Dataset()
        self.out_ds['f_time'] = ('f_time'), f_time
        self.out_ds['zm'] = ('zm'), zm
        self.out_ds['zm'].attrs['units'] = 'm'
        self.out_ds['zm'].attrs['long_name'] = 'layer midpoint depth'
        self.out_ds['nni'] = ('nni'), np.arange(nni, dtype=np.int32)
        self.out_ds['nns'] = ('nns'), np.arange(nns, dtype=np.int32)
        self.out_ds['nflx'] = ('nflx'), np.arange(nflx, dtype=np.int32)
        for v in ['zm', 'nni', 'nns', 'nflx']:
            self.out_ds[v].attrs['units'] = output_meta[v]['units']
            self.out_ds[v].attrs['long_name'] = output_meta[v]['long_name']
        for d in ['nni', 'nns']:
            self.out_ds[d].attrs['positive'] = 'down'
        self.out_ds['zm'].attrs['positive'] = 'up'

        len_f_time = len(f_time)
        len_zm = len(zm)

        self.vars_1D = []
        self.vars_int = []
        self.vars_2D = []
        self.vars_ice = []
        self.vars_snow = []
        for v in self.out_vars:
            if output_meta[v]['dim'] is None:
                self.out_ds[v] = ('f_time'), np.full(len_f_time, np.nan, np.float32)
                self.vars_1D.append(v)
            elif output_meta[v]['dim'] == 'int':
                self.out_ds[v] = ('f_time'), np.full(len_f_time, 0, np.int32)
                self.vars_int.append(v)
            else:
                if output_meta[v]['dim'] == 'zm':
                    self.vars_2D.append(v)
                    self.out_ds[v] = ('zm', 'f_time'), np.full((len_zm, len_f_time), np.nan, np.float32)
                elif output_meta[v]['dim'] == 'nni':
                    self.vars_ice.append(v)
                    self.out_ds[v] = ('nni', 'f_time'), np.full((nni, len_f_time), np.nan, np.float32)
                elif output_meta[v]['dim'] == 'nns':
                    self.vars_snow.append(v)
                    self.out_ds[v] = ('nns', 'f_time'), np.full((nns, len_f_time), np.nan, np.float32)
            self.out_ds[v].attrs['units'] = output_meta[v]['units']
            self.out_ds[v].attrs['long_name'] = output_meta[v]['long_name']

    def create_block_outputs(self, Vsave, Tsave, Flxsave, swSave, leco, lsw):
        self.leco = leco
        self.lsw = lsw

        print('Storing Fluxes...')
        for i, fv in enumerate(self.flx_vars):
            self.out_ds[fv] = ('nflx', 'f_time'), Flxsave[:, i, :]
            self.out_ds[fv].attrs['units'] = output_meta[fv]['units']
            self.out_ds[fv].attrs['long_name'] = output_meta[fv]['long_name']
        print('Storing Tracers...')
        self.out_ds['T'] = ('zm', 'f_time'), Tsave[:, 0, :]
        self.out_ds['T']['units'] = 'C'
        self.out_ds['S'] = ('zm', 'f_time'), Tsave[:, 1, :]
        self.out_ds['S']['units'] = 'psu'
        for i, fv in enumerate(['T', 'S']):
            self.out_ds[fv].attrs['units'] = output_meta[fv]['units']
            self.out_ds[fv].attrs['long_name'] = output_meta[fv]['long_name']

        if leco:
            for fv, fvd in ecosys_output_meta_block.items():
                self.out_ds[fv] = ('zm', 'f_time'), Tsave[:, fvd['idx'] + 2, :]
                self.out_ds[fv].attrs['units'] = fvd['units']
                self.out_ds[fv].attrs['long_name'] = fvd['long_name']

        if lsw:
            for fv, fvd in sw_output_meta_block.items():
                self.out_ds[fv] = ('f_time'), swSave[fvd['idx'], :]
                self.out_ds[fv].attrs['units'] = fvd['units']
                self.out_ds[fv].attrs['long_name'] = fvd['long_name']

    def store_step_outvars(self, kei, nt):
        '''Outvars are not stored or extracted in tracers blocks'''
        for v in self.vars_1D:
            val = kei.link.get_data_real(v)
            self.out_ds[v].values[nt] = np.float32(float(val))
        for v in self.vars_2D:
            self.out_ds[v].values[:, nt] = kei.link.get_nz_data(v)
        for v in self.vars_ice:
            self.out_ds[v].values[:, nt] = kei.link.get_ice_data(v)
        for v in self.vars_snow:
            self.out_ds[v].values[:, nt] = kei.link.get_snow_data(v)
        for v in self.vars_int:
            self.out_ds[v].values[nt] = _scalar_int32_from_fortran(
                kei.link.get_data_int(v)
            )

    def write(self, out_filepath, Finterp):

        hour_f, d_part = _matlab_day_hour_from_f_time(self.out_ds['f_time'])
        self.out_ds['hour'] = ('f_time',), hour_f
        day = d_part + hour_f
        day_add = 0
        nt = len(hour_f)
        seq_days = np.zeros(nt)
        seq_days[0] = day[0]
        for i in range(1, nt):
            if (day[i] - day[i - 1]) < 0:
                day_add = int(seq_days[i - 1])
            seq_days[i] = day[i] + day_add
        self.out_ds['day'] = ('f_time',), seq_days

        for v in forcing_idx.keys():
            da = Finterp[v]
            self.out_ds[v] = (da.dims, np.asarray(da.values))

        compress_vars = self.out_vars + list(forcing_idx.keys()) + ['T', 'S'] + self.flx_vars
        if self.leco:
            compress_vars += list(ecosys_output_meta_block.keys())
        encoding = {}
        for v in compress_vars:
            encoding[v] = {"dtype": np.float32, "zlib": True, "complevel": 4}

        self.out_ds = self.out_ds.compute()
        if any(getattr(v, "chunks", None) for v in self.out_ds.variables.values()):
            for name, var in self.out_ds.variables.items():
                if var.chunks is not None:
                    self.out_ds[name] = (var.dims, np.asarray(var.values))

        import xarray.backends.locks as _xr_locks
        import xarray.backends.writers as _xr_writers

        def _autoclose_without_dask_import(dataset, engine):
            have_chunks = any(
                v.chunks is not None for v in dataset.variables.values()
            )
            if not have_chunks:
                return False
            try:
                from xarray.backends.locks import get_dask_scheduler
            except Exception:
                return False
            scheduler = get_dask_scheduler()
            autoclose = have_chunks and scheduler in ("distributed", "multiprocessing")
            if autoclose and engine == "scipy":
                raise NotImplementedError(
                    "Writing netCDF with scipy + dask distributed is not supported."
                )
            return autoclose

        def _write_lock_threaded(filename: str):
            return _xr_locks._get_threaded_lock(filename)

        _saved_ac = _xr_writers._get_netcdf_autoclose
        _saved_gwl = _xr_locks.get_write_lock
        _xr_writers._get_netcdf_autoclose = _autoclose_without_dask_import
        _xr_locks.get_write_lock = _write_lock_threaded
        try:
            self.out_ds.to_netcdf(
                out_filepath,
                mode="w",
                engine="netcdf4",
                format="netcdf4",
                encoding=encoding,
            )
        finally:
            _xr_writers._get_netcdf_autoclose = _saved_ac
            _xr_locks.get_write_lock = _saved_gwl


class Simulation(object):

    f90_params = {
        'NZ': 400,  # number of vertical water layers
    }
    recompile = False

    def __init__(self, forcing_ds, runtime_yaml=None, t_start=None, t_end=None,
                 f90_params=None, recompile=False):

        self.update_f90(f90_params, recompile)
        self.update_forcing(forcing_ds, t_start, t_end)
        self._runtime_yaml_doc = None
        self.runtime_yaml = runtime_yaml if runtime_yaml is not None else DEFAULT_RUNTIME_YAML_PATH
        self.apply_runtime_yaml(self.runtime_yaml, reinit=True)

    def apply_runtime_yaml(self, yaml_path, *, reinit=False):
        '''
        Load ``kei_runtime_params.yml``-style YAML: each top-level key names a block whose
        entries are applied to the matching Fortran extension submodule (``kei_common``,
        ``ice_common`` → ``kei_icecommon``, ``eco_common`` → ``kei_ecocommon``, or any
        ``kei.<name>`` present on the built extension).

        Stored on the simulation and re-applied at the start of ``compute`` (after
        ``kei_param_init``). ``compute`` also loads ``DEFAULT_RUNTIME_YAML_PATH`` if nothing
        was stored.

        Parameters
        ----------
        yaml_path : str
            Path to YAML (see repository ``keipy/kei_runtime_params.yml``).
        reinit : bool
            If True, call ``kei.link.kei_param_init()`` before applying (default False).
        '''
        _require_fortran_kei()
        doc = _load_runtime_yaml(yaml_path)
        self._runtime_yaml_doc = doc
        if reinit:
            kei.link.kei_param_init()
        _apply_runtime_yaml_doc(kei, doc)

    def update_f90(self, f90_params=None, recompile=True):
        if f90_params is not None:
            self.f90_params.update(f90_params)
        self.recompile = recompile

    def update_forcing(self, forcing_ds, t_start=None, t_end=None):
        '''Save and interpolate forcing'''
        self.F0 = forcing_ds

        if t_start is None:
            self.t_start = forcing_ds.f_time[0]
        else:
            self.t_start = t_start
        if t_end is None:
            self.t_end = forcing_ds.f_time[-1]
        else:
            self.t_end = t_end

    @staticmethod
    def validate_forcing(ds):
        '''Check that a forcing dataset contains all variables required by compute().

        Verifies that every forcing time-series key (forcing_idx) and every ocean/
        ecosystem initial-condition variable (init_vars_ocn + init_vars_eco) is
        present in *ds* and contains no NaN values.

        Raises ValueError listing all missing variables and all variables that
        contain NaN, so the caller can fix everything in one pass.

        Parameters
        ----------
        ds : xarray.Dataset
            Dataset returned by load_forcing().
        '''
        missing = []
        has_nan = []

        for key in forcing_idx:
            if key not in ds:
                missing.append(f'{key} (forcing time-series, units: {forcing_output_meta_block[key]["units"]})')
            elif bool(np.any(np.isnan(ds[key].values))):
                has_nan.append(key)

        for key in init_vars_ocn + init_vars_eco:
            if key not in ds:
                missing.append(f'{key} (initial condition)')
            elif bool(np.any(np.isnan(ds[key].values))):
                has_nan.append(key)

        errors = []
        if missing:
            errors.append('Missing variables:\n    ' + '\n    '.join(missing))
        if has_nan:
            errors.append('Variables containing NaN: ' + ', '.join(has_nan))
        if errors:
            raise ValueError('Forcing dataset validation failed:\n  ' + '\n  '.join(errors))

    def compute(self, output_path, out_vars=None, run_name='keipy',
                *, runtime_yaml=None, yaml_overrides=None):

        _require_fortran_kei()

        if self._runtime_yaml_doc is not None:
            doc = copy.deepcopy(self._runtime_yaml_doc)
        else:
            doc = _load_runtime_yaml(runtime_yaml or DEFAULT_RUNTIME_YAML_PATH)
        if yaml_overrides:
            doc = _deep_merge_runtime_yaml(doc, yaml_overrides)

        kei.link.kei_param_init()
        _apply_runtime_yaml_doc(kei, doc)

        nvel = kei.kei_parameters.nvel
        nsclr = kei.kei_parameters.nsclr
        nsflxs = kei.kei_parameters.nsflxs
        nni = kei.kei_icecommon.nni
        nns = kei.kei_icecommon.nns
        nz = kei.kei_parameters.nz
        n_sw_output = kei.kei_parameters.n_sw_outputs

        leco = _kei_common_flag_int(kei, 'leco')
        lsw = _kei_common_flag_int(kei, 'lsw')

        self.validate_forcing(self.F0)

        dt_str = '%is' % int(round(_resample_dt_seconds(kei)))
        Finterp = self.F0[list(forcing_idx.keys()) + ['f_time']]
        Finterp = Finterp.sel(f_time=slice(self.t_start, self.t_end))
        Finterp = Finterp.resample({'f_time': dt_str}).interpolate()
        nt = Finterp.sizes['f_time']

        Fcomp = np.zeros((nf, nt), order='F', dtype=np.float32)
        for k, idx in forcing_idx.items():
            Fcomp[idx, :] = Finterp[k][...]

        kei.link.set_param_int('nend', nt)

        Velocity = np.zeros((nz, nvel), order='F')
        Tracers = np.zeros((nz, nsclr), order='F')
        Fluxes = np.zeros((nsflxs, 5), order='F')
        Vsave = np.full((nz, nvel, nt), np.nan, np.float32)
        Tsave = np.full((nz, nsclr, nt), np.nan, np.float32)
        Flxsave = np.full((nsflxs, 5, nt), np.nan, np.float32)
        swSave = np.full((n_sw_output, nt), np.nan, np.float64)

        kei.link.set_grid(self.F0['dm'].values,
                          self.F0['hm'].values,
                          self.F0['zm'].values)
        Velocity[:, 0] = self.F0['u'][0:nz]
        Velocity[:, 1] = self.F0['v'][0:nz]
        Tracers[:, 0] = self.F0['t'][0:nz]
        Tracers[:, 1] = self.F0['s'][0:nz]
        for t, v in ecosys_output_meta_block.items():
            Tracers[:, v['idx'] + 2] = self.F0[t][0:nz]
        kei.link.set_tracers(Velocity, Tracers)

        kei.link.kei_compute_init()

        now_str = datetime.datetime.now().strftime('%Y-%m-%d_%H%M%S')
        self.output_path = os.path.join(output_path, run_name + '_' + now_str)
        if not os.path.exists(self.output_path):
            os.mkdir(self.output_path)
        else:
            raise ValueError('KEI output path exists!', self.output_path)
        out_var_meta = {**ocn_output_meta, **ice_output_meta}
        if leco:
            out_var_meta = {**out_var_meta, **ecosys_output_meta}
            if lsw:
                out_var_meta = {**out_var_meta, **sw_output_meta}
        self.out_vars = list(out_var_meta.keys()) if out_vars is None else out_vars

        output = Output(self.out_vars, Finterp['f_time'].data, self.F0['zm'].data, nsflxs,
                        nni=nni, nns=nns)

        shutil.copytree(os.path.dirname(__file__), os.path.join(self.output_path, 'code'))

        _, yaml_name = os.path.split(self.runtime_yaml)
        shutil.copy(self.runtime_yaml, os.path.join(self.output_path, yaml_name))

        params_csv_path = os.path.join(self.output_path, run_name + '_keipy_params.csv')
        with open(params_csv_path, 'w', newline='') as _csvf:
            _writer = csv.writer(_csvf)
            _writer.writerow(['section', 'key', 'value'])
            for _section, _params in doc.items():
                if isinstance(_params, dict):
                    for _key, _val in _params.items():
                        _writer.writerow([_section, _key, _val])

        for nt, time in enumerate(Finterp['f_time']):

            kei.link.set_forcing(Fcomp[:, nt])

            doy = doy_from_datetime64(time)
            kei.link.kei_compute_step(nt, doy)

            Flxsave[..., nt] = kei.link.get_fluxes()
            Vsave[..., nt], Tsave[..., nt] = kei.link.get_tracers()
            if lsw:
                swSave[:, nt] = np.asarray(
                    kei.link.get_sw_data(), dtype=np.float64, order="C"
                ).reshape(n_sw_output)
            output.store_step_outvars(kei, nt)

        output.create_block_outputs(Vsave, Tsave, Flxsave, swSave, bool(leco), bool(lsw))
        outfile = os.path.join(self.output_path, run_name + '.nc')
        print('Saving KEI output:', outfile)
        output.write(outfile, Finterp)
