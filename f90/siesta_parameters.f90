! ======================================================================
! Global Parameters
! ======================================================================

module siesta_parameters

	use kei_kinds, only: i4, r4, r8, log_kind
	! Other SIESTA sea-ice tunables (save): defined in kei_icecommon, re-exported here.
	use kei_icecommon, only: &
		icecon_mod, grid_model, &
		ksnow, den_s_dry, den_s_wet, den_s_switch, bb_f, eps0_s, eps0_i, eps_snow, eps_ice, &
		atan_max, atan_c_i, chw, mu_w_min, Fm_a_switch, mean_floe_diameter, alpha_lateral_melt, melt_f_denom, &
		desal, bv_conv, f_sk, fb, fi, vb_crit, conv_max, dbvdt_scale, &
		alb_s_dry, alb_s_wet, alb_i_dry, alb_i_wet, h_snowpatch, par_to_swd, a_ice_ir, par_cf, &
		iit, iis, iin, iif, s_const, n_f, &
		ts_is_at, kevin_light, use_pl, ncep_f, pr_on, use_mdiff, no_flooding, flood_brine, woa_depth, &
		max_it, snow_ridging, snow_in_gaps, &
		min_sal, nr_tol, gl_max_f, fl_max_f, T_ref, temp_tol, fl_crit, fl_ratio, da_f, snow_min, &
		gc_offset, snow_fudge, a_factor, p_factor, snow_rd_lim, cv_void_f, cvf_switch, cvf_thin, &
		ohf_skew, at_skew, snow_skew
	
	implicit none

	public


	! ------------------------------------------------------------
	! run options
	! ------------------------------------------------------------
	integer(i4), parameter :: &
		rstart 				=	0	    ,	&	!	1) use retart files to resume simulation 2) start new simulation	
		adv_on 				=	1	    ,	&	!	advect ice according to ice motion product	
		use_gpu  			=	1	    ,	&	!	perform delta-eddington light calculations using GPU card	
		stn_only 			=	0	    ,	&	!	only compute stations, ignoring model domain (mdh1,mdv1, etc.) below	
		atm_f 				=	2	    ,	&	!	atmospheric forcing source (0=NCEP,1=ECMWF)	
		atmo 					=	1	    ,	&	!	atmospheric boundary calculation type (1-CICE 0=muntersteiner old/kottmeier 2003)	
		woa 					=	1	    ,	&	!	toggle for use of specified forcing (0) or world ocean atlas forcing (1)	
		ohf 					=	2	    ,	&	!	ocean heat flux is specified (0) or derived from world ocean atlas (1) or generated from internal climatology (2)	
		validation 		=	0	    ,	&	!	toggle for modeling of (1) validation station, (0) or specified model domain	
		monte_carlo 	=	0	    ,	&	!	toggle for running purmutations of validation based on modified snowfall,temperature	
		override_ic 	=	0	    ,	&	!	override the built-in dependence on satellite ice conectration, assuming ice the whole run	
		use_ponds 		=	1	    ,	&	!	1=don't disappear surface melted ice, 0=melted ice/snow dissappears	
		use_drain 		=	1	    ,	&	!	1=drain surface ice if above bv_conv and turn into snow, 0=don't	
		mdh1 					=	202	  , & !	model domain - horizontal upper left (RossSeaBox = 372/744, Full = 202/404)  400  300	
		mdv1 					=	194	  , & !	model domain - vertical upper left (RossSeaBox = 424/848, Full = 194/388)  260 280	
		mdh2 					=	517	  , & !	model domain - horizontal lower right (RossSeaBox = 374/748, Full = 517/1035)	
		mdv2 					=	525	   	  !	model domain - vertical lower right (RossSeaBox = 426/752, Full = 525/1051)	

	! ------------------------------------------------------------
	! start and end timing
	! ------------------------------------------------------------
	real(r4), parameter :: &
		begin_j_day 	=	71	    ,        & !	start date (decimal julian day)	
		begin_year 		=	1997	    ,        & !	start year	
		end_j_day 		=	182	    ,        & !	end date (decimal julian day)	
		end_year 			=	1998	             !	end year	

	! ------------------------------------------------------------
	! output options
	! ------------------------------------------------------------
	integer(i4), parameter :: &
		write_f 			=	24	    ,        & !	write frequency (hours)	
		write_disk 		=	1	    ,        & !	actually write to disk - may not want to if debugging (1=yes, 0=no)	
		wr_stations 	=	0	             !	write out station netcdf files - costly disk access, maybe want to supress	

	! ------------------------------------------------------------
	! grid resolution
	! ------------------------------------------------------------

	integer(i4), parameter :: &
		n_max_floes 					= 40						, & ! maximum number of ice categories
		z_max_ice 						= 42						, & ! maximum ice layers
		z_max_snow						= 26						, & ! maximum snow layers
		z_max_pack 						= z_max_ice + z_max_snow, &
		z_int_min 						=	1	    				, & !	defines minimum number of model layers	
		z_sk 									=	2	    				, & !	number of layers in skeletal layer	
		pl_max 								= 30								! maximum platelet layers

	! ------------------------------------------------------------
	! vertical grid / thickness (m); compile-time constants
	! ------------------------------------------------------------
	real(r4), parameter :: &
		h_max     = 10.0_r4,        &  ! maximum ice thickness (m)
		pl_th     = 0.02_r4,        &  ! platelet layer thickness (m)
		bot_th    = 0.2_r4,         &  ! bottom ice section thickness (m from bottom)
		sk_th_min = 0.001_r4,       &  ! minimum height skeletal layer (m)
		sk_th_max = 0.01_r4,        &  ! maximum height skeletal layer (m)
		z_th_min  = 0.02_r4,        &  ! minimum ice layer height (m)
		z_th_max  = 0.3937376_r4,   &  ! maximum height ice layer (m)
		z_th_fr   = 0.01_r4,        &  ! new consolidated frazil thickness (m)
		z_th_crit = 0.02_r4            ! critical layer height for sub-stepping (m)

	real(r4), parameter :: &
		h_crit = z_th_min * real(z_max_ice - z_sk, r4), & ! height where grid shifts to accordion style
		th_min = z_th_min * real(z_int_min, r4)          ! minimum thickness scale from structural grid

	! ------------------------------------------------------------
	! adjustable parameters
	! ------------------------------------------------------------

		! timing
		real(r4), save :: &
			dt 						=	1	    ,        & !	length of time step (hours)	
			dt_sub_1 			=	0.2	    ,        & !	fraction of main timestep for ice physics - normal is 0.05	
			dt_sub_2 			=	0.05	    ,        & !	fraction of main timestep for fast-changing ice physics - normal is 0.005	
			dt_sub_3 			=	0.05	    ,        & !	fraction of main timestep for very-fast-changing ice physics	
			dt_sub_1_tol 	=	0.5	    ,        & !	minimum temperature tolerance for use of dt_sub_1 (deg C)	
			dt_sub_2_tol 	=	1.3	             !	minimum temperature tolerance for use of dt_sub_2 (dec C)	

		! ocean
		real(r4), save :: &
			Fw 						=	7.0	    ,        & !	Oceanic heat flux from water (W/m^2) (1.195 cal/m^2/sec * 4.1868 W*s/cal = 5 W/m^2 in Arrigo, others?)	
			Sw 						=	34.1	    ,        & !	salinity of seawater (psu) - normal = 34.95 (33.33)	
			Sd 						=	1027693	    ,        & !	density of seawater  (g/m^3)	
			Tw 						=	-1.8	    ,        & !	seawater temperature (degC)	
			sw_NH4 				=	0.	    ,        & !	seawater NH4 concentration, used if climatologies not used (µMolar)	
			sw_NO3 				=	31	    ,        & !	seawater N03 concentration, used if climatologies not used (µMolar)	
			sw_SiO4 			=	80.	    ,        & !	seawater SiO2 concentration, used if climatologies not used (µMolar)	
			sw_PO4 				=	2.1	    ,        & !	seawater PO4 concentration, used if climatologies not used (µMolar)	
			sw_poc 				=	0.	    ,        & !	seawater detritus concentration (g/m^3)	
			alg_wc 				=	35	             !	water column algal concentration - used when freezing/flooding/creating new ice (mgC/m^3)	

		! snow & ice (physical ice/snow tunables: kei_icecommon, re-exported via use-list above)

		integer(i4), parameter :: &
			ic_n 									= 5							, & ! ice thickness categories (between 1 and 10)
			sc_n 									= 2 						, & ! lognormal snow thickness categories (currently, either 1 or 2) 
			la 										= 1 						, & ! lognormal light adjustment categories (between 1 and 9)
			snow_model 		=	1	              !	snow model type	

		! biology
		integer(i4), parameter :: &
			alg_mig 			=	1	             !	algae migration (0=algae stay put verticaly, 1=algae move with their respective layers while ice grows (quasi-movement))
		real(r4), parameter :: &
			Ek_max 				=	18	    ,        & !	Spectral photoaclimation parameter (microEin*m-2*s-1)	
			A 						=	1.4	    ,        & !	parameter of light utilization equation (dimensionless)	
			B 						=	0.12	    ,        & !	parameter of light utilization equation (dimensionless)	
			rg 						=	0.0631	    ,        & !	growth rate constant rg (1/degC) - from Epply et al 1972	
			G0 						=	0.81	    ,        & !	growth rate @ zero dec C (1/day) - from Epply at al 1972	
			xp 						=	0.01	    ,        & !	phytoplankton death/grazing rate (1/day)	
			remin 				=	0.03	    ,        & !	rate of poc/detritus remineralization (1/day)	
			remin_f 			=	1	    ,        & !	fraction poc remineralization to available N,P	
			c_chl 				=	35	    ,        & !	Carbon:Chlorophyl ratio (grams/gram)	
			c_n 					=	7	    ,        & !	Carbon:Nitrogen Ratio (moles/mole)	
			c_si 					=	4	    ,        & !	Carbon:Silicon Ratio (moles/mole)	
			c_p 					=	106	    ,        & !	Carbon:Phosphorus Ratio (moles/mole)	
			Ks_NH4 				=	1	    ,        & !	Half-saturation rate constant (microMolar)	
			Ks_NO3 				=	1	    ,        & !	Half-saturation rate constant (microMolar)	
			Ks_SiO4 			=	60	    ,        & !	Half-saturation rate constant (microMolar)	
			Ks_PO4 				=	0.1	    ,        & !	Half-saturation rate constant (microMolar)	
			alg_dtt 			=	1	    ,        & !	algal model calculation frequency (0=once per time step, 1=same frequency as sub-dt ice physics)	
			alg_mig_crit 	=	1.5	    ,        & !	maximum growth rate under which algae maintain position (cm/day)	
			min_alg 			=	3.5	             !	minimum microalgal concentration (mgC/m^3)	

	! ------------------------------------------------------------
	! tracers
	! ------------------------------------------------------------

		! external/2D tracers
		integer(i4), parameter :: &
			n_2t									= 4  								! number of 2D tracers
		integer(i4), parameter :: &
			age_i									= 1, 							& !	
			ridged_i							= 2, 							& !
			snow_dist_i						= 3, 							& !
			snow_rd_i							= 4                 !

		! internal/3D tracers
		integer(i4), parameter :: &
			n_3t 									= 5  								! number of 3D tracers		
		integer(i4), parameter :: &
			no3_i									= 1, 							& !
			nh4_i									= 2, 							& !
			po4_i									= 3, 							& !
			sio3_i								= 4, 							& !
			det_i									= 5, 							& !
			smalg_i								= 6									! 


	! ------------------------------------------------------------
	! ice fluxes - sign is out of ice
	! ------------------------------------------------------------
		integer(i4), parameter :: &
			n_flx									= 26  						! number of ice fluxes
		integer(i4), parameter :: &
			w_smelt 						= 1, 							& !
			w_bmelt 						= 2, 							& !
			w_bfreeze 					= 3, 							& !
			w_flood 						= 4, 							& !
			w_frfreeze 					= 5, 							& !
			w_latmelt 					= 6, 							& !
			w_latfreeze 				= 7, 							& !
			w_snowmelt 					= 8, 							& !
			w_desal 						= 9, 							& !
			s_smelt 						= 10, 							& !
			s_bmelt 						= 11, 							& !
			s_bfreeze 					= 12, 							& !
			s_flood 						= 13, 							& !
			s_frfreeze 					= 14, 							& !
			s_latmelt 					= 15, 							& !
			s_latfreeze 				= 16, 							& !
			s_desal 						= 17, 							& !
			q_ssmelt 						= 18, 							& !
    	q_mlmelt 						= 19, 							& !
    	q_bcon 							= 20, 							& !
    	q_latmelt 					= 21,	 							& !
    	q_totalfreeze 			= 22,	 							& !
    	q_totalmelt 				= 23,	 							& !
    	v_frazil      			= 24,	 							& !
    	v_congelation 			= 25,	 							& !
    	v_snowice     			= 26	 							  !


	! ------------------------------------------------------------
	! ice thickness change tracking variables
	! ------------------------------------------------------------
		integer(i4), parameter :: &
			n_dh									= 17  						! number of ice thickness changes
		integer(i4), parameter :: &
			sn_precip 					= 1, 							& !
			sn_melt 						= 2, 							& !
			sn_subl 						= 3, 							& !
			sn_flood						= 4,							&	!
			ice_b_melt_ml 			= 5, 							& !
			ice_b_melt_con 			= 6, 							& !
			ice_b_grow_ml 			= 7, 							& !
			ice_b_grow_con 			= 8, 							& !
			ice_s_melt 					= 9, 							& !
			ice_s_subl 					= 10, 							& !
			ice_s_flood 				= 11, 							& !
			ice_s_drain 				= 12, 							& !
			ice_s_melt_flood 		= 13, 							& !
			ice_b_dhdt 					= 14, 							&	!
			ice_b_sal 					= 15,								&	!
			ice_s_sal 					= 16,								&	!
			sn_rain   					= 17 									!
		
	! ------------------------------------------------------------
	! input data grid indexes
	! ------------------------------------------------------------          
	integer(i4), parameter :: &
			mp_x									= 192						, & ! NCEP/DOE II x bound
			mp_y									= 94						, & ! NCEP/DOE II y bound
			ec_x									= 144						, & ! ECMWF 40-yr Reanalysis x bound
			ec_y									= 73						, & ! ECMWF 40-yr Reanalysis y bound
			eci_x									= 240						, & ! ECMWF Interim Reanalysis x bound
			eci_y									= 121						, & ! ECMWF Interim Reanalysis y bound
			dg_x									= 360						, & ! 1 degree grid x bound
			dg_y									= 180						, & ! 1 degree grid y bound
			wavl									= 31						, & ! number of shortwave irradiance bins
			logn_n 								= 9							    ! lognormal distribution bins - not sure if this is used?

		! ------------------------------------------------------------
		! model domain grid indexes based on southern hemisphere EASE grid
		! ------------------------------------------------------------          
		integer(i4), parameter :: &
			grid_v								= 721						, & !
			grid_h								= 721						, & !
			h1_ncep_i							= 202						, & !
			h2_ncep_i							= 518						, & !
			v1_ncep_i							= 194						, & !
			v2_ncep_i							= 526						  !

		! ------------------------------------------------------------
		! Enumerations
		! ------------------------------------------------------------
		integer(i4), parameter :: &
			ncep_at								= 1					, & !
			ncep_p 								= 2					, & !
			ncep_h 								= 3					, & !
			ncep_fc								= 4					, & !
			ncep_u10							= 5					, & !
			ncep_v10							= 6					, & !
			ncep_pr								= 7							!
		integer(i4), parameter :: &
			woa_t									= 1					, & !
			woa_s									= 2					, & !
			woa_n									= 3					, & !
			woa_p									= 4					, & !
			woa_si								= 5						  !

		! ------------------------------------------------------------
		! All kinds of parameters
		! ------------------------------------------------------------
    real(r4), parameter :: &
    	ki_min 								= 0.563_r4			, & !  minimum sea ice thermal conductivity (W/m/K)
			pond_f_perc 					= 0.3e0_r4	    , & ! fraction of ponded/melt water that pushed down through brine network
			af_min 								= 5.0e-9_r4     , & ! minimum areal fraction of ice in a grid cell
      Ce 										= 2.1e-3_r4      , & ! coefficient of turbulent latent heat transfer (water vapor?)
      Ch 										= 2.0e-3_r4      , & ! coefficient of turbulent sensible heat transfer
      cp 										= 1005.0_r4       ! J/kg/K 

		! ------------------------------------------------------------
		! Model globals/parameters assigned during run or from
		! constant.txt run file
		! ------------------------------------------------------------
	
		real(r4), allocatable :: &
				ida_multiplier(:),        &	!
				lda_multiplier(:),        &	!
				sda_multiplier(:)	        	!
		logical(kind=log_kind), save :: &
				leap_year,       					&	!
				start,      							&	!
				do_write,       					&	!
				z_odd												!
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

		integer(i4), save :: &
			steps, last_day, last_hour, last_year, icevec_index,skdump, &
			dtt_1,dtt_2,dtt_3,n_dtt_1,n_dtt_2,n_dtt_3,snow_loaded, &
			mdh, mdv, last6hour,last12hour,n_stations,snowd_index, &
			hour24,tcells,sda_n, last3hour,ida_norm_n,lda_n,lda_norm_n, &
			f_index,f_index_next,i_temp,pur_clock,icecon_index

		real(r4), save :: &
			pur_stepper,sk_h,bt_h,next_write_hour,aph_max,dt_s, &
			b_flux_max_tot,dt_years,dt_days, &
			dtt_s_1,dtt_s_2,dtt_s_3,cur_month,ida_d,lda_d,ad_denom, &
			total_flooded,a_ice_ir_cos
			
end module siesta_parameters
	