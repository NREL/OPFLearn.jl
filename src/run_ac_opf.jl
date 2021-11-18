"""
Given a PowerModels data dictionary, following the InfrastructureModels 
multi-infrastructure conventions, use PowerModels.jl to solve the 
AC OPF problem and return the primal and dual variable values, and 
whether the AC OPF solver converged to an Optimal solution.
"""	
function run_ac_opf(network_data::Dict; print_level=0, from_py=false, 
				    solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	if from_py
		network_data = fix_network_data_dict(network_data)
	end
	
	pm = PM.instantiate_model(network_data, PM.ACPPowerModel, PM.build_opf)
	JuMP.set_optimizer(pm.model, solver)
	if print_level < 2
		JuMP.set_silent(pm.model)
	end
	results = PM.optimize_model!(pm)
	
	# Extracting Results
	bus_ids = sort(collect(ids(pm, :bus)))
	bus_ids_str = string.(bus_ids)
	bus_nums = collect(1:length(bus_ids))
	bus_num_ref = Dict(zip(bus_ids_str, bus_nums))
	
	num_buses = length(bus_ids)
	
	net_gen = network_data["gen"]
	gen_buses = sort([gen["gen_bus"] for gen in values(net_gen)])
	gen_bus_nums = [bus_num_ref[bus_idx] for bus_idx in string.(gen_buses)]
	num_gens = length(net_gen)
	
	not_slack(i) = net_bus[string(net_gen[i]["gen_bus"])]["bus_type"] != 3 # bus_type 3: Slack bus # UNUSED
	get_index(i) = net_gen[i]["index"] # UNUSED
	
	# Gather primal values
	primals = Dict()
	vm = zeros(num_buses)
	va = zeros(num_buses)
	res_bus = results["solution"]["bus"]
	for bus_idx in bus_ids_str
		bus_num = bus_num_ref[bus_idx]
		vm[bus_num] = res_bus[bus_idx]["vm"]
		va[bus_num] = res_bus[bus_idx]["va"]
	end
	v = vm.*exp.(1im*deg2rad.(va))
	vmg = vm[gen_bus_nums]
	
	primals["vm_bus"] = Array(vm')
	primals["va_bus"] = Array(va')
	primals["vm_gen"] = Array(vmg')
	primals["v_bus"] = Array(transpose(v))

	pg = zeros(num_gens)
	qg = zeros(num_gens)
	res_gen = results["solution"]["gen"]
	for gen_idx in keys(res_gen)
		gen_num = net_gen[gen_idx]["index"]
		pg[gen_num] = res_gen[gen_idx]["pg"]
		qg[gen_num] = res_gen[gen_idx]["qg"]
	end
	
	primals["p_gen"] = Array(pg')
	primals["q_gen"] = Array(qg')
	
	net_branch = network_data["branch"]
	num_branches = length(net_branch)
	p_to = zeros(num_branches)
	q_to = zeros(num_branches)
	p_fr = zeros(num_branches)
	q_fr = zeros(num_branches)
	res_branch = results["solution"]["branch"]
	for (idx, branch) in res_branch
		index = network_data["branch"][idx]["index"]
		p_to[index] = branch["pt"]
		q_to[index] = branch["qt"]
		p_fr[index] = branch["pf"]
		q_fr[index] = branch["qf"]
	end
	
	primals["p_fr"] = Array(p_fr')
	primals["p_to"] = Array(p_to')
	primals["q_fr"] = Array(q_fr')
	primals["q_to"] = Array(q_to')
	primals["total_cost"] = Array([results["objective"]])
	
	if print_level > 1
		println(string("OPF: ",results["termination_status"]))
	end
	converged = results["termination_status"] in SOLVED_STATUSES
	
	# Gather dual values
	vm = var(pm, :vm)
	pg = var(pm, :pg)
	qg = var(pm, :qg)
	p = var(pm, :p)
	q = var(pm, :q)
	
	#TASK: Determine if I need to sort these voltage values?
	v_min = [JuMP.dual(JuMP.LowerBoundRef(vm[i])) for i in bus_ids]
	v_max = [JuMP.dual(JuMP.UpperBoundRef(vm[i])) for i in bus_ids]
	
	pg_min = zeros(num_gens)
	pg_max = zeros(num_gens)
	qg_min = zeros(num_gens)
	qg_max = zeros(num_gens)
	for gen in values(net_gen)
		gen_idx = gen["index"]
		pg_min[gen_idx] = JuMP.dual(JuMP.LowerBoundRef(pg[gen_idx]))
		pg_max[gen_idx] = JuMP.dual(JuMP.UpperBoundRef(pg[gen_idx]))
		qg_min[gen_idx] = JuMP.dual(JuMP.LowerBoundRef(qg[gen_idx]))
		qg_max[gen_idx] = JuMP.dual(JuMP.UpperBoundRef(qg[gen_idx]))
	end
	
	p_to_max = zeros(num_branches)
	q_to_max = zeros(num_branches)
	p_fr_max = zeros(num_branches)
	q_fr_max = zeros(num_branches)
	if haskey(collect(values(net_branch))[1], "rate_a")
	for branch in values(net_branch)
		idx = branch["index"]
		fr = branch["f_bus"]
		to = branch["t_bus"]
		to_key = (idx, fr, to)
		fr_key = (idx, to, fr)
		p_to = p[to_key]
		q_to = q[to_key]
		p_fr = p[fr_key]
		q_fr = q[fr_key]
		
		p_to_max[idx] = JuMP.dual(JuMP.UpperBoundRef(p_to))
		q_to_max[idx] = JuMP.dual(JuMP.UpperBoundRef(q_to))
		p_fr_max[idx] = JuMP.dual(JuMP.UpperBoundRef(p_fr))
		q_fr_max[idx] = JuMP.dual(JuMP.UpperBoundRef(q_fr))
	end
	end
	
	duals = Dict("v_min" => Array(v_min'),
				 "v_max" => Array(v_max'),
				 "pg_min" => Array(pg_min'),
				 "pg_max" => Array(pg_max'),
				 "qg_min" => Array(qg_min'),
				 "qg_max" => Array(qg_max'),
				 "pto_max" => Array(p_to_max'),
				 "qto_max" => Array(q_to_max'),
				 "pfr_max" => Array(p_fr_max'),
				 "qfr_max" => Array(q_fr_max'),
				 )
	
	results = (primals, duals)
	return results, converged
end


"Calculates and returns the admittance matrix for the given network data dictionary"
function admittance_matrix(network_data::Dict)
	network_data = fix_network_data_dict(network_data)  
	return PM.calc_admittance_matrix(network_data).matrix
end


"""
	Sets the PowerModels data dictionaries types to Dict{String,Any} as Python strips the
	string type which is required by PowerModels functions.
"""
function fix_network_data_dict(network_data)
	# Dicts & subDicts passed from python have type Dict{Any,Any}
	network_data = convert(Dict{String,Any}, network_data) 
	for key in keys(network_data)  # Need Dict{String,Any}
	if typeof(network_data[key]) == Dict{Any,Any}
		network_data[key] = convert(Dict{String,Any}, network_data[key])
		for key2 in keys(network_data[key])
		if typeof(network_data[key][key2]) == Dict{Any,Any}
			network_data[key][key2] = convert(Dict{String,Any}, network_data[key][key2])
		end
		end
	end
	end
	
	return network_data
end
