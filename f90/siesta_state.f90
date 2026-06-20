
module siesta_state

	use kei_kinds, only: i4, r4, r8, log_kind
	
	implicit none

	public

	contains

! **********************************************************************
! subroutine function siesta_ice_state 
! Purpose: single function to calculate total ice state more quickly than single
! functions
! ----------------------------------------------------------------------	

	pure subroutine siesta_ice_state(T_mean,S_mean, &
		bs_mean,bd_mean,d_mean,bv_mean,heat)
		
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			mu,										&	! linear liquidus constant for seawater
			IceD,									&	! pure ice density (g m-3)
			Lf,										&	! latent heat of fusion of water (J g-1)
			ci0,									&	! heat capacity of pure ice (J g-1 K-1)
			cw,  									&	! heat capacity of cold seawater (J g-1 K-1)
			c1e3, 								&	! 1e3
			c1e6, 								&	! 1e6
			nc1, 									&	! -1
			c1, 									&	! 1
			c0											! zero
		use siesta_parameters, only : &
			bb_f										! constant bubble fraction in sea ice (fraction)

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			T_mean,							  & !
			S_mean                	!
		real(r4), intent(out) :: &
			bs_mean,							  & !
			bd_mean,							  & !
			d_mean,							  	& !
			bv_mean,							  & !
			heat                			!

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			alpha0,								& !
			alpha1,								& !
			alpha2,								& !
			alpha3,								& !
			T_melt

		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean

		if (T_mean .lt. T_melt) then

			! calc new brine salinity
			alpha0 = 1.0_r4   ! temp assignment as check below
			if (T_mean .gt. -3.058_r4) then

				! use linear freezing point calc for brine salinity above temp=-3.058
				bs_mean = T_mean/mu

			else

				! use polynomial brine sal estimation for temps colder than -3.058
				if (T_mean .le. -3.058_r4 .and. T_mean .ge. -22.9_r4) then
					alpha0 = -3.9921_r4
					alpha1 = -22.7_r4
					alpha2 = -1.0015_r4
					alpha3 = -0.019956_r4
				elseif (T_mean .lt. -22.9_r4 .and. &
				T_mean .ge. -44.0_r4) then
					alpha0 = 206.24_r4
					alpha1 = -1.8907_r4
					alpha2 = -0.060868_r4
					alpha3 = -0.0010247_r4
				elseif (T_mean .lt. -44.0_r4 .and. &
				T_mean .ge. -54.0_r4) then
					 alpha0 = -4442.1_r4
					 alpha1 = -277.86_r4
					 alpha2 = -5.501_r4
					 alpha3 = -0.03669_r4
				elseif (T_mean .lt. -54.0_r4) then
					 alpha0 = c0
				endif                  

				if (alpha0 .eq. c0) then
					! fix upper brine sal limit at 300 psu
					bs_mean = 300.0_r4
				else
					! use selected polynomial to calc brine sal
					bs_mean = alpha0 + alpha1*T_mean + &
					alpha2*T_mean**2 + alpha3*T_mean**3     ! ppt
				endif

			endif

			! error check brine sal
			if (bs_mean .lt. c0) then
				bs_mean = c0
			endif

			! calculate new brine density (c=800 g m-3 ppt-1)
			bd_mean = 1e6_r4 + bs_mean*800.0_r4      ! g/m^3

			! new ice density
			d_mean = (c1-bb_f)*IceD*bd_mean*bs_mean/(bd_mean*bs_mean - &
				S_mean*(bd_mean - IceD))

			! new brine volume
			bv_mean = c1e3*(d_mean*S_mean)/(bd_mean*bs_mean)  ! ppt

			heat = nc1*d_mean*(ci0*(T_melt - T_mean) &
				+ Lf*(c1 - T_melt/T_mean) - cw*T_melt) ! j/m^3 - not j/m^2
		
		else
		    
      bs_mean = s_mean ! ice is melted
			bd_mean = c1e6 + bs_mean*800.0_r4      ! g/m^3
			d_mean = bd_mean
			bv_mean = c1e3
      heat = cw*T_mean*d_mean
       
    endif		
	
	end subroutine siesta_ice_state

! **********************************************************************



