# Stores AC OPF Samples and statistics in result objects

"Stores AC OPF input data in a dictionary with keys of the desired input_vars"
function ACInputs(input_vars, n_loads)
	element_sizes = Dict([(:n_loads, n_loads)])
	
	AC_inputs = Dict()
	for variable in input_vars
		AC_inputs[variable] = Array{Float64}(undef, 0, sum([element_sizes[x] for x in VAR_SIZES[variable]]))
	end
	return AC_inputs
end


"Stores AC OPF output data in a dictionary with keys of the desired output_vars"
function ACOutputs(output_vars, n_buses, n_gens, n_ext, n_branches)
	element_sizes = Dict([(:n_buses, n_buses),
						 (:n_gens, n_gens),
						 (:n_ext, n_ext),
						 (:n_branches, n_branches),
						 (:n_nets, 1),  # TODO: This would need to change if using multinetwork models?
						])
	
	AC_outputs= Dict()
	for variable in output_vars
		AC_outputs[variable] = Array{Float64}(undef, 0, sum([element_sizes[x] for x in VAR_SIZES[variable]]))
	end
	return AC_outputs
end


"Stores the duals of the specified variables for each AC OPF sample"
function Duals(dual_vars, n_buses, n_gens, n_ext, n_branches)
	element_sizes = Dict([(:n_buses, n_buses),
					 (:n_gens, n_gens),
					 (:n_ext, n_ext),
					 (:n_branches, n_branches)
					])
	
    duals = Dict((
        ("k", 0),
        ("unique_active_sets", Set()),
		("variances", Dict())
		))
	for variable in dual_vars
		duals[variable] = Array{Float64}(undef, 0, sum([element_sizes[x] for x in VAR_SIZES[variable]]))
	end

	return duals
end


"Creates a dictionary of initialized results objects for storing sample data"
function initialize_results(input_vars, output_vars, dual_vars, net_info, 
						    save_certs, save_infeasible, stat_track)
	num_branches = net_info["num_branches"]
	num_buses = net_info["num_buses"]
	num_ext = net_info["num_ext"]
	num_gens = net_info["num_gens"]
	num_loads = net_info["num_loads"]
	
	AC_inputs = ACInputs(input_vars, num_loads)
    AC_outputs = ACOutputs(output_vars, num_buses, num_gens, num_ext, num_branches)
    duals = Duals(dual_vars, num_buses, num_gens, num_ext, num_branches)
	
	# Construct results object
	results = Dict{String, Any}([("inputs", AC_inputs),
								("outputs", AC_outputs),
								("duals", duals),
								])
	save_certs && (results["polytope"] = Dict())			
	if save_infeasible
		infeasible_AC_inputs = ACInputs(input_vars, num_loads)
		results["infeasible_inputs"] = infeasible_AC_inputs
	end
	if stat_track > 0
		stats = create_stats_dict(stat_track)
		results["stats"] = stats
	end
	
	return results
end


""" 
Adds the given values of the new values dictionary to the container values
of dict. Only adds values for keys that already exist in the dict.
"""
function add_sample(dict, new_values)
	for key in keys(dict)
		if dict[key] isa Array
			dict[key] = vcat(dict[key], new_values[key])
		elseif dict[key] isa Set
			push!(dict[key], new_values[key])
		end
	end
end


"Returns a list of bools indicating which values are greater than eps"
function gt_eps(l, eps_val=EPS)  # Determine what value to use for eps?
    l = abs.(l)
    return [x > eps_val for x in l]
end


