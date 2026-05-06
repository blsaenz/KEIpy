  module kei_icecommon
  use kei_kinds, only: i4, r4, r8, log_kind

    !use kei_parameters
    ! f2py won't allow this, so specified in two places ... make sure nni = z_max_ice, nns/nnfs = z_max_snow !!
    ! use sia2_parameters, only: z_max_ice, z_max_snow

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