! **********************************************************************
! function siesta_bs 
! Purpose: calculates brine salinity (PSU)
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_bs(T_mean,S_mean)
		
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			mu,										&	! linear liquidus constant for seawater
			c0											! zero

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			T_mean,							  & !
			S_mean                

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			alpha0,								& !
			alpha1,								& !
			alpha2,								& !
			alpha3,								& !
			T_melt

		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean

		if (T_mean .lt. T_melt) then

			! calc new brine salinity
			alpha0 = 1.0_r4   ! temp assignment as check below
			if (T_mean .gt. -3.058_r4) then

				! use linear freezing point calc for brine salinity above temp=-3.058
				siesta_bs = T_mean/mu

			else

				! use polynomial brine sal estimation for temps colder than -3.058
				if (T_mean .le. -3.058_r4 .and. T_mean .ge. -22.9_r4) then
					alpha0 = -3.9921_r4
					alpha1 = -22.7_r4
					alpha2 = -1.0015_r4
					alpha3 = -0.019956_r4
				elseif (T_mean .lt. -22.9_r4 .and. &
				T_mean .ge. -44.0_r4) then
					alpha0 = 206.24_r4
					alpha1 = -1.8907_r4
					alpha2 = -0.060868_r4
					alpha3 = -0.0010247_r4
				elseif (T_mean .lt. -44.0_r4 .and. &
				T_mean .ge. -54.0_r4) then
					 alpha0 = -4442.1_r4
					 alpha1 = -277.86_r4
					 alpha2 = -5.501_r4
					 alpha3 = -0.03669_r4
				elseif (T_mean .lt. -54.0_r4) then
					 alpha0 = c0
				endif                  

				if (alpha0 .eq. c0) then
					! fix upper brine sal limit at 300 psu
					siesta_bs = 300.0_r4
				else
					! use selected polynomial to calc brine sal
					siesta_bs = alpha0 + alpha1*T_mean + &
					alpha2*T_mean**2 + alpha3*T_mean**3     ! ppt
				endif

			endif

			! error check brine sal
			if (siesta_bs .lt. c0) then
				siesta_bs = c0
			endif
		
		else
		    
       siesta_bs = s_mean ! ice is melted
       
    endif		
	
	end function siesta_bs

! **********************************************************************

! **********************************************************************
! subroutine function siesta_bd 
! Purpose: calculates brine density (g m-3)
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_bd(bs_mean)

			implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			bs_mean									 !

		! calculate new brine density (c=800 g m-3 ppt-1)
		siesta_bd = 1e6_r4 + bs_mean*800.0_r4      ! g/m^3
			  
	end function siesta_bd

! **********************************************************************

! **********************************************************************
! subroutine function siesta_ice_d 
! Purpose: calculates sea ice density (g m-3)
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_ice_d(t_mean,s_mean,bs_mean,bd_mean)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			mu,										&	! linear liquidus constant for seawater
			IceD										! pure ice density (g m-3)
		use siesta_parameters, only : &
			bb_f										! constant bubble fraction in sea ice (fraction)

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			t_mean,							  	& !
			s_mean,							  	& !
			bs_mean,							  & !
			bd_mean                

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			T_melt

		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean

		if (T_mean .lt. T_melt) then				
	
			! new ice density
			siesta_ice_d = (1.0_r4-bb_f)*IceD*bd_mean*bs_mean / &
				(bd_mean*bs_mean - S_mean*(bd_mean - IceD))
				
		else
		
			siesta_ice_d = bd_mean ! completely melted
			
		endif
			  
	end function siesta_ice_d

! **********************************************************************


! **********************************************************************
! subroutine function siesta_bv 
! Purpose: calculates sea ice brine volume (ppt)
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_bv(t_mean,s_mean, &
		d_mean,bs_mean,bd_mean)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			mu,										&	! linear liquidus constant for seawater
			c0											! zero

		implicit none
				  
	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			t_mean,							  	& !
			s_mean,							  	& !
			d_mean,							  	& !
			bs_mean,							  & !
			bd_mean                

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			T_melt

		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean

		if (T_mean .lt. T_melt) then				

			! new brine volume
			siesta_bv = 1.e3_r4*(d_mean*S_mean)/(bd_mean*bs_mean)  ! ppt

		else
		
			siesta_bv = 1.e3_r4 ! completely melted
			
		endif

	end function siesta_bv

! **********************************************************************


