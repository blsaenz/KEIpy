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
!
!     Python version: upcoming


'''
import os,sys,shutil,csv,pickle,math,time,datetime
from calendar import isleap
import numpy as np
from numpy import asfortranarray,ascontiguousarray
#from numba import jit
#from netCDF4 import date2num # use these with date2num(dt,'days since %i-01-01'%year) to convert!
import xarray as xr
import pandas as pd

try:
    import cftime
except ImportError:
    cftime = None  # type: ignore

# import local utils and fortran modules
file_dir = os.path.dirname(__file__)
sys.path.append(file_dir)
import kei_util as util
from kei_util import forcing_idx,init_vars_ocn,init_vars_eco
from kei_util import ocn_output_meta, ice_output_meta, sw_output_meta, ecosys_output_meta
from kei_util import forcing_output_meta_block, sw_output_meta_block, ecosys_output_meta_block
from kei_util import output_meta,doy_from_datetime64

try:
    from f90 import kei
except ImportError:
    kei = None


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


nf = len(forcing_idx)

grid_vars = ['dm','hm','zm','f_time'] # midpoint depth of cells, at least needed for xarray


# fantastic thing to have around ...
month_doy = [1,32,60,91,121,152,182,213,244,274,305,335]


class kei_parameters(object):
    #default params
    p = {
      'dt'  :           3600.0,  # [seconds] 1 Hour default time step
      'lice':           1,     # ice model enabled
      'leco':           1,     # ecosystem model enabled
      'lsw':            0,     # seaweed model enabled
    }

    def __init__(self, params={}):
        self.update(params)

    def defaults(self):
        return self.p

    def update(self,params):
        self.p.update(params)
        self.build()

    def build(self):
        '''Perform any supplementary calculations for derived parameters'''
        pass


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
        # Unwrap numpy scalar object (sometimes stores cftime inside np.void)
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


def kei_forcing(nc_file = None, f_dict = {}, start_date=None, freq=None, legacy_nc=False):
    ''' Reads and updates forcing data into XArray dataset, which can be fed to KEI model simulation for easy
    interpolation or whatever

    All variables fed into this class should be 1D numpy arrays, except those that come from reading a netcdf file.

    f_time must be a pandas/xarray time series, I think

    Currently, all forcing vars must have similar timing
    '''

    if nc_file is not None:
        ds_in = xr.open_dataset(nc_file)
        if legacy_nc:
            # we are going to make a new dataset with the correct time-index dimensions
            if start_date is None or freq is None:
                raise ValueError('f_time is not provided, and start_date and/or time_delta are not provided; need one of them')
            else:
                f_time_len = len(ds_in['tz'][...])
                f_time = xr.date_range(
                    start=start_date, periods=f_time_len, freq=freq, use_cftime=True
                )
                zm = ds_in['zm'][0:-1].data
            ds = util.reindex_forcing(ds_in,f_time,zm)
            ds['msl'][...] = ds['msl'][...] * 0.01  # many old forcing netCDF files are in Pa, need mbar
        else:
            ds = ds_in
    elif f_dict is not None:
        ds = xr.Dataset()
        ds['f_time'] = ('f_time'), pd.to_datetime(f_dict['f_time'])
    else:
        raise ValueError('kei_forcing: No data given. An input NC file or f_dict must be supplied.')

    for k,v in f_dict.items():
        print("Adding: ",k)
        if k=='f_time':
            pass
        elif k in grid_vars:
            ds[k] = (k),v
        elif k in list(forcing_idx.keys()):
            ds[k] = ('f_time'),v
        elif k in init_vars_ocn + init_vars_eco:
            ds[k] = ('zm'),v

    # add things that we can that might be missing
    if not 'date' in ds.variables:
        td = pd.to_datetime(ds['f_time'].values[1]) - pd.to_datetime(ds['f_time'].values[0])
        ds['date'] = ('f_time'),np.arange(len(ds['f_time'])) / (td.total_seconds()*86400.)
    # 'zm' is negative layer midpoints, 'dm' layer bounds, without the last one, and 'hm' is thicknesses.
    if not 'dm' in ds.variables:
        dm = [0.0]
        zmp = ds['zm'].values * (-1.0)
        for i in range(len(ds['zm'])-1):
            midpoint_dist = zmp[i+1] - zmp[i]
            dm.append(dm[i]+midpoint_dist)
        ds['dm'] = ('zm'), dm
    if not 'hm' in ds.variables:
        dm = ds['dm'].values
        hm = [dm[i+1]-dm[i] for i in range(len(dm)-1)]
        hm.append(hm[-1]) # this is potentially inexact. We should make dm the full bounds at some point
        ds['hm'] = ('zm'), hm

    return ds


class kei_output(object):

    flx_vars = ['fatm','fao','fai','fio','focn']

    def __init__(self,out_vars,f_time,zm,nflx,nni,nns):

        self.out_vars = out_vars

        self.out_ds = xr.Dataset()
        self.out_ds['f_time'] = ('f_time'),f_time
        self.out_ds['zm'] = ('zm'),zm
        self.out_ds['zm'].attrs['units'] = 'm'
        self.out_ds['zm'].attrs['long_name'] = 'layer midpoint depth'
        self.out_ds['nni'] = ('nni'),np.arange(nni,dtype=np.int32)
        self.out_ds['nns'] = ('nns'),np.arange(nns,dtype=np.int32)
        self.out_ds['nflx'] = ('nflx'),np.arange(nflx,dtype=np.int32)
        # add dimension var meta
        for v in ['zm','nni','nns','nflx']:
            self.out_ds[v].attrs['units'] = output_meta[v]['units']
            self.out_ds[v].attrs['long_name'] = output_meta[v]['long_name']
        for d in ['nni','nns']:
            self.out_ds[d].attrs['positive'] = 'down'
        self.out_ds['zm'].attrs['positive'] = 'up'

        len_f_time = len(f_time)
        len_zm = len(zm)



        # setup lists of the exposed numpy arrays for potential usage in numba-optimized
        # methods

        # self.vars_1D = {}
        # self.vars_int = {}
        # self.vars_2D = {}
        # self.vars_ice = {}
        # self.vars_snow = {}
        # for v in self.out_vars:
        #     if output_var_data[v]['dim'] is None:
        #         self.out_ds[v] = ('f_time'),np.full(len_f_time,np.nan,np.float32)
        #         self.vars_1D[v] = self.out_ds[v].__array__()  # is this the best way?
        #     elif output_vars[v]['dim'] == 'int':
        #         self.out_ds[v] = ('f_time'),np.full(len_f_time,0,np.int32)
        #         self.vars_int[v] = self.out_ds[v].__array__()  # is this the best way?
        #     elif output_vars[v]['dim'] == 'zm':
        #         self.out_ds[v] = ('zm','f_time'),np.full((len_zm,len_f_time),np.nan,np.float32)
        #         self.vars_2D[v] = self.out_ds[v].__array__()  # is this the best way?
        #     elif output_vars[v]['dim'] == 'nni':
        #         self.out_ds[v] = ('nni','f_time'),np.full((nni,len_f_time),np.nan,np.float32)
        #         self.vars_ice[v] = self.out_ds[v].__array__()  # is this the best way?
        #     elif output_vars[v]['dim'] == 'nns':
        #         self.out_ds[v] = ('nns','f_time'),np.full((nns,len_f_time),np.nan,np.float32)
        #         self.vars_snow[v] = self.out_ds[v].__array__()  # is this the best way?

        # classify requestable output variables so we can make the right fortran calls to record them
        self.vars_1D = []
        self.vars_int = []
        self.vars_2D = []
        self.vars_ice = []
        self.vars_snow = []
        for v in self.out_vars:
            if output_meta[v]['dim'] is None:
                self.out_ds[v] = ('f_time'),np.full(len_f_time,np.nan,np.float32)
                self.vars_1D.append(v)
            elif output_meta[v]['dim'] == 'int':
                self.out_ds[v] = ('f_time'),np.full(len_f_time,0,np.int32)
                self.vars_int.append(v)
            else:
                if output_meta[v]['dim'] == 'zm':
                    self.vars_2D.append(v)
                    self.out_ds[v] = ('zm', 'f_time'), np.full((len_zm, len_f_time),np.nan,np.float32)
                elif output_meta[v]['dim'] == 'nni':
                    self.vars_ice.append(v)
                    self.out_ds[v] = ('nni', 'f_time'), np.full((nni, len_f_time),np.nan,np.float32)
                elif output_meta[v]['dim'] == 'nns':
                    self.vars_snow.append(v)
                    self.out_ds[v] = ('nns', 'f_time'), np.full((nns, len_f_time), np.nan, np.float32)
            self.out_ds[v].attrs['units'] = output_meta[v]['units']
            self.out_ds[v].attrs['long_name'] = output_meta[v]['long_name']

    def create_block_outputs(self,Vsave,Tsave,Flxsave,swSave,leco,lsw):
        self.leco=leco # this seems sloppy
        self.lsw =lsw

        print('Storing Fluxes...')
        for i,fv in enumerate(self.flx_vars):
            self.out_ds[fv] = ('nflx','f_time'),Flxsave[:,i,:]
            self.out_ds[fv].attrs['units'] = output_meta[fv]['units']
            self.out_ds[fv].attrs['long_name'] = output_meta[fv]['long_name']
        print('Storing Tracers...')
        self.out_ds['T'] = ('zm', 'f_time'), Tsave[:, 0, :]
        self.out_ds['T']['units'] = 'C'
        self.out_ds['S'] = ('zm', 'f_time'), Tsave[:, 1, :]
        self.out_ds['S']['units'] = 'psu'
        for i,fv in enumerate(['T','S']):
            self.out_ds[fv].attrs['units'] = output_meta[fv]['units']
            self.out_ds[fv].attrs['long_name'] = output_meta[fv]['long_name']

        if leco:
            for fv,fvd in ecosys_output_meta_block.items():
                self.out_ds[fv] = ('zm','f_time'),Tsave[:,fvd['idx']+2,:]
                self.out_ds[fv].attrs['units'] = fvd['units']
                self.out_ds[fv].attrs['long_name'] = fvd['long_name']

        if lsw:
            # create MACMODS outputs
            for fv,fvd in sw_output_meta_block.items():
                self.out_ds[fv] = ('f_time'),swSave[fvd['idx'],:]
                self.out_ds[fv].attrs['units'] = fvd['units']
                self.out_ds[fv].attrs['long_name'] = fvd['long_name']

    def store_step_outvars(self,kei,nt):
        '''Outvars are not stored or extracted in tracers blocks'''
        # Use ``.values[...] =`` so we do not trigger xarray's alignment / index
        # machinery on the ``f_time`` coordinate (cftime); integer label index
        # assignment has crashed some xarray builds during the main simulation loop.
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

    def write(self,out_filepath,Finterp,params):

        # create output directory


        # write KEI parameters, run parameters, any config we can think of


        # add compatibility vars for matlab plotting routines
        hour_f, d_part = _matlab_day_hour_from_f_time(self.out_ds['f_time'])
        self.out_ds['hour'] = ('f_time',), hour_f
        day = d_part + hour_f
        # days must be increasing always, above 365
        day_add = 0
        nt = len(hour_f)
        seq_days = np.zeros(nt)
        seq_days[0] = day[0]
        for i in range(1, nt):
            if (day[i] - day[i - 1]) < 0:
                day_add = int(seq_days[i - 1])
            seq_days[i] = day[i] + day_add
        self.out_ds['day'] = ('f_time',), seq_days

        # --- ``to_netcdf`` support (block 1/3): eager forcing arrays ---
        # Goal after upgrading Python/xarray/dask: you may only need plain assignment
        # here if lazy arrays are no longer an issue; keeping numpy avoids chunked
        # ``out_ds`` that triggers dask paths inside xarray writers.
        for v in forcing_idx.keys():
            da = Finterp[v]
            self.out_ds[v] = (da.dims, np.asarray(da.values))

        # create encodings
        #compress_vars = list(self.vars_1D.keys()) + list(self.vars_2D.keys()) + list(forcing_idx.keys()) + \
        #                list(self.vars_ice.keys()) + list(self.vars_snow.keys()) + list(self.vars_flx.keys())
        compress_vars = self.out_vars + list(forcing_idx.keys()) + ['T','S'] + self.flx_vars
        if self.leco:
            compress_vars += list(ecosys_output_meta_block.keys())
        encoding = {}
        for v in compress_vars:
            encoding[v] = {"dtype":np.float32,"zlib": True, "complevel": 4}

        # --- ``to_netcdf`` support (block 2/3): materialize before writing ---
        # Delete this block if a future xarray short-circuits writers without
        # importing ``distributed`` when nothing is chunked.
        self.out_ds = self.out_ds.compute()
        if any(getattr(v, "chunks", None) for v in self.out_ds.variables.values()):
            for name, var in self.out_ds.variables.items():
                if var.chunks is not None:
                    self.out_ds[name] = (var.dims, np.asarray(var.values))

        # --- ``to_netcdf`` support (block 3/3): monkeypatch xarray backends ---
        #
        # TARGET AFTER UPGRADES (replace blocks 1–3 + this patch with only this):
        #
        #     self.out_ds.to_netcdf(
        #         out_filepath,
        #         mode="w",
        #         engine="netcdf4",
        #         format="netcdf4",
        #         encoding=encoding,
        #     )
        #
        # WHY THIS EXISTS (circa py311 / xarray netCDF4 writer):
        # - ``_get_netcdf_autoclose`` can call ``get_dask_scheduler()`` even when
        #   the dataset is fully numpy.
        # - ``NetCDF4DataStore.open`` calls ``get_write_lock(path)``, which calls
        #   ``get_dask_scheduler()`` and may ``import dask.distributed`` (tornado),
        #   which aborted on some stacks.
        # The helpers below mirror upstream logic but skip dask imports when there
        # are no chunks, and force threaded per-file locks (appropriate once data
        # are materialized). Remove when you confirm ``to_netcdf`` no longer pulls
        # ``distributed`` or crashes during import.
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


class kei_simulation(object):

    # Compile time parameters defaults - these will be updated in fortran code for JIT compilation,
    # if requested
    f90_params = {
            'NZ':       400,  # number of vertical water layers
    }
    recompile = False

    # lon, lat are optional now, with defaults, but should be included in forcing data
    # so that we can have moving simulations
    def __init__(self,forcing_ds,t_start=None,t_end=None,
                 lon=None,lat=None,
                 f90_params=None,recompile=False):

        self.update_f90(f90_params,recompile)
        self.update_forcing(forcing_ds,t_start,t_end)
        self.fixed_lon = lon
        self.fixed_lat = lat


    def update_f90(self,f90_params=None,recompile=True):
        if f90_params is not None:
          self.f90_params.update(f90_params)
        self.recompile = recompile


    def update_forcing(self,forcing_ds,t_start=None,t_end=None):
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


    def compute(self,params,output_path,out_vars=None,run_name='keipy'):

        # recompile fortran module if requested, then re-import kei
        # .....  to do
        _require_fortran_kei()

        # get instance of kei, perform parameter init, and query dimensions
        kei.link.kei_param_init()
        if self.fixed_lon is not None:
            kei.link.set_param_real('dlon',self.fixed_lon)
        if self.fixed_lat is not None:
            kei.link.set_param_real('dlat',self.fixed_lat)

        nvel = kei.kei_parameters.nvel  # total number of water velocities (2)
        nsclr = kei.kei_parameters.nsclr  # total number of tracers/scalers
        nsflxs = kei.kei_parameters.nsflxs  # total number of tracers/scalers
        nni = kei.kei_icecommon.nni  # total number of ice layers
        nns = kei.kei_icecommon.nns  # total number of snow layers
        nz = kei.kei_parameters.nz
        n_sw_output = kei.kei_parameters.n_sw_outputs # number of MACMODS outputs

        # prepare & interpolate forcing
        dt_str = '%is' % params.p['dt']
        Finterp = self.F0[list(forcing_idx.keys())+['f_time']]
        Finterp = Finterp.sel(f_time=slice(self.t_start, self.t_end))
        Finterp = Finterp.resample({'f_time':dt_str}).interpolate()
        nt = Finterp.sizes['f_time']

        # copy interpolated forcing into an array for fast import into kei
        Fcomp = np.zeros((nf,nt),order='F',dtype=np.float32)
        for k,idx in forcing_idx.items():
          Fcomp[idx,:] = Finterp[k][...]

        # write out link_test data
        #np.savetxt(r'/Users/blsaenz/Projects/git/keipy/test_data/kf_200_100_2000_savetxt.txt',Fcomp[:,0:1000])

        # update changeable parameters
        for k,v in params.p.items():
          if isinstance(v,int):
            kei.link.set_param_int(k,v)
          elif isinstance(v,float):
            kei.link.set_param_real(k,v)
          else:
            raise ValueError('Unknown kei parameters type:',k,type(v))
        kei.link.set_param_int('nend', nt)

        # init local storage
        Velocity = np.zeros((nz,nvel),order='F')
        Tracers = np.zeros((nz,nsclr),order='F')
        Fluxes = np.zeros((nsflxs,5),order='F')
        Vsave = np.full((nz,nvel,nt),np.nan,np.float32)
        Tsave = np.full((nz,nsclr,nt),np.nan,np.float32)
        Flxsave = np.full((nsflxs,5,nt),np.nan,np.float32)
        swSave = np.full((n_sw_output,nt),np.nan,np.float64)

        # init/copy fortran storage
        kei.link.set_grid(self.F0['dm'].values,
                          self.F0['hm'].values,
                          self.F0['zm'].values)
        Velocity[:,0] = self.F0['u'][0:nz]
        Velocity[:,1] = self.F0['v'][0:nz]
        Tracers[:,0] = self.F0['t'][0:nz]
        Tracers[:,1] = self.F0['s'][0:nz]
        for t,v in ecosys_output_meta_block.items():
          Tracers[:,v['idx']+2] = self.F0[t][0:nz]
        # macroalgae tracers will go here as well, likely in separate array
        kei.link.set_tracers(Velocity,Tracers)

        # save init data for fortran_test
        # np.savetxt(r'/Users/blsaenz/Projects/git/keipy/test_data/dm_savetxt.txt',self.F0['dm'][...])
        # np.savetxt(r'/Users/blsaenz/Projects/git/keipy/test_data/hm_savetxt.txt',self.F0['hm'][...])
        # np.savetxt(r'/Users/blsaenz/Projects/git/keipy/test_data/zm_savetxt.txt',self.F0['zm'][...])
        #np.savetxt(r'/Users/blsaenz/Projects/git/keipy/test_data/X_savetxt.txt',np.transpose(Tracers))
        #np.savetxt(r'/Users/blsaenz/Projects/git/keipy/test_data/U_savetxt.txt',np.transpose(Velocity))

        # initialize
        kei.link.kei_compute_init()

        # init output
        now_str = datetime.datetime.now().strftime('%Y-%m-%d_%H%M%S')
        self.output_path = os.path.join(output_path,run_name + '_' + now_str)
        if not os.path.exists(self.output_path):
            os.mkdir(self.output_path)
        else:
            raise ValueError('KEI output path exists!',self.output_path)
        out_var_meta = {**ocn_output_meta, **ice_output_meta}
        if params.p['leco']:
            out_var_meta = {**out_var_meta, **ecosys_output_meta}
            if params.p['lsw']:
                out_var_meta = {**out_var_meta, **sw_output_meta}
        self.out_vars = list(out_var_meta.keys()) if out_vars is None else out_vars

        # create output object
        output = kei_output(self.out_vars,Finterp['f_time'].data,self.F0['zm'].data,nsflxs,
                            nni=nni,nns=nns)

        # copy code
        shutil.copytree(os.path.dirname(__file__),os.path.join(self.output_path,'code'))

        # write option to txt and pickle
        params_csv = os.path.join(self.output_path,run_name+'_keipy_params.csv')
        with open(params_csv,"w",newline='', encoding='utf-8') as csvfile:
            w = csv.writer(csvfile)
            for key, val in params.p.items():
                w.writerow([key, val])

        # main loop

        for nt,time in enumerate(Finterp['f_time']):

            # load atm data to fortran
            kei.link.set_forcing(Fcomp[:,nt])

            # calc step
            doy=doy_from_datetime64(time)
            kei.link.kei_compute_step(nt,doy)

            # store step data in big arrays
            #Fluxes = kei.link.get_fluxes()
            Flxsave[...,nt] = kei.link.get_fluxes()
            #Velocity,Tracers = kei.link.get_tracers()
            Vsave[...,nt],Tsave[...,nt] = kei.link.get_tracers()
            if params.p['lsw']:
                # swSave[...,nt] = kei.link.get_sw_data()
                swSave[:, nt] = np.asarray(
                    kei.link.get_sw_data(), dtype=np.float64, order="C"
                ).reshape(n_sw_output)
            output.store_step_outvars(kei,nt) # get individual-request outputs

        # write output netCDF file
        output.create_block_outputs(Vsave,Tsave,Flxsave,swSave,params.p['leco'],params.p['lsw'])
        outfile = os.path.join(self.output_path,run_name+'.nc')
        print('Saving KEI output:',outfile)
        output.write(outfile,Finterp,params)


if __name__ == '__main__':


    # params = kei_parameters()
    # kf_ds = kei_forcing(r'/Users/blsaenz/KEI_run/DATA1/kf_200_100_2000.nc',start_date='2000-01-01', freq='H',legacy_nc=True)
    # k = kei_simulation(kf_ds,t_start='2000-01-15',t_end='2000-08-15',lon=-71.53101,lat=-67.11383)
    # k.compute(params,r'/Users/blsaenz/temp/keipy_output',run_name='keipytest5')

    # test with MACMODS
    params = kei_parameters()
    params.p['lsw'] = 1
    kf_ds = kei_forcing(r'/Users/blsaenz/KEI_run/DATA1/kf_200_100_2000.nc',start_date='2000-01-01', freq='h',legacy_nc=True)
    f_time_dim = kf_ds.sizes['f_time']
    kf_ds['swh'] = ('f_time'), np.full(f_time_dim,0.5) # add swell height [m]
    kf_ds['mwp'] = ('f_time'), np.full(f_time_dim,30.) # add mean wave period [s]
    kf_ds['cmag'] = ('f_time'), np.full(f_time_dim,0.05) # add current speed  [m/s]
    k = kei_simulation(kf_ds,t_start='2000-01-15',t_end='2000-08-15',lon=-71.53101,lat=-67.11383)
    k.compute(params,r'/Users/blsaenz/temp/keipy_output',run_name='keipytest_macmods')






