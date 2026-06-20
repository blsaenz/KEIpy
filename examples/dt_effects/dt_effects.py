"""
dt_effects.py — Timestep sensitivity study for KEIPy.

Runs three simulations at dt = 450 s, 3600 s, and 10800 s using the 4-year
WAP-LTER forcing dataset (kf_200_100_2000_v2.nc, 35040 hourly steps) and
produces comparison plots:

  * Z–t colour maps for T, S, NO3, diatChl (depth × time).
  * Time-series line plots for hi (ice thickness) and hs (snow thickness).

The dt=450 s run is the reference (finest timestep).  The 3600 s and 10800 s
results are interpolated in time to the 450 s grid before differencing.

Usage (from repo root)::

    python examples/dt_effects/dt_effects.py

Output::

    examples/dt_effects/output/dt_effects_comparison.png

Note: delete the output/ directory when changing forcing files or time range,
otherwise the cached NC files from prior runs will be reused.
"""

from pathlib import Path
import sys

# Ensure repo root is on sys.path when run directly (without pip install -e .)
_HERE      = Path(__file__).resolve().parent
_REPO_ROOT = _HERE.parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

import numpy as np
import pandas as pd
import xarray as xr
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.gridspec import GridSpec
import keipy

# ── Paths ─────────────────────────────────────────────────────────────────────
FORCING_NC   = _HERE / 'kf_200_100_2000_v2.nc'   # 35040-hour (4-year) dataset
RUNTIME_YAML = _REPO_ROOT / 'examples' / 'WAP_LTER' / 'WAP.yml'
OUTPUT_DIR   = _HERE / 'output'

# ── Study parameters ──────────────────────────────────────────────────────────
DT_LIST = [90, 450, 3600, 10800]    # model timesteps to run [s]
REF_DT  = 3600                      # reference timestep for difference plots
T_START = '2000-01-01'
T_END   = '2001-06-30'              # ~1.5 years

# Depth-time colour maps
TRACERS_2D = ['T', 'S', 'NO3', 'diatChl']
TRACER_2D_META = {
    'T':       ('Temperature',   'RdYlBu_r', '°C'),
    'S':       ('Salinity',      'Blues',     'psu'),
    'NO3':     ('Nitrate',       'YlGn',      'mmol m⁻³'),
    'diatChl': ('Diatom CHL',    'Greens',    'mg Chl m⁻³'),
}

# Time-series line plots (1-D in time)
TRACERS_1D = ['hi', 'hs']
TRACER_1D_META = {
    'hi': ('Ice thickness',  'm'),
    'hs': ('Snow thickness', 'm'),
}


# ── Forcing builder ────────────────────────────────────────────────────────────
def build_forcing():
    ds = keipy.load_forcing(
        str(FORCING_NC),
        start_date=T_START,
        freq='h',          # source data is hourly; model will interpolate to dtsec
        legacy_nc=True,
    )
    nt = ds.sizes['f_time']
    nz = ds.sizes['zm']
    ds['swh']    = ('f_time'), np.full(nt, 0.5)
    ds['mwp']    = ('f_time'), np.full(nt, 30.)
    ds['cmag']   = ('f_time'), np.full(nt, 0.05)
    ds['runoff'] = ('f_time'), np.zeros(nt)
    ds['icefe']  = ('f_time'), np.zeros(nt)
    ds['POC']    = ('zm'), np.zeros(nz)
    return ds


# ── Run one simulation; return path to output NC ──────────────────────────────
def run_or_load(forcing_ds, dtsec, out_root):
    """Run a simulation if no cached output exists; return path to NC."""
    run_name = f'dt_{dtsec:05d}s'
    run_dir  = out_root / run_name
    run_dir.mkdir(parents=True, exist_ok=True)

    existing = sorted(run_dir.glob(f'{run_name}_*'))
    if existing:
        nc_path = existing[-1] / f'{run_name}.nc'
        if nc_path.is_file():
            print(f'  [cached] {nc_path.relative_to(_REPO_ROOT)}')
            return nc_path

    print(f'  Running dt={dtsec} s ...')
    sim = keipy.Simulation(
        forcing_ds,
        runtime_yaml=str(RUNTIME_YAML),
        t_start=T_START,
        t_end=T_END,
    )
    sim.compute(
        str(run_dir),
        run_name=run_name,
        yaml_overrides={'kei_common': {'dtsec': float(dtsec), 'leco': 1}},
    )
    subdirs = sorted(run_dir.glob(f'{run_name}_*'))
    assert subdirs, f'No output subdirectory found in {run_dir}'
    nc_path = subdirs[-1] / f'{run_name}.nc'
    assert nc_path.is_file(), f'Expected output NC at {nc_path}'
    return nc_path


# ── Time-axis helper ──────────────────────────────────────────────────────────
def to_mpl_dates(da_time):
    """Convert an xarray time coordinate to matplotlib date numbers."""
    try:
        return mdates.date2num(pd.DatetimeIndex(da_time.values))
    except Exception:
        return mdates.date2num(
            [pd.Timestamp(str(v)[:19]) for v in da_time.values]
        )


def _fmt_date_axis(ax, n_years):
    """Apply quarterly or yearly date ticks depending on run length."""
    if n_years <= 1:
        ax.xaxis.set_major_locator(mdates.MonthLocator())
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %Y'))
    else:
        ax.xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 4, 7, 10]))
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%b\n%Y'))
    plt.setp(ax.get_xticklabels(), fontsize=7)


