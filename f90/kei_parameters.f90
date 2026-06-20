
MODULE kei_parameters

  use kei_kinds, only: i4, r4, r8, log_kind

  IMPLICIT NONE

  PUBLIC

  INTEGER(i4), PARAMETER :: NZ = 400
  INTEGER(i4), PARAMETER :: NZM1 = NZ-1
  INTEGER(i4), PARAMETER :: NZP1 = NZ+1
  INTEGER(i4), PARAMETER :: NDIM = 1
  INTEGER(i4), PARAMETER :: NX = 1
  INTEGER(i4), PARAMETER :: NY = 1
  INTEGER(i4), PARAMETER :: NVEL = 2
  INTEGER(i4), PARAMETER :: NSCLR = 2+25  ! +1 for POC ecosystem tracer
  INTEGER(i4), PARAMETER :: NVP1 = NVEL+1
  INTEGER(i4), PARAMETER :: NSP1 = NSCLR+1

  INTEGER(i4), PARAMETER :: n_sw_outputs = 36 ! This lives here, and in macmods, n_outputs = 36.  How to fix? could use an alloceable array for storage, probably should


  INTEGER(i4), PARAMETER :: itermax = 15
  REAL(r8), PARAMETER :: hmixtolfrac = 0.5_r8

  ! temporary grid
  INTEGER(i4), PARAMETER :: NGRID = 1
  INTEGER(i4), PARAMETER :: NZL = 1
  INTEGER(i4), PARAMETER :: NZU = 2
  INTEGER(i4), PARAMETER :: NZDIVmax = 8
  INTEGER(i4), PARAMETER :: NZtmax = NZ +(NZL+NZU)*(NZDIVmax-1)
  INTEGER(i4), PARAMETER :: NZP1tmax = NZtmax+1
  INTEGER(i4), PARAMETER :: igridmax = 5

  ! fluxes and forcing
  INTEGER(i4), PARAMETER :: NSFLXS = 9
  INTEGER(i4), PARAMETER :: NJDT = 1
  INTEGER(i4), PARAMETER :: NSFLXSM1 = NSFLXS-1
  INTEGER(i4), PARAMETER :: NSFLXSP2 = NSFLXS+2
  INTEGER(i4), PARAMETER :: NFDATA = 13
  INTEGER(i4), PARAMETER :: NFDATAP1 = NFDATA+1
  INTEGER(i4), PARAMETER :: NDHARM = 5

  ! richardson mixing
  INTEGER(i4), PARAMETER :: MR = 100
  INTEGER(i4), PARAMETER :: MRP1 = MR+1

  ! rad/conv model
  INTEGER(i4), PARAMETER :: NPLEV  = 18
  INTEGER(i4), PARAMETER :: NPSAVE = 10

  ! output buffer
  !INTEGER, PARAMETER :: NDOUT = 10+NZP1
  !INTEGER, PARAMETER :: NBUFF = NZP1*(NVp1+NSP1) + &
  !  NZP1*(NVEL+NSCLR) + NDOUT + 3*NZ + 5*NSFLXS

  INTEGER(i4), PARAMETER :: maxmodeadv = 6

  INTEGER(i4), PARAMETER :: forcing_var_cnt = 21  ! +2 for runoff and icefe iron forcing
  ! (forcing field names were in a CHARACTER PARAMETER array; f2py's parser
  ! cannot split that constructor reliably. Names match *_f_ind below.)

  INTEGER(i4), PARAMETER :: &
      date_f_ind = 1,     &  ! date forcing field
      taux_f_ind = 2,     &  ! x-direction windspeed forcing field
      tauy_f_ind = 3,     &  ! y-direction windspeed forcing field
      qswins_f_ind = 4,   &  ! shortwave incident irradiance forcing field
      qlwdwn_f_ind = 5,   &  ! longwave downward irradiance forcing field
      tz_f_ind = 6,       &  ! atmospheric temperature forcing field
      qz_f_ind = 7,       &  ! humidity forcing field
      prain_f_ind = 8,    &  ! rain precipitation forcing field
      psnow_f_ind = 9,    &  ! snow precipitation forcing field
      msl_f_ind = 10,     &  ! mean sea level pressure (mbar)
      h_f_ind = 11,       &  ! specific humidity of air (kg/kg)
      dustf_f_ind = 12,   &  ! atmospheric dust flux forcing field
      divu_f_ind = 13,    &  ! ice divergence forcing field
      ic_f_ind = 14,      &  ! ice concentration (fraction 0-1)
      ain_f_ind = 15,     &  ! ice advection in (fraction 0-1)
      aout_f_ind = 16,    &  ! ice advection out (fraction 0-1)
      swh_f_ind = 17,     &  ! swell height (seaweed module) (m)
      mwp_f_ind = 18,     &  ! mean wave period (seaweed_module) (s)
      cmag_f_ind = 19,    &  ! horizonotal current magnitude (seaweed_module) (m/s)
      runoff_f_ind = 20,  &  ! glacial runoff iron forcing field (mmol Fe/m2/s)
      icefe_f_ind = 21       ! sea-ice iron forcing field (mmol Fe/m2/s)

