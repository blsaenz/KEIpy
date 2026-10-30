# TODO

- Make the vertical grid dynamic and able to be set in YAML parameter file. (Currently f90 recompilation is necessary for a grid change)

# Releases

## Current main

### 2026-10-30: Fix surface air-sea gas flux (CO2, O2) applied without top-layer thickness.
  - This changes results for DIC and O2 (and anything coupled to them).
  - `ecosys_set_sflux` returns surface fluxes in nmol/cm^2/s, but `ecosys_step` added them to the top-layer tracer as if they were tendencies (nmol/cm^3/s), omitting the 1/dz factor. For a 1 m top layer the air-sea gas tendency was ~100x too large, effectively pinning surface DIC/O2 near equilibrium each step (the O2 saturation clamp masked this for O2). The update now multiplies by `dzr_eco(1)`.
  - WAP test case (2000-01-15 to 2000-02-15): column DIC change was ~100x the reported `FG_CO2`; after the fix the column change equals integrated `FG_CO2` plus biology. T, ALK, NO3 (the reference-test variables) are unchanged.
  - Note: `FG_CO2` output is in nmol/cm^2/s (multiply by 0.01 for mmol/m^2/s), not the mmol C m-2 s-1 given in its metadata.

### 2026-06-20: Python package refactored for proper pip installation, classes renamed, enabled variable time step.
  - This is a breaking change
  - Now the basic usage classes, after installation (see installation.md), are avaiable as: keipy.load_forcing and keipy.Simulation
  - The entire model chain can use the dt_sec set in the parameters YAML file, although it is still recommended to use 3600s. Very short time steps can result in developing physical (and biological) artifacts due to flux-coupling effects from atmospheric forcing and feedbacks between nutrient uptake/supply and biological growth/grazing.   

### 2026-06-19: Changes ported from `archive/Czajka_et_al_WAP` and adapted to the `feature/py313` architecture.

### 2026-05-01: `feature/py313` developed that support build changes and numpy changes in f2py from python >=3.12.
  - This is breaking change, in the sense that the setup, build, and packaging are different that previous verions. The underlying KEI model is unchanged.


## v1.1.0: `archive/Czajka_et_al_WAP` - Archive of version used for Czajka et al. 2026 (https://onlinelibrary.wiley.com/doi/abs/10.1029/2025JG009428)

### Changes below were made to calibrate the ecosystem model for use in the West Antarctic Pennisula.
  - Updated nine ecosystem parameters with values from Czajka et al. WAP experiments:
    - `eco_PCrefSp_pre_dps`, `eco_PCrefDiat_pre_dps` — reduced max photosynthesis rates
    - `eco_sp_mort_pre_dps`, `eco_sp_mort2_pre_dps` — increased small phytoplankton mortality
    - `eco_diat_mort_pre_dps`, `eco_diat_mort2_pre_dps` — increased diatom mortality
    - `eco_loss_thres_sp`, `eco_loss_thres_diat`, `eco_loss_thres_zoo` — raised loss thresholds
  - Values documented as commented-out entries in `kei_runtime_params.yml`; Fortran defaults in `kei_ecocommon.f90` updated to match
  - Added 25th ecosystem tracer: particulate organic carbon (POC; index 25)
  - Added two new forcing inputs for glacial iron runoff and sea-ice iron flux
  - Phytoplankton photosynthesis and chlorophyll synthesis now account for sea-ice light attenuation
  - PAR under ice is attenuated by a factor of 0.05 (5% transmittance)
    - Both small phytoplankton and diatom blocks updated in `ecosys_set_interior`
  - Added 13 new depth-profile diagnostic ecosystem variables variables:
    - `sp_loss`, `diat_loss`, `diaz_loss` — phytoplankton and diazotroph loss rates
    - `sp_agg`, `diat_agg` — phytoplankton aggregation rates
    - `DOC_prod`, `DOC_remin` — dissolved organic carbon production and remineralization
    - `FG_CO2` — air-sea CO2 flux (surface value replicated to all levels)
    - `POC_PROD`, `POC_REMIN` — surface-layer POC production and remineralization
    - `CaCO3_PROD`, `CaCO3_REMIN` — surface-layer CaCO3 production and remineralization
    - `PAR_out` — per-layer photosynthetically available radiation

## v1.0.0: Original release used in Saenz et al. 2021 (https://doi.org/10.1017/jog.2023.36)