! **********************************************************************
! subroutine function siesta_ice_heat 
! Purpose: calculates enthalpy  from a reference of 0 deg C
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_ice_heat(t_mean,s_mean,d_mean)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			mu,										&	! linear liquidus constant for seawater
			Lf,										&	! latent heat of fusion of water (J g-1)
			ci0,									&	! heat capacity of pure ice (J g-1 K-1)
			cw 											! heat capacity of cold seawater (J g-1 K-1)

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			t_mean,							  	& ! 
			s_mean,							  	& ! 
			d_mean							  	  !

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			T_melt

		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean

		if (T_mean .lt. T_melt) then				
	
			siesta_ice_heat = -1.0_r4*d_mean*(ci0*(T_melt - T_mean) &
				+ Lf*(1.0_r4 - T_melt/T_mean) - cw*T_melt) ! j/m^3 - not j/m^2

    else

      siesta_ice_heat = cw*T_mean*d_mean
              
    endif

	end function siesta_ice_heat

! **********************************************************************

! **********************************************************************
! subroutine function siesta_ice_heat_melt 
! Purpose: calculate energy required to melt ice
! NOTE - Returns a positive heat! (If temp is below T_melt...)
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_ice_heat_melt(t_mean,s_mean, &
		d_mean,t_ocn)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			c0,										&	! zero
			mu,										&	! linear liquidus constant for seawater
			Lf,										&	! latent heat of fusion of water (J g-1)
			ci0,									&	! heat capacity of pure ice (J g-1 K-1)
			cw 											! heat capacity of cold seawater (J g-1 K-1)

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			t_mean,							  	& ! 
			s_mean,							  	& ! 
			d_mean,							  	& ! 
			t_ocn								  	  !

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			T_melt

		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean
		siesta_ice_heat_melt = c0 ! initialize
		
		if (T_mean .lt. T_melt) then					
			siesta_ice_heat_melt = ci0*(T_melt - T_mean) &
				+ Lf*(1.0_r4 - T_melt/T_mean) ! j/m^3 - not j/m^2
!    else
!      siesta_ice_heat_melt = cw*T_mean ! sea ice is already melted             
    endif
		! adjust heat such that melt water is at the mixed layer temperature    
    siesta_ice_heat_melt = (siesta_ice_heat_melt + (t_ocn-t_mean)*cw)*d_mean

	end function siesta_ice_heat_melt

! **********************************************************************


! **********************************************************************
! subroutine function siesta_snow_heat_melt 
! Purpose: calculate energy required to melt snow - right now 
! we assume heat capacity is constant, instead of using Ono 1990...
! NOTE - Returns a positive heat! (If temp is below 0degC...)
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_snow_heat_melt(t_snow,d_snow,t_ocn)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			c0,										&	! zero
			Lf,										&	! latent heat of fusion of ice (J g-1)
			ci0,									&	! heat capacity of pure ice (J g-1 K-1)
			cw 											! heat capacity of cold seawater (J g-1 K-1)

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			t_snow,							  	& ! 
			d_snow,							  	& ! 
			t_ocn							  	  !

!		if (t_snow .le. c0) then				
			siesta_snow_heat_melt = Lf - ci0*t_snow ! j/m^3 - not j/m^2
!    else
!			! ice is already melted!
!      siesta_ice_heat_melt = cw*t_snow          
!    endif
		! adjust heat such that melt water is at the mixed layer temperature    
    siesta_snow_heat_melt = (siesta_snow_heat_melt + &
    	(t_ocn-t_snow)*cw)*d_snow

	end function siesta_snow_heat_melt



! **********************************************************************
! function siesta_ice_temp 
! Purpose: calculates sea ice temperature from enthalpy, salinity, and
! density from a reference heat at 0 deg C
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_ice_temp(s_mean,d_mean,h_mean)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			mu,										&	! linear liquidus constant for seawater
			Lf,										&	! latent heat of fusion of water (J g-1)
			ci0,									&	! heat capacity of pure ice (J g-1 K-1)
			cw 											! heat capacity of cold seawater (J g-1 K-1)

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			s_mean,							  	& ! 
			d_mean,							  	& ! 
			h_mean							  	  !

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			aq,							  			& ! 
			bq,							  			& ! 
			cq,							  			& ! 
			q_melt,							  	& ! 
			T_melt

    q_melt = h_mean/d_mean ! enthalpy in J m-3 assuming melt
		T_melt = mu*s_mean  ! find melt temperature at salinity s_mean

		if (q_melt .lt. T_melt*cw) then

			aq = ci0  ! quadratic a term
			bq = (cw-ci0)*T_melt - Lf - q_melt ! quadratic b term
			cq = Lf*T_melt  ! quadradic c term
			
			! solve heat eqn. backwards to find T_mean
			! the "negative" solutions seem to always be right
			siesta_ice_temp = (-1.0_r4*bq - &
				sqrt(bq**2 - 4.0_r4*aq*cq))/(2.0_r4*aq)

		else	  
				
			siesta_ice_temp = q_melt/cw  ! T = Q/cw

		endif

	end function siesta_ice_temp

