module kei_ecocommon

  use kei_parameters
	use kei_kinds, only: i4, r4, r8, log_kind
	implicit none

	Public
	Save
     integer(i4), parameter :: &
          ecosys_tracer_cnt = 24

     ! number of vertical layers
     ! sourced using equivalence to kei_parameters, for code compatibility
     integer(i4), parameter :: &
          km = NZ
     !equivalence (nz,km)

      integer(i4), parameter :: &
        imt = 1,  &   ! x (longitudinal) dimension of ecosys variables
        jmt = 1       ! y (latitudinal) dimension of ecosys variables

!-----------------------------------------------------------------------
!     tracer indices
!-----------------------------------------------------------------------

    integer(i4), parameter :: &
      po4_ind     =  1,  & ! dissolved inorganic phosphate
      no3_ind     =  2,  & ! dissolved inorganic nitrate
      sio3_ind    =  3,  & ! dissolved inorganic silicate
      nh4_ind     =  4,  & ! dissolved ammonia
      fe_ind      =  5,  & ! dissolved inorganic iron
      o2_ind      =  6,  & ! dissolved oxygen
      dic_ind     =  7,  & ! dissolved inorganic carbon
      alk_ind     =  8,  & ! alkalinity
      doc_ind     =  9,  & ! dissolved organic carbon
      spC_ind     = 10,  & ! small phytoplankton carbon
      spChl_ind   = 11,  & ! small phytoplankton chlorophyll
      spCaCO3_ind = 12,  & ! small phytoplankton caco3
      diatC_ind   = 13,  & ! diatom carbon
      diatChl_ind = 14,  & ! diatom chlorophyll
      zooC_ind    = 15,  & ! zooplankton carbon
      spFe_ind    = 16,  & ! small phytoplankton iron
      diatSi_ind  = 17,  & ! diatom silicon
      diatFe_ind  = 18,  & ! diatom iron
      diazC_ind   = 19,  & ! diazotroph carbon
      diazChl_ind = 20,  & ! diazotroph Chlorophyll
      diazFe_ind  = 21,  & ! diazotroph iron
      don_ind     = 22,  & ! dissolved organic nitrogen
      dofe_ind    = 23,  & ! dissolved organic iron
      dop_ind     = 24     ! dissolved organic phosphorus

    character (len = 8), dimension(ecosys_tracer_cnt), &
      parameter :: eco_tracer_name = (/ &
        'PO4     ', &
        'NO3     ', &
        'SiO3    ', &
        'NH4     ', &
        'Fe      ', &
        'O2      ', &
        'DIC     ', &
        'ALK     ', &
        'DOC     ', &
        'spC     ', &
        'spChl   ', &
        'spCaCO3 ', &
        'diatC   ', &
        'diatChl ', &
        'zooC    ', &
        'spFe    ', &
        'diatSi  ', &
        'diatFe  ', &
        'diazC   ', &
        'diazChl ', &
        'diazFe  ', &
        'DON     ', &
        'DOFe    ', &
        'DOP     ' /)

