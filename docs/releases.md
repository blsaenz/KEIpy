# Releases

## feature/py313-C — Czajka et al. WAP tuning applied to py313

Changes ported from `archive/Czajka_et_al_WAP` and adapted to the `feature/py313` architecture.

### A — Ecosystem parameter tuning (Czajka et al.)
- Updated nine ecosystem parameters with values from Czajka et al. WAP experiments:
  - `eco_PCrefSp_pre_dps`, `eco_PCrefDiat_pre_dps` — reduced max photosynthesis rates
  - `eco_sp_mort_pre_dps`, `eco_sp_mort2_pre_dps` — increased small phytoplankton mortality
  - `eco_diat_mort_pre_dps`, `eco_diat_mort2_pre_dps` — increased diatom mortality
  - `eco_loss_thres_sp`, `eco_loss_thres_diat`, `eco_loss_thres_zoo` — raised loss thresholds
- Values documented as commented-out entries in `kei_runtime_params.yml`; Fortran defaults in `kei_ecocommon.f90` updated to match

### B — POC ecosystem tracer
- Added 25th ecosystem tracer: particulate organic carbon (POC; index 25)
- `kei_parameters.f90`: `NSCLR` incremented to `2+25`
- `kei_ecocommon.f90`: `ecosys_tracer_cnt` set to 25; `poc_ind = 25` added; `'POC     '` added to tracer name array
- `kei_eco.f90`: `POC_loc` initialized, land-masked, and tracer tendency written (`POC%prod - POC%remin`)
- `kei_util.py`: POC added to `ecosys_output_meta_block` (index 24, mmol C m-3)

### C — Runoff and sea-ice iron forcing fields
- Added two new forcing inputs for glacial iron runoff and sea-ice iron flux
- `kei_parameters.f90`: `forcing_var_cnt` set to 21; `runoff_f_ind = 20`, `icefe_f_ind = 21`
  (indices 17–19 were already occupied by seaweed module fields `swh`, `mwp`, `cmag`)
- `kei_util.py`: `runoff` and `icefe` added to `forcing_output_meta_block`

### D — Ice-fraction-weighted photosynthesis
- Phytoplankton photosynthesis and chlorophyll synthesis now account for sea-ice light attenuation
- PAR under ice is attenuated by a factor of 0.05 (5% transmittance)
- Both small phytoplankton and diatom blocks updated in `ecosys_set_interior`
- `ecosys_set_interior` signature extended to accept `fice_eco` (2D ice fraction field)

### E — Extended depth-profile diagnostic outputs
- Added 13 new depth-profile output variables routed through the Fortran→Python bridge:
  - `sp_loss`, `diat_loss`, `diaz_loss` — phytoplankton and diazotroph loss rates
  - `sp_agg`, `diat_agg` — phytoplankton aggregation rates
  - `DOC_prod`, `DOC_remin` — dissolved organic carbon production and remineralization
  - `FG_CO2` — air-sea CO2 flux (surface value replicated to all levels)
  - `POC_PROD`, `POC_REMIN` — surface-layer POC production and remineralization
  - `CaCO3_PROD`, `CaCO3_REMIN` — surface-layer CaCO3 production and remineralization
  - `PAR_out` — per-layer photosynthetically available radiation
- `kei_ecocommon.f90`: variables declared in `real(r4), dimension(km)` block
- `kei_eco.f90`: k-indexed assignments added in `ecosys_step` output loop; `POC_PROD_tavg`, `POC_REMIN_tavg`, `CaCO3_PROD_tavg`, `CaCO3_REMIN_tavg` uncommented in `ecosys_set_sflux`
- `kei_link.f90`: routing blocks added in `get_nz_data`
- `kei_util.py`: entries added to `ecosys_output_meta`