! **********************************************************************


! **********************************************************************
! function siesta_snow_heat 
! Purpose: calculates snow reference enthalpy, using a reference 
! enthalpy at t=0degC
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_snow_heat(d_mean,t_mean)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			kelvin0,							&	! K at 0 deg C
			heat_snow0							! reference enthalpy (J g-1) of snow at 0 deg C

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			d_mean,							  	& ! density (g m-3)
			t_mean							  	  ! snow temperature (deg C)

	! Internal Variables
	! --------------------------------------------------------------------
		real(r4) :: &
			T_k												! snow temp in kelvin

		T_k = t_mean + kelvin0
	  siesta_snow_heat = d_mean*(heat_snow0 - 0.2309_r4*T_k - &
			0.0034_r4*T_k**2)

	end function siesta_snow_heat

! **********************************************************************


! **********************************************************************
! function siesta_snow_temp 
! Purpose: calculates snow temperature from enthalpy and
! density from a reference heat at 0 deg C
! ----------------------------------------------------------------------	

	real(r4) pure function siesta_snow_temp(d_mean,h_mean)

	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only : &
			c0,										&	! zero
			kelvin0,							&	! K at 0 deg C
			heat_snow0							! reference enthalpy (J g-1) of snow at 0 deg C

		implicit none

	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			d_mean,							  	& ! snow density (g m-3)
			h_mean							  	  ! snow enthalpy (J m-3)

		! Solve quadradic for new snow temp
		siesta_snow_temp = h_mean/d_mean
		siesta_snow_temp = (0.2309_r4 - &
			sqrt(0.05331481_r4 + 0.0136_r4 * &
			 (heat_snow0-siesta_snow_temp)))/(-0.0068_r4)
		siesta_snow_temp = min(siesta_snow_temp - kelvin0,c0)

	end function siesta_snow_temp

! **********************************************************************


! **********************************************************************
! SUBROUTINE: siesta_ice_mass
! used to find masses of h2o and salt for flux accounting purposes
! note: does not take ice area into account - masses are in kg/m^2
! ----------------------------------------------------------------------	
	pure subroutine siesta_ice_mass(ice,h20,salt)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			c0,							&	! zero 
			c_1e3,					& ! 0.001
			c1e3							! 1000
		use siesta_parameters, only: &
			use_ponds					! melt pond switch
		use siesta_types
		
		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		type (ice_type), intent(in) :: &
			ice             ! ice structure
		real(r4), intent(out) :: &
			h20,          & ! total h20 mass (kg/m^2)
			salt            ! total salt mass (kg/m^2)
			
	! Internal Variables
	! --------------------------------------------------------------------
		integer(i4) :: &
			i           		! iterator
		real(r4) :: &
			mass            ! layer mass (kg/m^2)
			
	! Function Code
	! --------------------------------------------------------------------
		h20 = c0
		salt = c0
	  !do ii=1,ice%snow%z
	  !	h20 = h20 + &
	  !		ice%snow%d(ii)*ice%snow%th(ii)*c_1e3 ! kg h2o
	  !enddo
	  do i=1,ice%z
	  	mass = ice%th(i)*ice%d(i)*c_1e3
	  	h20 = h20 + siesta_layer_h2o(mass,ice%s(i))  ! kg h2o- bubble fraction already accounted for in density
	  	salt = salt + siesta_layer_salt(mass,ice%s(i)) ! kg salt
	  enddo
	  if (use_ponds .eq. 1 .and. ice%pond%th .gt. c0) then
	  	mass = ice%pond%th*ice%pond%d*c_1e3
	  	h20 = h20 + siesta_layer_h2o(mass,ice%pond%s) ! kg h2o
	  	salt = salt + siesta_layer_salt(mass,ice%pond%s) ! kg salt
	  endif
	  
	end subroutine siesta_ice_mass

! **********************************************************************

