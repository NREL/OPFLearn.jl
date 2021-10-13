# Formulations of relaxed AC-OPF based on PowerModels.jl

"""
InfrastructureModels build function to formulate AC OPF with variable loads
"""
function build_opf_var_load(pm)
    PM.variable_bus_voltage(pm)
    PM.variable_gen_power(pm)
    PM.variable_branch_power(pm)
    PM.variable_dcline_power(pm)
	variable_load(pm)
	
    PM.constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        PM.constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_var_loads(pm, i)
    end

    for i in ids(pm, :branch)
        PM.constraint_ohms_yt_from(pm, i)
        PM.constraint_ohms_yt_to(pm, i)

        PM.constraint_voltage_angle_difference(pm, i)

        PM.constraint_thermal_limit_from(pm, i)
        PM.constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        PM.constraint_dcline_power_losses(pm, i)
    end
end


"""
InfrastructureModels build function to formulate AC OPF with variable loads constrained
by the minimum powerfactor, and minimum and maximum real power if given in the 
PowerModels network data dictionary used to create the PowerModels model. 
"""
function build_opf_constr_load(pm)
    PM.variable_bus_voltage(pm)
    PM.variable_gen_power(pm)
    PM.variable_branch_power(pm)
    PM.variable_dcline_power(pm)
	variable_load(pm)
	constraint_load(pm)
	
    PM.constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        PM.constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance_var_loads(pm, i)
    end

    for i in ids(pm, :branch)
        PM.constraint_ohms_yt_from(pm, i)
        PM.constraint_ohms_yt_to(pm, i)

        PM.constraint_voltage_angle_difference(pm, i)

        PM.constraint_thermal_limit_from(pm, i)
        PM.constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        PM.constraint_dcline_power_losses(pm, i)
    end
end


""" 
Add variables for the active and reactive components of loads in the network to 
the given PowerModels model
"""
function variable_load(pm)
	model = pm.model
	
	bus_loads = ref(pm, :bus_loads)
	num_loads = length(PM.ref(pm, :load))
	
	Pd = JuMP.@variable(model, pd[1:num_loads], container=DenseAxisArray)
	Qd = JuMP.@variable(model, qd[1:num_loads], container=DenseAxisArray)
	pm.var[:it][:pm][:nw][0][:pd] = Pd
	pm.var[:it][:pm][:nw][0][:qd] = Qd
end


""" 
Constrains the load variables in a PowerModels AC OPF formulation model. 
Constrains the reactive power with the given minimum power factor, pf_min,
maximum active power, pd_max, and minimum active power, pd_min. These constraints 
are pulled from the PowerModels network data dictionary used to create the 
PowerModels network model if the dictionary has these constraint keys (These keys 
are to be added to the dictionary after loading it in using PowerModels). 
Additionally, the power factor is constrained to lagging values by default but 
can be specified to include leading values by including the constraint option 
pf_lagging => false.
"""
function constraint_load(pm; nw::Int=NW_DEFAULT, pd_min=nothing)
	model = pm.model
	load_ids = ids(pm, :load)  # Load indeces, 1 to num_loads
	num_loads = length(load_ids)
	
	if haskey(pm.data, "pd_max")
		pd_max = pm.data["pd_max"]  # Pre-calculated & stored max active powers
		@assert length(pd_max) == num_loads
	else
		pd_max = nothing
	end
	
	if haskey(pm.data, "pd_min")
		pd_min = pm.data["pd_min"]  # Specified min active powers
		@assert length(pd_min) == num_loads
	else
		pd_min = nothing
	end
	
	if haskey(pm.data, "pf_min")
		pf_min = pm.data["pf_min"]  # Selected minimum power factor
		@assert ((length(pf_min) == num_loads) | (length(pf_min) == 1))
	else
		pf_min = nothing
	end
	
	if haskey(pm.data, "pf_lagging")
		pf_lagging = pm.data["pf_lagging"]  # Contrain load pf to lagging or allow leading
	else
		pf_lagging = true
	end
	

	
	pd = get(PM.var(pm, nw), :pd, Dict())
	qd = get(PM.var(pm, nw), :qd, Dict())
	
	# Load Bus Constraints
	for load in load_ids  #TASK: Determine how load variables align with bus order
		if !isnothing(pd_min)
			JuMP.set_lower_bound(pd[load], pd_min[load])
		else
			JuMP.set_lower_bound(pd[load], 0)
		end
		if !isnothing(pd_max)  # Contrain max real load if data is available
			JuMP.set_upper_bound(pd[load], pd_max[load])
		end
	end
	
	# Reactive load powers contrained to a ratio of Real load power if pf_min is not nothing
	if !isnothing(pf_min)
		for load_idx in load_ids
			d = tan(acos(pf_min[load_idx]))
			JuMP.@constraint(model, qd[load_idx] <= (pd[load_idx] * d)) 
			if pf_lagging
				JuMP.@constraint(model, qd[load_idx] >= 0) 
			else
				JuMP.@constraint(model, qd[load_idx] >= (pd[load_idx] * -d)) 
			end
		end
	end
end


