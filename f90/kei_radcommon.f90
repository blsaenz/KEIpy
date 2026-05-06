module kei_radcommon
  use kei_kinds, only: i4, r4, r8, log_kind
!    common-blocks for radiative/convective model
!    includes :
!    comtim, drnl, global, prt, crdcon, crdcae, crdctl, crdalb

!     !   Basic grid point resolution parameters
		implicit none

    integer(i4), parameter :: plev    = 18      !  number of vertical levels
    integer(i4), parameter :: plevp   = plev+1  !  number of vertical interfaces
    integer(i4), parameter :: plon    = 1       !  number of longitudes (T42)
    integer(i4), parameter :: plat    = 1       !  number of latitudes (T42)
    integer(i4), parameter :: plond   = 1       !  slt extended domain longitude
    integer(i4), parameter :: psave   = 10      ! number of extra rad/conv variables
!                                    to be stored

!               plond= plon + 1 + 2*nxpt, !slt extended domain longitude

! model control time variables ********************************** comtim

    REAL(r8), save :: calday ! an change calday to double precision
    integer(i4), save :: nstep

! diurnal cycle switch; if true, does diurnal cycle *************** drnl

    logical(kind=log_kind), save :: diurnal

! global mean switch; if true, does global mean computation ***** global

    ! common /glbl/ global
    logical(kind=log_kind), save :: globl ! changes from global, which is keywork in fortran 90 - saenz 7/2011
!
! clear sky switch; if true, does diagn. clear sky comp. ****** clearsky

    logical(kind=log_kind), save :: clrsky
!
! radiation constants ******************************************* crdcon

    real(r4), save :: gravit,   & !  gravitational acceleration
    rga,   & !  1 over gravit
    cpair,   & !  heat capacity air at constant pressure
    epsilo,   & !  ratio mmw h2o to mmw air
    sslp,   & !  standard pressure
    stebol,   & !  stephan boltzmann constant
    rgsslp,   & !  0.5 / (gravit*sslp)
    co2vmr,   & !  co2 volume mixing ratio
    dpfo3,   & !  Doppler factor for o3
    dpfco2,   & !  Doppler factor for co2
    dayspy,   & !  solar days in one year
    pie    ! pie


! water vapor narrow band constants for lw computations ********* crdcae

    real(r4), dimension(2), save :: realk,st,a1,a2,b1,b2

! constant coefficients for water vapor absorptivity and emissivi

    real(r4), dimension(3,4), save :: coefa, coefc, coefe
    real(r4), dimension(4,4), save :: coefb, coefd
    real(r4), dimension(6,2), save :: coeff, coefi
    real(r4), dimension(2,4), save :: coefg, coefh
    real(r4), dimension(3,2), save :: coefj, coefk
    real(r4), dimension(4), save :: c1,c2,c3,c4,c5,c6,c7
    real(r4), save :: c8 ,c9 ,c10,c11,c12,c13,c14,c15,c16,c17, &
    	c18,c19,c20,c21,c22,c23,c24,c25,c26,c27, &
    	c28,c29,c30,c31

! farwing correction constants for narrow-band emissivity model
! introduce farwing correction to account for the
! deficiencies in narrow-band model used to derive the
! emissivity. tuned with arkings line calculations.

        real(r4), save :: fwcoef,fwc1,fwc2,fc1,cfa1


! radiation control variables *********************************** crdctl

! fradsw = .t. iff full shortwave computation
! fradlw = .t. iff full longwave computation

! irad = iteration frequency for radiation computation
! iradae = iteration frequency for absorptivity/
! emissivity computation


    integer(i4), save :: iradae,irad,naclw,nacsw,fnlw,fnsw
    logical(kind=log_kind), save :: aeres


! surface albedo data ******************************************* crdalb

! vs = 0.2 - 0.7 micro-meters wavelength range
! ni = 0.7 - 5.0 micro-meters wavelength range

! s  = strong zenith angle dependent surfaces
! w  = weak   zenith angle dependent surfaces

! the albedos are computed for a model grid box by ascribing values to
! high resolution points from a vegetation dataset, then linearlly
! averaging to the grid box value; ocean and land values are averaged
! together along coastlines; the fraction of every grid box that has
! strong zenith angle dependence is included also.

    real(r4), dimension(plond,plat), save :: & 
    albvss, & !  grid box alb for vs over strng zn srfs
    albvsw, & !  grid box alb for vs over weak  zn srfs
    albnis, & !  grid box alb for ni over strng zn srfs
    albniw, & !  grid box alb for ni over weak  zn srfs
    frctst  ! fraction of area in grid box strng zn

! surface boundary data

! rghnss is the aerodynamic roughness length for the grid box, computed
! by linear averaging of the values ascribed to high resolution
! vegetation dataset values; ocean and land values are averaged together
! at coastlines.

    real(r4), dimension(plond,plat), save :: &
    rghnss  ! aerodynamic roughness length

!  Former ``atmrad.com`` column state (``nrow``, ``pmid``, ``t``, …) lived in
!  ``kei_atmradcommon.f90`` and here; nothing in the current KEI link/use graph
!  referenced it. Removed as unused — revive from CCM-era sources if rad/conv
!  coupling is restored.

end module kei_radcommon