!-----------------------------------------------------------------------
!     Ecosystem tunables used by module kei_eco (applied in ecosys_init_apply_ecocommon_parms).
!     Legacy rates defined as (coef * dps) in kei_eco (dps = 1/86400 s^-1):
!       coef stored here as eco_*_pre_dps ; kei_eco sets param = eco_*_pre_dps * dps.
!     Restoring time: eco_parm_rest_prod_tau_days * spd -> parm_rest_prod_tau (sec).
!-----------------------------------------------------------------------

	!   Redfield ratios, dissolved & particulate (bases; derived ratios in kei_eco)
	!
	real(r8) :: eco_Red_D_C_P = 117.0_r8      ! dissolved C:P (carbon:phosphorus)
	real(r8) :: eco_Red_D_N_P = 16.0_r8       ! dissolved N:P (nitrogen:phosphorus)
	real(r8) :: eco_Red_D_O2_P = 170.0_r8     ! dissolved O2:P (oxygen:phosphorus)
	real(r8) :: eco_Red_Fe_C = 3.0e-6_r8       ! dissolved Fe:C (iron:carbon)
	real(r8) :: eco_Red_diaz_C_O2_divisor = 150.0_r8  ! divisor for parm_Red_D_C_O2_diaz (= C/O2 diaz.)

	!
	!   Parameters previously hardcoded in ecosystem code (coef × dps -> 1/sec)
	!
	real(r8) :: eco_PCref_pre_dps = 3.0_r8    ! coef; → max phyto C-spec. growth rate at Tref (1/sec)
	real(r8) :: eco_PCrefSp_pre_dps = 4.5_r8    ! coef; → small-phyto C-spec. growth at Tref (1/sec)
	real(r8) :: eco_PCrefDiat_pre_dps = 4.5_r8  ! coef; → diatom C-spec. growth at Tref (1/sec)
	real(r8) :: eco_sp_mort_pre_dps = 0.1_r8    ! coef; → small-phyto linear mort rate (1/sec)
	real(r8) :: eco_sp_mort2_pre_dps = 0.0009_r8 ! coef; → small-phyto quad. mort (1/sec/(mmol C/m3)^2 order)
	real(r8) :: eco_diat_mort_pre_dps = 0.1_r8  ! coef; → diatom linear mort rate (1/sec)
	real(r8) :: eco_diat_mort2_pre_dps = 0.0009_r8 ! coef; → diatom quad. mort (1/sec/(mmol C/m3)^2 order)
	real(r8) :: eco_PCrefDiaz_pre_dps = 0.4_r8    ! coef; → diaz C-spec. growth at Tref (1/sec)
	real(r8) :: eco_diaz_mort_pre_dps = 0.16_r8   ! coef; → diaz mort rate (1/sec)
	real(r8) :: eco_diaz_kPO4 = 0.005_r8           ! diaz half-sat. P (diatom value)
	real(r8) :: eco_diaz_kFe = 0.1e-3_r8         ! diaz half-sat. Fe

	!
	!   Misc. rate constants
	!
	real(r8) :: eco_sp_agg_rate_max = 0.75_r8       ! max aggregation rate small phyto (1/d)
	real(r8) :: eco_diat_agg_rate_max = 0.75_r8     ! max aggregation rate diatoms (1/d)
	real(r8) :: eco_diat_agg_rate_min = 0.01_r8     ! min aggregation rate diatoms (1/d)
	real(r8) :: eco_fe_scavenge_rate0 = 0.12_r8      ! initial Fe scavenging rate (% of ambient)
	real(r8) :: eco_fe_scavenge_thres1 = 0.6e-3_r8   ! upper threshold for Fe scavenging
	real(r8) :: eco_fe_scavenge_thres2 = 0.5e-3_r8   ! lower threshold for Fe scavenging
	real(r8) :: eco_dust_fescav_scale = 0.833e8_r8 ! dust scavenging scale factor
	real(r8) :: eco_thres_fe = 1.0e5_r8             ! threshold depth for Fe diffusive flux
	real(r8) :: eco_fe_max_scale1 = 3.0_r8          ! unitless scaling coefficient
	real(r8) :: eco_fe_max_scale2_num = 6.0_r8      ! numerator for fe_max_scale2 (unitless scaling)
	real(r8) :: eco_fe_max_scale2_den = 1.4e-3_r8   ! denominator for fe_max_scale2 (matches legacy 6/1.4e-3)
	real(r8) :: eco_fe_diff_rate = 2.3148e-6_r8     ! Fe diffusion rate (nmol Fe/cm^2/sec)
	real(r8) :: eco_f_fescav_P_iron = 0.1_r8       ! fraction of Fe scavenging → particulate Fe

	!
	!   Dust → Fe conversion: dust_to_Fe = mass_ratio/M_Fe(mol)*nm_scale → (nmol Fe/g dust)
	!   Legacy: dust_to_Fe = 0.035/55.847*1.e9
	!
	real(r8) :: eco_dust_fe_mass_ratio = 0.035_r8        ! g Fe per g dust (mass ratio in formula)
	real(r8) :: eco_dust_fe_molar_mass_g_mol = 55.847_r8 ! g Fe / mol Fe
	real(r8) :: eco_dust_to_fe_nm_scale = 1.0e9_r8       ! scale to nmol Fe

	!
	!   Partitioning phytoplankton growth, grazing & losses (fractions nondim.)
	!
	real(r8) :: eco_z_ingest = 0.15_r8            ! zoo ingestion coefficient (-)
	real(r8) :: eco_caco3_poc_min = 0.4_r8         ! min QCaCO3 vs grazing loss to POC (mmol C/mmol CaCO3)
	real(r8) :: eco_spc_poc_fac = 0.22_r8          ! small-phyto grazing factor (1/mmol C)
	real(r8) :: eco_f_graze_sp_poc_lim = 0.24_r8   ! (fraction / limit parameter in grazing)
	real(r8) :: eco_f_prod_sp_CaCO3 = 0.026_r8     ! fraction of small-phyto prod. as CaCO3 prod.
	real(r8) :: eco_f_photosp_CaCO3 = 0.4_r8      ! proportionality small-phyto prod. vs CaCO3 prod.
	real(r8) :: eco_f_graze_sp_doc = 0.34_r8       ! fraction small-phyto grazing → DOC (f_dic derived in eco)
	real(r8) :: eco_f_z_grz_sqr_diat = 0.81_r8     ! grazing nonlinearity squared term (diatoms)
	real(r8) :: eco_f_graze_diat_poc = 0.26_r8     ! fraction diatom grazing → POC
	real(r8) :: eco_f_graze_diat_doc = 0.13_r8     ! fraction diatom grazing → DOC
	real(r8) :: eco_f_diat_loss_poc = 0.05_r8      ! fraction diatom loss → POC (f_dc derived in eco)
	real(r8) :: eco_f_graze_diaz_zoo = 0.21_r8      ! fraction diaz grazing → zooplankton
	real(r8) :: eco_f_graze_diaz_poc = 0.0_r8      ! fraction diaz grazing → POC
	real(r8) :: eco_f_graze_diaz_doc = 0.24_r8     ! fraction diaz grazing → DOC
	real(r8) :: eco_f_sp_zoo_detr = 0.06666_r8     ! zoo losses → detritus when grazing sp (-)
	real(r8) :: eco_f_diat_zoo_detr = 0.1333_r8    ! zoo losses → detritus when grazing diatoms (-)
	real(r8) :: eco_f_diaz_zoo_detr = 0.03333_r8   ! zoo losses → detritus when grazing diaz (-)
	real(r8) :: eco_f_graze_CaCO3_remin = 0.33_r8  ! fraction of sp CaCO3 grazing remineralized (-)
	real(r8) :: eco_f_graze_si_remin = 0.5_r8      ! fraction diatom Si grazing remineralized (-)

	!
	!   Fixed ratio: N fixation vs carbon fixation
	!
	real(r8) :: eco_r_Nfix_photo = 1.43_r8       ! N fix relative to C fix (-)

	!
	!   Stoichiometry N/C, P/C, Si/C, Fe/C, Chl (Anderson & Sarmiento 1994; diaz N/P Letelier & Karl 1998)
	!
	real(r8) :: eco_Q = 0.137_r8                   ! phyto+zoo N/C (mmol/mmol)
	real(r8) :: eco_Qp = 0.00855_r8                ! P/C small phyto diatom zoo (mmol/mmol)
	real(r8) :: eco_Qp_diaz = 0.002735_r8          ! diaz P/C (-)
	real(r8) :: eco_Qfe_zoo = 2.5e-6_r8            ! zoo Fe/C ratio (-)
	real(r8) :: eco_gQsi_0 = 0.137_r8               ! initial diatom Si/C (-)
	real(r8) :: eco_gQfe_diat_0 = 6.0e-6_r8        ! initial diatom Fe/C (-)
	real(r8) :: eco_gQfe_sp_0 = 6.0e-6_r8          ! initial small-phyto Fe/C (-)
	real(r8) :: eco_gQfe_diaz_0 = 42.0e-6_r8       ! initial diaz Fe/C (-)
	real(r8) :: eco_gQfe_diat_min = 2.5e-6_r8      ! min diatom Fe/C (-)
	real(r8) :: eco_gQsi_max = 0.685_r8            ! max diatom Si/C (-)
	real(r8) :: eco_gQsi_min = 0.0685_r8           ! min diatom Si/C (-)
	real(r8) :: eco_gQsi_coef = 2.5_r8             ! Si/C parameter (-)
	real(r8) :: eco_gQfe_sp_min = 2.5e-6_r8        ! min small-phyto Fe/C (-)
	real(r8) :: eco_gQfe_diaz_min = 14.0e-6_r8     ! min diaz Fe/C (-)
	real(r8) :: eco_QCaCO3_max = 0.4_r8           ! max QCaCO3 (-)
	real(r8) :: eco_thetaN_max_sp = 2.5_r8          ! max Chl/N small phyto (mg Chl/mmol N)
	real(r8) :: eco_thetaN_max_diat = 4.0_r8        ! max Chl/N diatoms (mg Chl/mmol N)
	real(r8) :: eco_thetaN_max_diaz = 3.4_r8       ! max Chl/N diaz (mg Chl/mmol N)
	! Denitrification C:N denominator: legacy denitrif_C_N = parm_Red_D_C_P/136 ;
	!   net removal 120 mol NO3 per 117 mol C (136 = 120 + 16)
	real(r8) :: eco_denitrif_c_n_denominator = 136.0_r8

	!
	!   Loss thresholds & CaCO3 / diaz temperature (loss terms, conc. or °C)
	!
	real(r8) :: eco_thres_z1 = 100.0e2_r8        ! threshold depth z: shallow (cm): C_loss full
	real(r8) :: eco_thres_z2 = 200.0e2_r8         ! threshold depth z: deep (cm): losses → 0
	real(r8) :: eco_loss_thres_sp = 0.003_r8       ! small phyto conc. cutoff for losses → 0 (mmol C/m3 scale)
	real(r8) :: eco_loss_thres_diat = 0.03_r8       ! diatom conc. cutoff (-)
	real(r8) :: eco_loss_thres_zoo = 0.03_r8        ! zoo conc. cutoff (-)
	real(r8) :: eco_loss_thres_diaz = 0.01_r8      ! diaz conc. cutoff (-)
	real(r8) :: eco_loss_thres_diaz2 = 0.001_r8    ! diaz conc. threshold low temperature (-)
	real(r8) :: eco_diaz_temp_thres = 15.0_r8       ! °C where diaz conc. threshold transitions
	real(r8) :: eco_CaCO3_temp_thres1 = 1.0_r8      ! upper °C threshold CaCO3 production
	real(r8) :: eco_CaCO3_temp_thres2 = -2.0_r8     ! lower °C threshold
	real(r8) :: eco_CaCO3_sp_thres = 3.0_r8         ! bloom small-phyto condition (mmol C/m^3)

	!
	!   PAR attenuation (-)
	!
	real(r8) :: eco_k_chl = 0.03e-2_r8           ! Chl attenuation (1/cm per mg Chl/m^3)
	real(r8) :: eco_k_h2o = 0.04e-2_r8            ! water attenuation (1/cm)
	real(r8) :: eco_f_qsw_par = 0.45_r8          ! PAR fraction of shortwave (-)

	!
	!   Temperature response for rates (eco module Tref/Q_10, not ocean Tref in kei_common)
	!
	real(r8) :: eco_Tref_degC = 30.0_r8          ! reference temperature (°C)
	real(r8) :: eco_Q_10_factor = 2.0_r8          ! Q10 factor (-)

	!
	!   Ecosystem parms (many were “input-file” parms in CESM-style naming)
	!
	real(r8) :: eco_parm_Fe_bioavail = 0.02_r8    ! fraction of Fe flux bioavailable (-)
	real(r8) :: eco_parm_prod_dissolve = 0.67_r8    ! fraction of production → DOC (-)
	real(r8) :: eco_parm_o2_min = 4.0_r8            ! min O2 for prod/consump. (nmol/cm^3)
	real(r8) :: eco_parm_no3_min = 32.0_r8         ! min NO3 for denitrification (mmol/m^3)
	real(r8) :: eco_parm_Rain_CaCO3 = 0.07_r8       ! rain ratio CaCO3 (-)
	real(r8) :: eco_parm_Rain_SiO2 = 0.03_r8        ! rain ratio SiO2 (-)
	real(r8) :: eco_parm_kappa_nitrif_pre_dps = 0.06_r8 ! coef; ×dps → nitrification rate (1/s); (=1/d basis)
	real(r8) :: eco_parm_nitrif_par_lim = 5.0_r8     ! PAR limit nitrification (W/m^2)
	real(r8) :: eco_parm_POC_flux_ref = 2.0e-3_r8    ! reference POC flux (nmol C/cm^2/s)
	real(r8) :: eco_parm_rest_prod_tau_days = 30.0_r8 ! restoring prod time-scale (days); ×spd→ sec
	real(r8) :: eco_parm_rest_prod_z_c = 7500.0_r8   ! depth limit restoring prod (cm)
	real(r8) :: eco_parm_z_umax_0_pre_dps = 1.5_r8    ! coef; ×dps → max zoo growth on sphyto at Tref (1/s)
	real(r8) :: eco_parm_diat_umax_0_pre_dps = 1.5_r8 ! coef; ×dps → max zoo growth on diatoms at Tref (1/s)
	real(r8) :: eco_parm_z_mort_0_pre_dps = 0.17_r8   ! coef; ×dps → zoo linear mort (1/s)
	real(r8) :: eco_parm_z_mort2_0_pre_dps = 0.0035_r8 ! coef; ×dps → zoo quadratic mort (1/s per (mmolC/m3))
	real(r8) :: eco_parm_sd_remin_0_pre_dps = 0.01_r8  ! coef; ×dps → small detritus remin (1/s)
	real(r8) :: eco_parm_sp_kNO3 = 0.5_r8            ! sp NO3 half-saturation (mmol N/m^3)
	real(r8) :: eco_parm_diat_kNO3 = 2.5_r8            ! diatom NO3 half-saturation (mmol N/m^3)
	real(r8) :: eco_parm_sp_kNH4 = 0.01_r8            ! sp NH4 half-saturation (mmol N/m^3)
	real(r8) :: eco_parm_diat_kNH4 = 0.1_r8           ! diatom NH4 half-saturation (mmol N/m^3)
	real(r8) :: eco_parm_sp_kFe = 0.035e-3_r8       ! sp Fe half-saturation (nmol Fe/m^3)
	real(r8) :: eco_parm_diat_kFe = 0.08e-3_r8        ! diatom Fe half-saturation (nmol Fe/m^3)
	real(r8) :: eco_parm_diat_kSiO3 = 1.0_r8          ! diatom SiO3 half-saturation (mmol SiO3/m^3)
	real(r8) :: eco_parm_sp_kPO4 = 0.01_r8            ! sp PO4 half-saturation (mmol P/m^3)
	real(r8) :: eco_parm_diat_kPO4 = 0.1_r8           ! diatom PO4 half-saturation (mmol P/m^3)
	real(r8) :: eco_parm_z_grz = 1.05_r8              ! grazing coefficient small phyto (mmol C/m^3 reference)
	real(r8) :: eco_parm_alphaChl_pre_dps = 0.25_r8   ! coef; ×dps → Chl-normalized P-I init slope (GD98 units)
	real(r8) :: eco_parm_alphaChlsp_pre_dps = 0.28_r8  ! same for small phyto (mmol C m^2/(mg Chl W s))
	real(r8) :: eco_parm_alphaChldiat_pre_dps = 0.25_r8 ! same for diatoms
	real(r8) :: eco_parm_alphaChlphaeo_pre_dps = 0.68_r8 ! same for phaeocystis-like pool
	real(r8) :: eco_parm_labile_ratio = 0.70_r8        ! frac. routed directly to DIC (-)
	real(r8) :: eco_parm_alphaDiaz_pre_dps = 0.036_r8  ! coef; ×dps → diaz P-I slope
	real(r8) :: eco_parm_diaz_umax_0_pre_dps = 1.2_r8  ! coef; ×dps → max zoo growth on diaz at Tref (1/s)