!   TYPE kei_forcing_type
!     INTEGER :: &
!       f_len,              &   ! length of forcing data (steps)
!       f_wct                   ! switch set to inform whether water column forcing date is present
!     REAL, POINTER :: &
!       wct_interp(:),     &
!       f_interp(:)
!   END TYPE kei_forcing_type

END MODULE kei_parameters


!-----------------------------------------------------------------------
! Note in this version:
!    -albedo for ocean is set in init cnsts and used for QSW from fcomp
!        or fread when rad/conv is not running:
!-----------------------------------------------------------------------

! main (permanent) grid

!     NZ    : number of layers
!     NZP1  : number of grid points
!     NDIM  & NX & NY : dimension of the model(not used in this version)
!     NVEL  : number of velocity components, i.e. 2 for U and V
!     NSCLR : number of scalars, i.e. T, S, and additional scalars
!     hmixtolfrac : convergence tolerance for hmix(new)-hmix(old)
!             iteration in ocnstep: fraction of layer thickness hm(kmix)
!     itermax : maximum number of hmix iterations (on main or temporary
!             grids.

! temporary grid

!     NGRID : number of grids = permanent grid + temporary grids,
!             if only p-grid used: NGRID = 1, if t-grid used: NGRID = NZ
!     NZL   & NZU : refinement interval: it is defined on permanent-grid
!             from (kmix+NZU) to (kmix-NZL)
!     NZDIVmax: maximum number of fine(temporary) grid intervals
!             per permanent grid interval. It is needed to dimension the
!             necessary arrays; the number to be used is being read in
!             as NZDIV.
!     NZtmax: maximum number of layers on temporary grid,
!             the number to be used in this run is read in as NZT.
!     igridmax : maximum number of new grid refinements in ocntgrid

! fluxes and forcing

!     NSFLXS: number of fluxes: sflux(NSFLXS,5,0:NJDT)
!     NJDT  : number of older flux values used to extrapolate new fluxes
!     NDHARM: maximum number of harmonics used to specify forcing
!     NFDATA: number of flux data parameters to be read

! ocean advection
!     maxmodeadv: maximum number of different modes for advection
! richardson mixing

!     MR    : dimension of "F of Ri" in ri_mix routine

! rad/conv model

!     NPLEV : number of levels in atmospheric model.
!             (Note: NPLEV=plev necessary in "rad.par")
!     NPSAVE: number of extra atmospheric variables to be saved

! dimension of output array

!     NDOUT : dimension of output array "dout", so that a number of
!             scalar parameters, as well as one extra profile
!             (on layer or grid) can be stored for diagnostic purposes.
!     NBUFF : dimension of data array "buffer"