"""
Adds the AC OPF power balance constraint to the formulation of a PowerModels model with variable loads. 
Modified from the PowerModels function 'constraint_power_balance' which can be found here,
https://github.com/lanl-ansi/PowerModels.jl/blob/460b310288787d4196f9e50b1a81127ee4677a97/src/core/constraint_template.jl#L174-L191

Copyright (c) 2016, Los Alamos National Security, LLC All rights reserved. Copyright 2016. Los Alamos National Security, LLC.
"""
function constraint_power_balance_var_loads(pm::PM.AbstractPowerModel, i::Int; nw::Int=NW_DEFAULT)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
	
	# PowerModels gathers float values for loads in the system
    #bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    #bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)
	
	# Replace with load variables
	pd = get(PM.var(pm, nw), :pd, Dict())
	qd = get(PM.var(pm, nw), :qd, Dict())
	
	bus_pd = Dict(k => pd[k] for k in bus_loads)
    bus_qd = Dict(k => qd[k] for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    PM.constraint_power_balance(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end


""" 
Determines the maximum servable active load for each load bus with the given system information.
Formulates the problem in JuMP to maximize the load at each load bus individually using 
the given solver.

min_load: The minimum active load constraint as a percentage of the nominal load. Given as either 
		  a single number or a list of number of length num_loads
print_level: An integer from 0-2 that determines how much information is printed to console.
"""
function find_max_loads(pm; print_level=0, nw=NW_DEFAULT, min_load=0.0,
				     solver=optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	model = pm.model
	
	JuMP.set_optimizer(model, solver)
	if print_level < 2
		JuMP.set_silent(pm.model)
	end
	
	
	pd = get(PM.var(pm, nw), :pd, Dict())
	qd = get(PM.var(pm, nw), :qd, Dict())
	loads = ref(pm, :load)
	num_loads = length(PM.ref(pm, :load))
	num_buses = length(ref(pm, :bus))
	
	# Constrain the load pf and pd max/min
	nominal_load = pm.data["base_load"]
	min_load isa Number && (min_load = ones(num_loads) .* min_load)
	pd_min = min_load .* nominal_load[1:num_loads]
	
	constraint_load(pm, pd_min=pd_min)
	
	solved_statuses = []
	pd_max = zeros(num_loads, 1)
	for load_idx in sort(collect(keys(loads)))
		# Maximize Load Objective
		JuMP.@objective(model, Max, pd[load_idx]) # Set objective to maximize the load at a load bus
		
		JuMP.optimize!(model)
		load_bus = loads[load_idx]["load_bus"]
		pd_max[load_idx] = JuMP.objective_value(model)
		
		if print_level > 0
			println("")
			println("Load Bus: ", load_bus)
			println(JuMP.solution_summary(model))
		end
		
		# Check if solution was found & no errors occured
		status = JuMP.termination_status(model)
		solved = status in SOLVED_STATUSES
		append!(solved_statuses, solved)
		!solved && @warn "Load $(load) max load solution is $(status)"
	end
	return pd_max, solved_statuses
end


"""
Initializes a PowerModels model, pm, with variable loads, to be used for finding 
the nearest feasible load profile. 
"""
function find_nearest_feasible_model(pm; nw=NW_DEFAULT, print_level=0, 
							       solver=optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	!haskey(pm.data, "pd_max") && (@warn "Max load constraint values not provided.")
	
	model = pm.model
	
	JuMP.set_optimizer(model, solver)
	if print_level < 2
		JuMP.set_silent(pm.model)
	end
	
	constraint_load(pm)
	return pm
end


"""
Finds the nearest feasible load profile to given load profile, with active and reactive loads, px and qx,
for the PowerModels network, pm.
"""
function find_nearest_feasible(pm, px, qx; nw=NW_DEFAULT, print_level=0)
	model = pm.model 
	num_loads = length(PM.ref(pm, :load))
	
	# Objective, RMS of distance between sample load points in Px & Qx and potentail feasible loads Pd and Qd
	#quad_form(Pd - Px, eye(numbus))+ quad_form(Qd - Qx, eye(numbus)
	pd = get(PM.var(pm, nw), :pd, Dict())
	qd = get(PM.var(pm, nw), :qd, Dict())
	
	JuMP.unregister(model, :R)
	
	JuMP.@expression(model, R, sum((pd[i] - px[i])^2 + (qd[i] - qx[i])^2 for i in 1:num_loads))
	JuMP.@objective(model, MOI.FEASIBILITY_SENSE, 0)  # Set sense to delete the bridge, Needed for SCS & Hypatia
	JuMP.@objective(model, Min, R)  # Add the new objective
	
	JuMP.optimize!(model)
	
	r = JuMP.objective_value(model)

	PD_vals = JuMP.value.(model[:pd]).data
	QD_vals = JuMP.value.(model[:qd]).data

	if print_level > 1
		println(JuMP.solution_summary(model))
	end
	
	# Check if solution was found & no errors occured
	status = JuMP.termination_status(model)
	solved = status in SOLVED_STATUSES
	!solved && @warn "Nearest feasible load solution is $(status)"
	
	return r, PD_vals, QD_vals, solved
end