!-----------------------------------------------------------------------
!     terms that may be of interest to output
!-----------------------------------------------------------------------

       real(r8), dimension(:,:), allocatable, target :: &
        XKW_tavg, AP_tavg, PV_CO2_tavg, PV_O2_tavg, &
        SCHMIDT_O2_tavg, O2SAT_tavg, &
        FG_O2_tavg, SCHMIDT_CO2_tavg, PH_tavg, CO2STAR_tavg, &
        DCO2STAR_tavg, pCO2SURF_tavg, DpCO2_tavg, FG_CO2_tavg, &
        IRON_FLUX_tavg, PROD_tavg, PO4_RESTORE_tavg, NO3_RESTORE_tavg, &
        SiO3_RESTORE_tavg, PAR_avg_tavg, PO4STAR_tavg, POC_FLUX_IN_tavg, &
        POC_PROD_tavg, POC_REMIN_tavg, CaCO3_FLUX_IN_tavg, &
        CaCO3_PROD_tavg, CaCO3_REMIN_tavg, SiO2_FLUX_IN_tavg, &
        SiO2_PROD_tavg, SiO2_REMIN_tavg, dust_FLUX_IN_tavg, &
        dust_REMIN_tavg, P_iron_FLUX_IN_tavg, P_iron_PROD_tavg, &
        P_iron_REMIN_tavg, graze_sp_tavg, graze_diat_tavg, &
        graze_tot_tavg, sp_loss_tavg, diat_loss_tavg, zoo_loss_tavg, &
        sp_agg_tavg, diat_agg_tavg, photoC_sp_tavg, photoC_diat_tavg, &
        tot_prod_tavg, DOC_prod_tavg, DOC_remin_tavg, Fe_scavenge_tavg, &
        sp_N_lim_tavg, sp_Fe_lim_tavg, sp_PO4_lim_tavg, &
        sp_light_lim_tavg, diat_N_lim_tavg, diat_Fe_lim_tavg, &
        diat_PO4_lim_tavg, diat_SiO3_lim_tavg, diat_light_lim_tavg, &
        CaCO3_form_tavg, diaz_Nfix_tavg, graze_diaz_tavg,diaz_loss_tavg, &
        photoC_diaz_tavg, diaz_P_lim_tavg, diaz_Fe_lim_tavg, &
        diaz_light_lim_tavg, Fe_scavenge_rate_tavg, DON_prod_tavg, &
        DON_remin_tavg, DOFe_prod_tavg, DOFe_remin_tavg, DOP_prod_tavg, &
        DOP_remin_tavg, bSi_form_tavg, photoFe_diaz_tavg, &
        photoFe_diat_tavg, photoFe_sp_tavg, FvPE_DIC_tavg,  &
        FvPE_ALK_tavg, NITRIF_tavg, DENITRIF_tavg

       ! output parameters
       real(r4), dimension(km) :: &
          tot_prod, diat_Fe_lim, diat_light_lim, graze_diat, graze_tot, &
          diat_N_lim, diat_P_lim, diat_Si_lim, sp_N_lim, sp_P_lim, sp_Fe_lim, &
          graze_sp, sp_light_lim