! **********************************************************************
! SUBROUTINE: siesta_layer_h2o
! used to find h20 mass (kg or kg/m^2) in a mass with salinity in parts
! per thousand (ppt)
! ----------------------------------------------------------------------	
	real(r4) pure function siesta_layer_h2o(mass,salinity)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			c1e3							! 1000
		use siesta_types
		
		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			mass,          & ! total h20 mass (kg or kg/m^2)
			salinity         ! bulk salinity (ppt)
						
	! Function Code
	! --------------------------------------------------------------------
		siesta_layer_h2o = mass*(c1e3 / (c1e3 + salinity))  		 ! kg h2o 
	  
	end function siesta_layer_h2o

! **********************************************************************


! **********************************************************************
! SUBROUTINE: siesta_layer_salt
! used to find salt mass (kg or kg/m^2) in a mass with salinity in parts
! per thousand (ppt)
! ----------------------------------------------------------------------	
	real(r4) pure function siesta_layer_salt(mass,salinity)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			c1e3							! 1000
		
		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		real(r4), intent(in) :: &
			mass,          & ! total h20 mass (kg or kg/m^2)
			salinity         ! bulk salinity (ppt)
						
	! Function Code
	! --------------------------------------------------------------------
		siesta_layer_salt = mass*(salinity / (c1e3 + salinity)) ! kg salt
	  
	end function siesta_layer_salt

! **********************************************************************


! **********************************************************************
! SUBROUTINE: siesta_snow_mass
! used to find mass of h2o int snow for flux accounting purposes
! note: does not take ice area into account - masses are in kg/m^2
! ----------------------------------------------------------------------	
	pure subroutine siesta_snow_mass(ice,h20)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			c0,							&	! zero 
			c_1e3,					& ! 0.001
			c1e3							! 1000
		use siesta_types

		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		type (ice_type), intent(in) :: &
			ice             ! ice structure
		real(r4), intent(out) :: &
			h20            ! total h20 mass (kg/m^2)
			
	! Internal Variables
	! --------------------------------------------------------------------
		integer(i4) :: &
			i        		   	! iterator
		real(r4) :: &
			mass            ! layer mass (kg/m^2)
			
	! Function Code
	! --------------------------------------------------------------------
		h20 = c0
	  do i=1,ice%snow%z
	  	h20 = h20 + &
	  		ice%snow%d(i)*ice%snow%th(i)*c_1e3 ! kg h2o
	  enddo
	  
	end subroutine siesta_snow_mass

! **********************************************************************

! **********************************************************************
! SUBROUTINE: siesta_snow_mass
! used to find mass of h2o int snow for flux accounting purposes
! note: does not take ice area into account - masses are in kg/m^2
! ----------------------------------------------------------------------	
	real(r4) pure function siesta_snow_mean_d(ice)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			c0							! zero
		use siesta_types

		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		type (ice_type), intent(in) :: &
			ice             ! ice structure
			
	! Internal Variables
	! --------------------------------------------------------------------
		integer(i4) :: &
			i           	! iterator
		real(r4) :: &
			th            ! layer mass (kg/m^2)
			
	! Function Code
	! --------------------------------------------------------------------
		siesta_snow_mean_d = c0
		th = c0
	  do i=1,ice%snow%z
	  	siesta_snow_mean_d = siesta_snow_mean_d + &
	  		ice%snow%d(i)*ice%snow%th(i) ! kg h2o
	  	th = th + ice%snow%th(i)
	  enddo
	  siesta_snow_mean_d = siesta_snow_mean_d/th
	  
	end function siesta_snow_mean_d

! **********************************************************************



