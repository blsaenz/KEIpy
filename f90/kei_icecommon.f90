  module kei_icecommon
  use kei_kinds, only: i4, r4, log_kind

    !use kei_parameters
    ! f2py won't allow this, so specified in two places ... make sure nni = z_max_ice, nns/nnfs = z_max_snow !!
    ! use siesta_parameters, only: z_max_ice, z_max_snow

    implicit none

    integer(i4), parameter  :: &
      nni            =  42,      &  !
      nnfs           =  26,      & !
      nns            =  26        !
    real(r4), parameter :: fs_crit = -0.02 ! height below freeboard at which flooding occurs (m)


    !integer, parameter  :: nnis=nns+nnfs+nni
    integer(i4), parameter  :: nnis=nns+nni

    ! ice advection
    real(r4), parameter :: export_melt_f = 0.  ! fraction of ice exported that is assumed to melt nearby/influence salinity
    real(r4), save :: import_melt_f ! multiplier of calculated ice melt - affects ocean salinity
    real(r4), save :: ice_fe_local ! storage for what concentration of fe the ice has


    integer(i4), save  :: &
      ni_cur,   &
      ns_cur

    real(r4), save  :: &
      Tas,      &
      Ti(nni),  &
      Si(nni),  &
      Ts(nns),  &
      Tfs(nnfs),  &
      dzfs(nnfs), &
      dzs(nns), &
      dzi(nni)

    ! timice
    integer(i4), save :: &
      ndtice,icemax,inew,iold
    real(r4), save :: &
      runice,dti

    ! ice state
    real(r4), save :: &
      fice,hice(0:1),TI0,qI0,uI,vI,albice

    ! ice paras
    real(r4), save :: &
      dsice,tfscl,SWFACS,tmlt,tfrz,sice,rhoice, &
      CPice,epsi,sfrazil,fCoriolis,sslush

    ! ice force
    integer(i4), save :: &
      NSICE
    real(r4), save :: &
      FROCN,FRICE,R1,R0,DHDTice,dhs,dhi,dhfs,shs

    ! snow state
    real(r4), save :: &
      hsn(0:1),rhosn,rhofsnow,CPsn,CPfsnow, &
      hfsnow(0:1)

    ! flx paras
    real(r4), save :: &
      EL,SL,FL,FLSN,C2K,Qsfc

    real(r4), save :: &
      lateral_freshwater_melt_flux

    real(r4), save :: atm_flux_to_ice_surface, &
      ice_ocean_bottom_flux, &
      ice_ocean_bottom_flux_potential, &
      total_ice_melt, &
      total_ice_freeze, &
      frazil_ice_volume, &
      congelation_ice_volume, &
      snow_ice_volume, &
      snow_precip_mass

    ! ----------------------------------------------------------------------
    ! SIESTA sea-ice tunables (save) for f2py/Python; grid thickness PARAMETERs live in siesta_parameters.
    ! If you change mean_floe_diameter or alpha_lateral_melt, set melt_f_denom to their product.
    ! ----------------------------------------------------------------------

    ! --- snow & ice ---
    integer(i4), save :: icecon_mod = 2          ! satellite ice conc. tweak (0 none, 1 90%→100%, 2 80%→100%)
    integer(i4), save :: grid_model = 2          ! vertical grid (0 uniform, 1 hi res ends, 2 variable nlayers)
    real(r4), save :: ksnow = 0.33_r4           ! snow conductivity (W/m/K)
    real(r4), save :: den_s_dry = 0.35_r4         ! dry snow density (g/cm^3)
    real(r4), save :: den_s_wet = 0.35_r4         ! wet snow density (g/cm^3)
    real(r4), save :: den_s_switch = -2.0_r4     ! snow type vs temperature (°C ref)
    real(r4), save :: bb_f = 0.03_r4              ! bubble fraction in sea ice (-)
    real(r4), save :: eps0_s = 0.97_r4            ! LW emissivity snow surface (-)
    real(r4), save :: eps0_i = 0.99_r4            ! LW emissivity ice surface (-)
    real(r4), save :: eps_snow = 0.97_r4          ! LW emissivity snow (same as eps0_s by default)
    real(r4), save :: eps_ice = 0.99_r4           ! LW emissivity ice (same as eps0_i by default)
    real(r4), save :: atan_max = 1.557407724654902_r4  ! = tan(1), atan multiplier for albedo
    real(r4), save :: atan_c_i = 3.114815449309804_r4  ! atan_max/0.5; 0.5 m atan cutoff for albedo
    real(r4), save :: chw = 0.006_r4              ! ocean-ice heat transfer coefficient (-)
    real(r4), save :: mu_w_min = 0.05_r4          ! min u* ice-ocean (-)
    real(r4), save :: Fm_a_switch = 0.90_r4       ! area frac. ML frazil under ice
    real(r4), save :: mean_floe_diameter = 30.0_r4
    real(r4), save :: alpha_lateral_melt = 0.66_r4
    real(r4), save :: melt_f_denom = 30.0_r4 * 0.66_r4    ! legacy mean_floe_diameter*alpha_lateral_melt

    ! --- desalination / brine ---
    integer(i4), save :: desal = 7                ! desalination scheme index
    real(r4), save :: bv_conv = 200.0_r4          ! critical brine volume switch (ppt)
    real(r4), save :: f_sk = 0.5_r4               ! skeletal layer convective openness (-)
    real(r4), save :: fb = 0.0511_r4               ! brine tube fraction (-)
    real(r4), save :: fi = 0.5_r4                  ! minimum ice fraction for model (-)
    real(r4), save :: vb_crit = 50.0_r4           ! gravity drainage brine volume (ppt)
    real(r4), save :: conv_max = 1.74e-5_r4        ! max convective flux (cm^3/cm^2/s)
    real(r4), save :: dbvdt_scale = 1.0_r4         ! desal dilution scaling (-)

    ! --- irradiance / albedo inputs ---
    real(r4), save :: alb_s_dry = 0.98_r4         ! dry snow albedo (-)
    real(r4), save :: alb_s_wet = 0.88_r4         ! wet snow albedo (-)
    real(r4), save :: alb_i_dry = 0.58_r4         ! dry ice albedo (-)
    real(r4), save :: alb_i_wet = 0.505_r4        ! wet ice albedo (-)
    real(r4), save :: h_snowpatch = 0.02_r4       ! bare/snow ice partitioning vs depth
    real(r4), save :: par_to_swd = 2.0_r4         ! PAR to broadband SW energy factor (-)
    real(r4), save :: a_ice_ir = 7.18_r4          ! mean ice NIR absorption coefficient (700–4000 nm)
    integer(i4), save :: par_cf = 0               ! PAR cloud fraction correction (0 off, 1 on)

    ! --- initialization options ---
    integer(i4), save :: iit = 1                  ! initial ice temperature mode
    integer(i4), save :: iis = 0                  ! initial salinity mode
    integer(i4), save :: iin = 4                  ! initial nutrient mode
    integer(i4), save :: iif = 0                  ! initial snow flood (m)
    real(r4), save :: s_const = 9.0_r4            ! bulk salinity when iis=0 (psu)
    real(r4), save :: n_f = 0.3_r4                 ! nutrient fraction when iin=2

    ! --- misc. switches and scalars ---
    integer(i4), save :: ts_is_at = 0             ! fix surface T to air T (0/1)
    integer(i4), save :: kevin_light = 0         ! light scheme (0 Gregg&Carder, 1 Kevin)
    integer(i4), save :: use_pl = 0               ! platelet layer (0/1)
    integer(i4), save :: ncep_f = 6               ! NCEP forcing interval (h)
    integer(i4), save :: pr_on = 0                ! precip to snow-ice shortcut (0/1)
    integer(i4), save :: use_mdiff = 1            ! molecular diffusion to ice base (0/1)
    integer(i4), save :: no_flooding = 0          ! suppress flooding if /=0
    integer(i4), save :: flood_brine = 0          ! flooding/brine mode
    integer(i4), save :: woa_depth = 3            ! WOA level for forcing
    integer(i4), save :: max_it = 100             ! Newton-Raphson max iterations
    integer(i4), save :: snow_ridging = 0         ! snow ridging mass conservation (0/1)
    integer(i4), save :: snow_in_gaps = 1          ! snow in ridge gaps (0/1)
    real(r4), save :: min_sal = 0.1_r4            ! minimum bulk ice salinity (ppt)
    real(r4), save :: nr_tol = 0.005_r4           ! NR tolerance surface temp (-)
    real(r4), save :: gl_max_f = 0.075_r4         ! layer boundary adjustment trigger fraction (-)
    real(r4), save :: fl_max_f = 0.075_r4         ! same for surface flooding (-)
    real(r4), save :: T_ref = -75.0_r4            ! reference for heat integrals (°C)
    real(r4), save :: temp_tol = 1.0e-7_r4       ! temperature iteration tolerance (°C)
    real(r4), save :: fl_crit = -0.02_r4         ! min freeboard for surface flood (m)
    real(r4), save :: fl_ratio = 0.5_r4           ! ice/water in flooded snow (-)
    real(r4), save :: da_f = 0.4_r4               ! lognormal distribution width factor (-)
    real(r4), save :: snow_min = 0.01_r4          ! min snow depth treated as snow (m)
    real(r4), save :: gc_offset = 0.0_r4         ! hour offset gc_par_ice index
    real(r4), save :: snow_fudge = 1.0_r4         ! snow depth multiplier for light (-)
    real(r4), save :: a_factor = 0.3_r4           ! snow absorption delta-Eddington (-)
    real(r4), save :: p_factor = 1.0_r4          ! ice strength vs momentum scalar (-)
    real(r4), save :: snow_rd_lim = 24.0_r4       ! snow distribution redistribution trigger
    real(r4), save :: cv_void_f = 0.3_r4          ! convergence void fraction (-)
    real(r4), save :: cvf_switch = 0.6_r4         ! thin-ice height scale (m)
    real(r4), save :: cvf_thin = 0.33333333_r4   ! thin-ice cv_void_f multiplier (-)
    real(r4), save :: ohf_skew = 0.0_r4          ! ocean heat flux additive skew (W/m^2 scale in usage)
    real(r4), save :: at_skew = 0.0_r4           ! air temperature additive skew (°C)
    real(r4), save :: snow_skew = 0.0_r4         ! snow depth skew — fractional precip mult. (0.5 = +50%)

!    type, public :: flux_type
!      integer :: &
!          jptr
!      real :: &
!          o_latent, &            ! ocean latent
!          o_sensible, &          ! ocean latent
!          o_shortwave, &         ! ocean latent
!          o_longwave, &          ! ocean latent
!          o_ice, &          ! ocean latent
!          i_latent, &            ! ocean latent
!          i_sensible, &          ! ocean latent
!          i_shortwave, &         ! ocean latent
!          i_longwave, &          ! ocean latent
!          i_ocean, &          ! ocean latent
!          ice_heat
!      end type flux_type

  end module kei_icecommon

