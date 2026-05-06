module siesta_constants

	use kei_kinds, only: i4, r4, r8, log_kind

	implicit none

	public

	! ------------------------------------------------------------
	! Elemental data types/sizes
	! ------------------------------------------------------------

	! ------------------------------------------------------------
	! Empirical and Physical Constants
	! ------------------------------------------------------------

	real(r4), parameter :: &
			cw										=	3.96_r4		, &	! heat capacity of water at 0degC (J g-1 K-1)
			ci0										=	2.113_r4		, &	! constant in ice heat capacity equation (W m-1 K-1)
			IceD									=	918000_r4			, &	! density of pure ice (g m-3)
			mu										=	-0.054_r4   ,	&	! linear liquidus constant for seawater
			kelvin0								= 273.15_r4	 	  , &  !	0degC in K
      qq1 									= 1.16378e7_r4  , & ! q1 constant in turbulent latentent heat flux calc, CICE v. 4
      qq2 									= 5897.8_r4     , &  ! q2 constant in turbulent latentent heat flux calc, CICE v. 4
      Lv 										= 2501.0_r4 , & ! kJ/kg latent heat of vaporization of water (2260)
      Lf 										= 334.0_r4 , & ! kJ/kg latent heat of fusion of water (334)
      R_air 								= 287.058_r4  , & ! Universal gas constant for dry air - J/kg/K; pressure must be in Pascals for: density = pressure/RT   
      R_h2o 								= 461.495_r4  , &! Universal gas constant for water vapor - J/kg/K; pressure must be in Pascals for: density = pressure/RT
      heat_snow0 						= 0.2309_r4*kelvin0 + 0.0034_r4*kelvin0**2

		real(r4), parameter :: pi=3.141592_r4
		real(r4), parameter :: steph_boltz=5.66e-8_r4 !W/m^2/K^4
		real(r4), parameter :: gC_mC = 12.01_r4 !gramsC/molesC
		real(r4), parameter :: mC_gC = 1.0_r4/12.01_r4 !molesC/gramC
		real(r4), parameter :: cell_side = 25.067525_r4 ! km
		real(r4), parameter :: cell_area = cell_side**2 ! km^2
		real(r4), parameter :: grav = 9.80616_r4 ! gravity, m/s^2
	
		integer(i4), parameter :: &
			bins 					=	31	      !	num of wavelength bins	

		real(r4), parameter :: fe_A = 2.7798e-6_r4   ! hPa/K^4, turbutent heat flux coefficient
		real(r4), parameter :: fe_B = -2.6913e-3_r4  ! hPa/K^3, turbutent heat flux coefficient
		real(r4), parameter :: fe_C = 0.97920_r4     ! hPa/K^2, turbutent heat flux coefficient
		real(r4), parameter :: fe_D = -158.64_r4     ! hPa/K, turbutent heat flux coefficient
		real(r4), parameter :: fe_E = 9653.2_r4      ! hPa, turbutent heat flux coefficient

		real(r4), parameter :: ss0 = 8.0_r4     ! 1st year ice salinilty standard curve value (top)
		real(r4), parameter :: ss1 = 6.3_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss2 = 5.6_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss3 = 5.3_r4    ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss4 = 5.2_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss5 = 5.1_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss6 = 4.9_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss7 = 4.8_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss8 = 4.8_r4     ! 1st year ice salinilty standard curve value (mid)
		real(r4), parameter :: ss9 = 6.2_r4     ! 1st year ice salinilty standard curve value (bottom)

		real(r4), parameter :: ssm0 = 0.1_r4     ! multi-year salinilty standard curve value (top)
		real(r4), parameter :: ssm1 = 0.2_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm2 = 0.2_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm3 = 0.6_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm4 = 1.9_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm5 = 3.1_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm6 = 3.3_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm7 = 3.4_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm8 = 3.9_r4     ! multi-year salinilty standard curve value (mid)
		real(r4), parameter :: ssm9 = 6.2_r4     ! multi-year salinilty standard curve value (bottom)

		real(r4), parameter :: a0 = -0.12073_r4    ! salinity limiting poly coefficient 0 (dimensionless)
		real(r4), parameter :: a1 = 0.07097_r4     ! salinity limiting poly coefficient 1 (dimensionless)
		real(r4), parameter :: a2 = -0.00133_r4    ! salinity limiting poly coefficient 2 (dimensionless)
		real(r4), parameter :: a3 = 6.3427e-6_r4  ! salinity limiting poly coefficient 3 (dimensionless)

		real(r4), parameter :: a_star = 0.05_r4  ! mean value of areal fraction participating in ridging
		real(r4), parameter :: r_a_star = 20.0_r4  ! 1/a_star
		real(r4), parameter :: adv_mu = 4.0_r4  !  used to calc lambda constant in ice category redistribution function

		! seawater equation of state coefficient alpha
		real(r4), parameter :: d_a(7) = (/ -1.36471e-1_r4, &
			4.68181e-2_r4, 8.07004e-1_r4, -7.45353e-3_r4, &
			-2.94418e-3_r4, 3.43570e-5_r4, 3.48658e-5_r4/)
		! seawater equation of state coefficient beta
		real(r4), parameter :: d_b(7) = (/ 5.06423e-1_r4, &
			-3.57109e-3_r4, -8.76148e-4_r4, 5.25243e-5_r4, &
			1.57976e-5_r4, -3.46686e-7_r4, -1.68764e-7_r4/)
		! seawater equation of state coefficient gamma
		real(r4), parameter :: d_g(7) = (/ -5.52640e-4_r4, &
			4.88584e-6_r4, 9.96027e-7_r4, -7.25139e-8_r4, &
			-3.98736e-9_r4, 4.00631e-10_r4, 8.26368e-11_r4/)

		real(r4), parameter :: logn_multiplier9(9) = &
			(/0.102_r4, 0.272_r4, 0.427_r4, 0.532_r4, &
			0.721_r4, 0.952_r4, 1.31_r4, 1.74_r4, &
			3.31_r4/)

		real(r4), parameter :: logn_multiplier6(6) = &
			(/0.145_r4, 0.385_r4, 0.585_r4, 0.860_r4, &
			1.345_r4, 2.70_r4/)
		real(r4), parameter :: logn_multiplier5(5) = &
			(/1.82e-1_r4, 4.08e-1_r4, 6.96e-1_r4, &
			1.14_r4, 2.59_r4/)

		real(r4), target :: gauss_bins_3(4) = (/0.0_r4, &
			1.3717e-01_r4, 3.0777e-01_r4, 1.0_r4/)
		real(r4), target :: gauss_bins_4(5) = (/0.0_r4, &
			1.0153e-01_r4, 2.1483e-01_r4, 3.6633e-01_r4, &
			1.0_r4/)
		real(r4), target :: gauss_bins_5(6) = (/0.0_r4, &
			8.0522e-02_r4, 1.6677e-01_r4, 2.6766e-01_r4, &
			4.0738e-01_r4, 1.0_r4/)
		real(r4), target :: gauss_bins_6(7) = (/0.0_r4, &
			6.7155e-02_r4, 1.3749e-01_r4, 2.1515e-01_r4, &
			3.0840e-01_r4, 4.4080e-01_r4, 1.0_r4/)
		real(r4), target :: gauss_bins_7(8) = (/0.0_r4, &
			5.7288e-02_r4, 1.1649e-01_r4, 1.8014e-01_r4, &
			2.5207e-01_r4, 3.3991e-01_r4, 4.6626e-01_r4, &
			1.0_r4/)
		real(r4), target :: gauss_bins_8(9) = (/0.0_r4, &
			5.0286e-02_r4, 1.0185e-01_r4, 1.5595e-01_r4, &
			2.1515e-01_r4, 2.8294e-01_r4, 3.6696e-01_r4, &
			4.8950e-01_r4, 1.0_r4/)
		real(r4), target :: gauss_bins_9(10) = (/0.0_r4, &
			4.4558e-02_r4, 9.0070e-02_r4, 1.3749e-01_r4, &
			1.8810e-01_r4, 2.4411e-01_r4, 3.0872e-01_r4, &
			3.8956e-01_r4, 5.0859e-01_r4, 1.0_r4/)
		real(r4), target :: gauss_bins_10(11) = (/0.0_r4, &
			4.0102e-02_r4, 8.0840e-02_r4, 1.2285e-01_r4, &
			1.6709e-01_r4, 2.1483e-01_r4, 2.6798e-01_r4, &
			3.3004e-01_r4, 4.0802e-01_r4, 5.2355e-01_r4, &
			1.0_r4/)

		real(r4), parameter :: pur_c = 0.0246059207996924_r4
		real(r4), parameter :: one_over_pur_c = 40.6406250000000_r4          
		real(r4), parameter :: pur_c_2 = 0.0244140625000000_r4
		real(r4), parameter :: one_over_pur_c_2 = 40.96_r4
