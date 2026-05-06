list of shit for new ice heat flux

call siesta_env_atmo

call siesta_conductivity
	
	<setup newton-raphson iteration>

	call siesta_heat_solver
	
	<check/repeat>
	
<update boundary fluxes/ice grwowth rates>

<update ice state>

<find ice boundary adjustments for grid changes>

call siesta_boundaries
		r_depth = r_depth + f_depth
<make sure we are not growing too large/small h_min/h_max, deal with loss of biomass. ice etc>

call siesta_new_grid (for ice)

call siesta_regrid_ice

<deal with skeletal shit>

call siesta_regrid_snow