""" 
Checks if the given sample should be stored and gathers stat tracking info
Calls a helper function to store the given samlpe if it should be stored.
"""
function store_feasible_sample(s, u, v, k, i, K, iter_stats, AC_inputs, AC_outputs, duals, dual_vars,
							   x, result, discard, variance, net_name, now_str, save_path, save_all,
							   save_order, print_level)
	s = s + 1
	u = u + 1
	v = v + 1
	
	set, new_set, added, var_inc = store_feasible_sample(AC_inputs, AC_outputs, duals, dual_vars,
										   x, result, discard, variance)
	
	# Update iteration stats dict
	iter_stats[:feasible] = true
	iter_stats[:new_set] = new_set
	iter_stats[:added] = added
	iter_stats[:var_inc] = var_inc
	iter_stats[:active_set] = set
	
	if added
		k = k + 1
		if print_level > 0
			println("Samples: $(k) / $(K),\t Iter: $(i)")
		elseif ((k % (K / 10)) == 0)
			println("Samples: $(k) / $(K),\t Iter: $(i)")
		end
		
		s = 0  # Reset count since last sample added
		
		if var_inc
			v = 0  # Reset count since last variance increase
		elseif print_level > 0
			println("Samples since last variance increase:", v)
		end
		
		if new_set
			if print_level > 0
				println("New set found!")
			end
			u = 0  # Reset count since last unique set added
		elseif print_level > 0
			println("Samples since last new set found:", u)
		end 
	elseif print_level > 0
		println("Samples: $(k) / $(K),\t Iter: $(i)")
		println("Samples since last sample added:", s)
		println("Samples since last variance increase:", v)
		println("Samples since last new set found:", u)
	end
	
	save_all && save_sample_csv(x, result, net_name*"_"*now_str,
							    save_order, dual_vars, dir=save_path)	
	
	return s, u, v, k, iter_stats
end


""" 
Checks if the given sample should be stored and stores the given sample to the results object.
Returns stat tracking information.
"""
function store_feasible_sample(AC_inputs, AC_outputs, duals, dual_vars, x, results, discard, variance, keep_samples=true)
	# Gen. & Ext. and Dual Results
	primal_vals, dual_vals = results

    # Load results
	new_AC_inputs = extract_load(x)
	
    # Duals results
	dual_vals["unique_active_sets"] = extract_active_set(dual_vals, dual_vars)
	
	set = dual_vals["unique_active_sets"]
	new_set = !(set in duals["unique_active_sets"])
	#TASK: Fix turning off saving results in variables not allowing new sets to be tracked
	
	# Updating variances & adding sample
	if new_set
		#Create new variance object
		if variance
		duals["variances"][set] = create_variance_dict([new_AC_inputs, primal_vals], STAT_ORDER)
		update_variances(duals["variances"][set], [new_AC_inputs, primal_vals], STAT_ORDER)
		end
		var_inc = true
	else # Check variance and add if increased
		if variance
			# If variance not increased don't add
			var_inc = dim_variance_increases(duals["variances"][set], [new_AC_inputs, primal_vals], STAT_ORDER)
			if discard
				if  !var_inc
					added = false
					return set, new_set, added, var_inc
				end
			end
			update_variances(duals["variances"][set], [new_AC_inputs, primal_vals], STAT_ORDER)
		else
			var_inc = true  # Return true when not tracking
		end
	end
	
	if keep_samples 
    add_sample(AC_inputs, new_AC_inputs)
	add_sample(AC_outputs, primal_vals)
    add_sample(duals, dual_vals)
	end
	added = true
	
	return set, new_set, added, var_inc
end


"Saves infeasible sample results"
function store_infeasible_sample(infeasible_AC_inputs, x, result, save_all, 
								 net_name, now_str, save_order, dual_vars, save_path)
	# Load results
	new_AC_inputs = extract_load(x)
    add_sample(infeasible_AC_inputs, new_AC_inputs)
	
	save_all && save_sample_csv(x, result, "INFEASIBLE_"*net_name*"_"*now_str,
							    save_order, dual_vars, dir=save_path)	
end


"Takes a load vector, x, and puts the active and reactive load values into a new input object"
function extract_load(x)
    num_loads = Int(length(x) / 2)
    pd = x[1:num_loads]'
    qd = x[num_loads + 1:end]'

	new_AC_inputs = Dict((
					("pd", pd),
					("qd", qd)
					))
	return new_AC_inputs
end


"Finds the set of active constraints for a given samples dual values"
function extract_active_set(dual_vals, dual_vars)
	active_set = Array{Float64}(undef, 1, 0)
	for variable in dual_vars
		active_set = hcat(active_set, gt_eps(dual_vals[variable]))
	end
	return active_set
end


"Creates a dictionary of variance tracking objects for each dimension of the given variable keys"
function create_variance_dict(dicts, keys_)
	var_dict = Dict()
	for dict in dicts
		variables = intersect(keys(dict), keys_)
		for variable in variables 
			var_dict[variable] = CovMatrix()
		end
	end
	return var_dict
end


" Adds the given values from the new_value_dicts to the variance objects in the dict vars"
function update_variances(var_dicts, new_values_dicts, keys_)
	for dict in new_values_dicts
		variables = intersect(keys(dict), keys_)
		for variable in variables
			fit!(var_dicts[variable], dict[variable][:])
		end
	end