!          integer (kind=1), parameter :: pur_0 = -127
		integer (kind=2), parameter :: pur_0 = -32767
		real(r4), parameter :: af_min = 5.0e-9_r4
		
		character*20, save :: version_string = 'beta - initial      '

		real(r4), parameter :: c9999 = 9999.0_r4
		real(r4), parameter :: c_5 = 0.5_r4
		real(r4), parameter :: cn_5 = -0.5_r4      
		real(r4), parameter :: c_1 = 0.1_r4
		real(r4), parameter :: c_01 = 0.01_r4
		real(r4), parameter :: c_001 = 0.001_r4
		real(r4), parameter :: c1_5 = 3.0_r4/2.0_r4
		real(r4), parameter :: c_333 = 2.0_r4/3.0_r4
		real(r4), parameter :: c_111 = 1.0_r4/9.0_r4
    real(r4), parameter :: c_1e3 = 1.0e-3_r4       
    real(r4), parameter :: c_1e6 = 1.0e-6_r4       

		real(r4), parameter :: d0_ = 0.0_r4
		real(r4), parameter :: c0 = 0.0_r4
    real(r4), parameter :: c1 = 1.0_r4    
    real(r4), parameter :: c2 = 2.0_r4   
    real(r4), parameter :: c3 = 3.0_r4           
    real(r4), parameter :: c4 = 4.0_r4       
    real(r4), parameter :: c5 = 5.0_r4       
    real(r4), parameter :: c6 = 6.0_r4       
    real(r4), parameter :: c7 = 7.0_r4       
    real(r4), parameter :: c8 = 8.0_r4       
    real(r4), parameter :: c9 = 9.0_r4       
    real(r4), parameter :: c10 = 10.0_r4       
    real(r4), parameter :: c100 = 100.0_r4       
    real(r4), parameter :: c1000 = 1000.0_r4       
    real(r4), parameter :: c1e3 = 1.e3_r4       
    real(r4), parameter :: c1e5 = 1.e5_r4       
    real(r4), parameter :: c1e6 = 1.e6_r4       

    real(r4), parameter :: nc1 = -1.0_r4    
			
end module siesta_constants