# ── Main ──────────────────────────────────────────────────────────────────────
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

print('Building forcing dataset ...')
forcing = build_forcing()

# Run (or load) all three simulations
results = {}
for dt in DT_LIST:
    nc = run_or_load(forcing, dt, OUTPUT_DIR)
    results[dt] = xr.open_dataset(nc)

# ── Interpolate all runs to the reference time grid ───────────────────────────
ref_ds   = results[REF_DT]
ref_time = ref_ds['f_time']
t_mpl    = to_mpl_dates(ref_time)
DIFF_DTS = [dt for dt in DT_LIST if dt != REF_DT]

# estimate run length in years for tick-spacing decision
n_years = float((t_mpl[-1] - t_mpl[0]) / 365.25)

print('Interpolating to reference time grid ...')
interp = {REF_DT: ref_ds}
for dt in DIFF_DTS:
    interp[dt] = results[dt].interp(f_time=ref_time, method='linear')

# ── Plot layout ────────────────────────────────────────────────────────────────
n2d = len(TRACERS_2D)
n1d = len(TRACERS_1D)
n_rows = n2d + n1d
n_cols = 1 + len(DIFF_DTS)

height_ratios = [3.5] * n2d + [1.8] * n1d
fig = plt.figure(figsize=(7 * n_cols, sum(height_ratios) + 1.5), layout='constrained')
gs  = GridSpec(n_rows, n_cols, figure=fig, height_ratios=height_ratios,
               hspace=0.45, wspace=0.3)

axes = [[fig.add_subplot(gs[r, c]) for c in range(n_cols)] for r in range(n_rows)]

fig.suptitle(
    f'KEIPy Timestep Sensitivity  ·  WAP-LTER  ·  {T_START} to {T_END}',
    fontsize=13, fontweight='bold',
)

zm    = ref_ds['zm'].values
y_top, y_bot = 0.0, float(zm.min())

col_titles = [f'dt = {REF_DT} s  (reference)'] + [
    f'dt = {dt} s  −  dt = {REF_DT} s' for dt in DIFF_DTS
]

# ── 2-D (depth × time) rows ───────────────────────────────────────────────────
for row, var in enumerate(TRACERS_2D):
    label, abs_cmap, unit = TRACER_2D_META[var]
    ref_data = interp[REF_DT][var].values   # (nz, nt)

    ax = axes[row][0]
    vlo, vhi = np.nanpercentile(ref_data, [2, 98])
    p = ax.pcolormesh(t_mpl, zm, ref_data, cmap=abs_cmap,
                      vmin=vlo, vmax=vhi, shading='auto')
    fig.colorbar(p, ax=ax, label=unit, pad=0.02)
    ax.set_ylim(y_bot, y_top)
    ax.set_title(f'{label}  |  {col_titles[0]}', fontsize=8)
    ax.set_ylabel('Depth (m)', fontsize=8)
    _fmt_date_axis(ax, n_years)

    for col, cdt in enumerate(DIFF_DTS, start=1):
        ax = axes[row][col]
        diff = interp[cdt][var].values - ref_data
        vmax = float(np.nanpercentile(np.abs(diff), 98)) or 1.0
        p = ax.pcolormesh(t_mpl, zm, diff, cmap='RdBu_r',
                          vmin=-vmax, vmax=vmax, shading='auto')
        fig.colorbar(p, ax=ax, label=f'Δ {unit}', pad=0.02)
        ax.set_ylim(y_bot, y_top)
        ax.set_title(f'{label}  |  {col_titles[col]}', fontsize=8)
        ax.set_ylabel('Depth (m)', fontsize=8)
        _fmt_date_axis(ax, n_years)

# ── 1-D (time-series) rows ────────────────────────────────────────────────────
for i, var in enumerate(TRACERS_1D):
    row   = n2d + i
    label, unit = TRACER_1D_META[var]
    ref_vals = interp[REF_DT][var].values   # (nt,)

    # Col 0: absolute reference
    ax = axes[row][0]
    ax.plot(t_mpl, ref_vals, lw=0.7, color='steelblue')
    ax.set_title(f'{label}  |  {col_titles[0]}', fontsize=8)
    ax.set_ylabel(unit, fontsize=8)
    ax.set_xlim(t_mpl[0], t_mpl[-1])
    _fmt_date_axis(ax, n_years)

    # Cols 1+: differences
    diff_colors = ['#27ae60', '#e67e22', '#c0392b', '#7d3c98']
    for col, (cdt, color) in enumerate(zip(DIFF_DTS, diff_colors), start=1):
        ax = axes[row][col]
        diff = interp[cdt][var].values - ref_vals
        ax.plot(t_mpl, diff, lw=0.7, color=color)
        ax.axhline(0, color='k', lw=0.5, ls='--')
        ax.set_title(f'{label}  |  {col_titles[col]}', fontsize=8)
        ax.set_ylabel(f'Δ {unit}', fontsize=8)
        ax.set_xlim(t_mpl[0], t_mpl[-1])
        _fmt_date_axis(ax, n_years)

# ── Save ──────────────────────────────────────────────────────────────────────
plot_path = OUTPUT_DIR / 'dt_effects_comparison.png'
fig.savefig(plot_path, dpi=150, bbox_inches='tight')
plt.close(fig)
print(f'\nPlot saved → {plot_path.relative_to(_REPO_ROOT)}')