! **********************************************************************
! SUBROUTINE: siesta_hc
! finds total heat content of ice pack requited to warm ice (hc_i) or
! the entire vertical ice pack (hc_total) to zero C
! ----------------------------------------------------------------------	
!	pure subroutine siesta_hc(ice,hc_i,hc_total)
!	
!	! Use Statements and Variables/Globals/Parameters
!	! --------------------------------------------------------------------
!		use siesta_constants, only: &
!			c0								! zero 
!		use siesta_types
!
!		implicit none
!	
!	! Function Arguments
!	! --------------------------------------------------------------------
!		type (ice_type), intent(in) :: &
!			ice             ! ice structure
!		real(r4), intent(out) :: &
!			hc_i,          & ! heat content of ice (J relative to 0 deg C)
!			hc_total         ! heat content of ice and snow (J relative to 0 deg C)
!			
!	! Internal Variables
!	! --------------------------------------------------------------------
!		integer(int_kind) :: &
!			i            ! iterator
!			
!	! Function Code
!	! --------------------------------------------------------------------
!		hc_i = c0		
!	  do i=1,ice%z
!	  	hc_i = hc_i + ice%heat(i)*ice%th(i) ! J
!	  enddo
!	  hc_total = hc_i
!	  do i=1,ice%snow%z
!	  	hc_total = hc_total - ice%snow%heat(i)*ice%snow%th(i) ! J
!	  enddo
!	  	  
!	end subroutine siesta_hc
	pure subroutine siesta_hc(ice,hc_i,hc_total)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			c0								! zero 
		use siesta_types

		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		type (ice_type), intent(in) :: &
			ice             ! ice structure
		real(r4), intent(out) :: &
			hc_i,          & ! heat content of ice (J relative to 0 deg C)
			hc_total         ! heat content of ice and snow (J relative to 0 deg C)
			
	! Function Code
	! --------------------------------------------------------------------
		call siesta_hc_melt(ice,c0,hc_i,hc_total)
		
	end subroutine siesta_hc


! **********************************************************************

! **********************************************************************
! SUBROUTINE: siesta_hc_melt
! finds total heat content of ice pack requited to warm ice (hc_i) or
! the entire vertical ice pack (hc_total) to t_ocn, the ocean mixed
! layer temperature
! ----------------------------------------------------------------------	
!	pure subroutine siesta_hc_melt(ice,t_ocn,hc_i,hc_total)
!	
!	! Use Statements and Variables/Globals/Parameters
!	! --------------------------------------------------------------------
!		use siesta_constants, only: &
!			cw,							&	! specific heat fo water near 0degC 
!			c0								! zero 
!		use siesta_types
!
!		implicit none
!	
!	! Function Arguments
!	! --------------------------------------------------------------------
!		type (ice_type), intent(in) :: &
!			ice             ! ice structure
!		real(r4), intent(in) :: &
!			t_ocn						! ocean mixed layer temperature (degC)
!		real(r4), intent(out) :: &
!			hc_i,          & ! heat content of ice (J relative to t_ocn)
!			hc_total         ! heat content of ice and snow (J relative to t_ocn)
!			
!	! Internal Variables
!	! --------------------------------------------------------------------
!		integer(int_kind) :: &
!			i            ! iterator
!			
!	! Function Code
!	! --------------------------------------------------------------------
!		hc_i = c0		
!	  do i=1,ice%z
!	  	hc_i = hc_i + (ice%heat(i) - t_ocn*cw*ice%d(i))*ice%th(i) ! J
!	  enddo
!	  hc_total = hc_i
!	  do i=1,ice%snow%z
!	  	hc_total = hc_total - &
!	  		(ice%snow%heat(i) + t_ocn*cw*ice%snow%d(i))*ice%snow%th(i) ! J
!	  enddo
!	  	  
!	end subroutine siesta_hc_melt

! alternate not based on internal heat structure
	pure subroutine siesta_hc_melt(ice,t_ocn,hc_i,hc_total)
	
	! Use Statements and Variables/Globals/Parameters
	! --------------------------------------------------------------------
		use siesta_constants, only: &
			cw,							&	! specific heat fo water near 0degC 
			c0								! zero 
		use siesta_types

		implicit none
	
	! Function Arguments
	! --------------------------------------------------------------------
		type (ice_type), intent(in) :: &
			ice             ! ice structure
		real(r4), intent(in) :: &
			t_ocn						! ocean mixed layer temperature (degC)
		real(r4), intent(out) :: &
			hc_i,          & ! heat content of ice (J relative to t_ocn)
			hc_total         ! heat content of ice and snow (J relative to t_ocn)
			
	! Internal Variables
	! --------------------------------------------------------------------
		integer(i4) :: &
			i            ! iterator
			
	! Function Code
	! --------------------------------------------------------------------
		hc_i = c0		
	  do i=1,ice%z
	  	hc_i = hc_i - &
	  		siesta_ice_heat_melt(ice%t(i),ice%s(i),ice%d(i),t_ocn)*ice%th(i) ! J
	  enddo
	  hc_total = hc_i
	  do i=1,ice%snow%z
	  	hc_total = hc_total - &
	  		siesta_snow_heat_melt(ice%snow%t(i),ice%snow%d(i),t_ocn)*ice%snow%th(i) ! J
	  enddo
	  	  
	end subroutine siesta_hc_melt


end module siesta_state