end


""" 
Returns if adding the new value to any of the variables' dimensions increases its variance
by more than the given tol amount
"""
function dim_variance_increases(var_dicts, new_values_dicts, keys_; tol=1e-1, min_n=2)
	for dict in new_values_dicts
		variables = intersect(keys(dict), keys_)
		for variable in variables
			
			# Always add a second value to the covariance matrix
			if var_dicts[variable].n < min_n 
				return true
			end
			
			updated_vars = deepcopy(var_dicts[variable])
			fit!(updated_vars, dict[variable][:])
			if sum(diag(OnlineStatsBase.value(updated_vars)) .> (diag(OnlineStatsBase.value(var_dicts[variable])) .+ tol .+ eps())) > 0
				return true
			end
		end
	end
	return false
end


"Creates a dictionary with stat keys and empty arrays to append iteration stats to"
function create_stats_dict(stat_level)
	stats = Dict(
				:var_inc 			=> [],
				:new_set 			=> [],
				:new_cert			=> [],
				:feasible			=> [],
				:added 				=> [],
				:iter_time			=> [],
				)
	stat_level > 1 && (stats[:active_set] = [])
	stat_level > 2 && (stats[:variances] = [])
	return stats
end


""" 
Updates the given stats object to contain the duals and iter_stats information for an iteration
The given stat_level determines how much information is tracked and stored for each new sample.

...
# Arguments
- 'save_level::Integer': how much statistical information is saved each iteration,
	Level 1: If a new sample was added, if it was a new unique active set, & if the variance increased
	Level 2: All above and unique active sets
	Level 3: All above and covariance matrix for all variables
...
"""
function update_stats!(stats, duals, iter_stats; keys_=STAT_ORDER, save_level=2::Integer)	
	if save_level >= 1
	# Update from iter stats dict 
	# variance increase, new set, added, and feasible
	for (s, new_stat) in iter_stats
		if s != :active_set
		push!(stats[s], new_stat)
		end
	end
	end
	
	if save_level >= 2
	# Update unique active sets
	push!(stats[:active_set], iter_stats[:active_set])
	end
	
	if save_level >= 3
	# Update variances
	for set in duals["unique_active_sets"]
		new_set = !(set in keys(stats[:variances]))
		if new_set
			stats[:variances][set] = Dict()
		end
		for variable in keys_
			iter_variances = diag(OnlineStatsBase.value(duals["variances"][set][variable]))'
			if new_set
				stats[:variances][set][variable] = -ones(length(stats[:unique_active_sets]) - 1, 
														 length(iter_variances))
			end
			stats[:variances][set][variable] = vcat(stats[:variances][set][variable], iter_variances)
		end
	end
	end
end


function store_cert(results, A, b)
	results["polytope"]["A"] = A
	results["polytope"]["b"] = b
end


function results_to_array(results; save_order=DEFAULT_SAVE_ORDER, header=true, imag_j=false)
	AC_inputs = results["inputs"]
	AC_outputs = results["outputs"]
	duals = results["duals"]
	return results_to_array(AC_inputs, AC_outputs, duals, save_order=save_order, 
							header=header, imag_j=imag_j)
end


""" 
Takes the results objects from a create samples run and converts them to a single array.
Requires the save\\_order, an array of variables, to save from the results objects. Takes 
optional boolean arguments header, whether to include a header as the first row, and 
imag\\_j, whether to convert complex data values to strings and replace 'im' with 'j' for
datasets that are to be used outside of the Julia environment.
"""
function results_to_array(AC_inputs, AC_outputs, duals; 
					      save_order=DEFAULT_SAVE_ORDER, header=true, imag_j=false)
	all_data = merge(AC_inputs, AC_outputs, duals)
	
	num_samples = size(collect(values(AC_inputs))[1],1)
	data = Array{Number}(undef, num_samples, 0)
	#all_data[save_order[1]]
	for key in save_order
		if haskey(all_data, key)
			var_data = all_data[key]
			iscomplex = typeof(var_data[1]) == Complex{Float64}
			if iscomplex & imag_j
				var_data = string.(var_data)
				var_data = chop.(var_data, tail=2) .* "j"
			end
			data = hcat(data, var_data) #string.(all_data[key])
		end
	end
	
	if header
		header = build_header(AC_inputs, AC_outputs, duals, save_order)
		data = vcat(header, data)
	end
	return data
end
