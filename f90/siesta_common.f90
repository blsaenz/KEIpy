module siesta_common
  use kei_kinds, only: i4, r4, r8, log_kind
	use siesta_parameters

	public
	
		real(r4), allocatable :: ida_multiplier(:)
		real(r4), allocatable :: lda_multiplier(:)
		real(r4), allocatable :: sda_multiplier(:)

		real(r4), save, dimension (301) :: &
				aice, &
				aph, &
				awater, &
				awater_tc, &
				awater_sc, &
				awater_v, &
				aozone, &
				rdsnow, &
				rwsnow, &
				surfacelight
		character (LEN=14) :: &
				datestr
		integer(2), save, pointer :: &
				SSMI_grid_int2(:,:), &
				icevec_grid_int2(:,:,:), &
				Ed_int2(:,:,:), &
				mp_grid_int2(:,:), &
				ec_grid_int2(:,:), &
				eci_grid_int2(:,:)
		real(r4), save, pointer :: &
				kds_wet(:), &
				kds_dry(:), &
				lambda(:), &
				quanta_to_watts(:)              
		real(r4), save, dimension (130) :: &
				mc_prod
		real(r4), save, dimension (ic_n) :: &
				ic_h_max, &
				ic_h_med, &
				ic_h_min              

end module siesta_common