!-----------------------------------------------------------------------
!     forcing variables required for ecosys module
!-----------------------------------------------------------------------

		real(r8), parameter :: &
		 atm_co2_const = 400.0_r8, &  ! default constant CO2
		 ap_const = 1.0_r8             ! default constant air pressure (atm)

		real(r8) :: &
		 dust_flux,          & ! surface dust flux
!       iron_flux,         & ! iron component of surface dust flux
		 winds_SQR,          & ! wind-speed ** 2
		 xkw,                & ! a * U10_SQR
		 atm_co2,            & ! atmospheric CO2 concentration
		 ap                    ! atmospheric pressure

		real(r8), dimension (ecosys_tracer_cnt) :: &
      ice_to_ocean_eflux

		! restoring nutrient climatology switches
		logical(kind=log_kind), parameter :: &
			lrest_po4 = .false. , &        ! po4 climatological restoring switch
			lrest_no3 = .false. , &        ! no3 climatological restoring switch
			lrest_sio3 = .false. , &       ! sio3 climatological restoring switch
			lflux_gas_co2 = .true., &      ! atmospheric co2 flux switch
		  lflux_gas_o2 = .true., &       ! atmospheric o2 flux switch
		  lsource_sink = .true.          ! T = compute ecosys, F = inorganic only

		! restoring nutrient climatology profiles
		real(r8), dimension(imt,jmt,km) :: &
			PO4_CLIM, NO3_CLIM, SiO3_CLIM

		! timescales and depths for nutrient restoring
		real(r8), parameter :: &
			rest_time_inv_surf = 0.0_r8, &  ! 0 = instant, inverse ?
			rest_time_inv_deep = 0.0_r8, &  ! 0 = instant, inverse ?
			rest_z0            = 1000.0_r8, &  ! m
			rest_z1            = 2000.0_r8     ! m


end module kei_ecocommon
