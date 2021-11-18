# Gathers network information used for generating AC OPF samples


"Loads a PowerModels network dictionary from the net file and parses out the file dir"
function load_net(net::AbstractString, net_path, print_level=0)
	(print_level > 0) && println("Loading PowerModules.jl model data...")
	net = joinpath(net_path, net)  		# Join net_path and net if net_path is given
	net_path, net_name = splitdir(net)  # Get the net path in case it was given with the network
	net = PM.parse_file(net)  			# Load PowerModels data
	return net, net_path
end


"Returns the PowerModels.jl network data information needed to generate AC OPF samples"
function gather_net_info(net)
	net_name = net["name"]
	
	# Get system information for relaxed AC OPF runs
	net_ref = PM.build_ref(net)
	bus_ref = net_ref[:it][:pm][:nw][NW_DEFAULT][:bus]
	
	load_buses = sort([load["load_bus"] for load in values(net["load"])])
	gen_buses = sort([gen["gen_bus"] for gen in values(net["gen"])
                 if bus_ref[gen["gen_bus"]]["bus_type"] != 3])
    ext_bus = sort([gen["gen_bus"] for gen in values(net["gen"])
                 if bus_ref[gen["gen_bus"]]["bus_type"] == 3])
    gen_buses_w_ext = sort([ext_bus; gen_buses])
	num_loads = length(load_buses)
    num_gens = length(gen_buses)
    num_buses = length(net["bus"])
    num_ext = length(ext_bus)
	num_branches = length(net["branch"])
	
	pg_max = [gen["pmax"] for gen in values(net["gen"])]
	
	# Get base load
	load_ref = net_ref[:it][:pm][:nw][NW_DEFAULT][:load]
	
    base_pd = [load_ref[bus]["pd"] for bus in 1:length(load_ref)]
	base_qd = [load_ref[bus]["qd"] for bus in 1:length(load_ref)]
	base_load = vcat(base_pd, base_qd)
	
	keys_ = ("net_name", "load_buses", "gen_buses", "ext_bus", "num_loads", "num_gens", "num_buses",
			 "num_ext", "num_branches", "pg_max", "base_load")
	
	values_ = (net_name, load_buses, gen_buses, ext_bus, num_loads, num_gens, num_buses, 
			   num_ext, num_branches, pg_max, base_load)
	
	net_info = Dict(zip(keys_, values_))
	return net_info
end


"Creates a copy of the given network dictionary and stores additional constraint information"
function create_net_r(net, pf_min, pf_lagging, base_load)
	net_r = copy(net)  # PowerModels data dict to use for convex formulations
	num_loads = length(net["load"])
	pf_min isa Number && (pf_min = ones(num_loads) .* pf_min)
	net_r["pf_min"] = pf_min  # Set pf_min for relaxed formulation load constraints
	net_r["pf_lagging"] = pf_lagging
	net_r["base_load"] = base_load
	return net_r
end


""
function find_max_loads(pd_max, net_r, net_path, net_name, model_type, r_solver,
						save_max_load, results, save_while, print_level)
	if isnothing(pd_max)
		max_load_file = joinpath(net_path, net_name * "_found_max_load.csv")
		if isfile(max_load_file )
			pd_max = readdlm(max_load_file , ',')
		else
			pm_pd_max = PM.instantiate_model(net_r, model_type, build_opf_var_load)
			pd_max, status = find_max_loads(pm_pd_max, print_level=print_level, solver=r_solver)
								   
			save_while && writedlm(max_load_file, pd_max, ',')
		end
	end
	net_r["pd_max"] = pd_max
	if save_max_load
		!haskey(results, "load_constraints") && (results["load_constraints"]=Dict())
		results["load_constraints"]["pd_max"] = pd_max
	end
	return pd_max
end


""" 
Sets the load values in the net to the given load profile
specified in a 2*n_load x 1 array of n_load real then n_load
reactive load powers.
"""
function set_network_load(net, new_load; scale_load=true)
    if scale_load
		new_load = new_load * 1 / net["baseMVA"]
	end
	
    num_loads = length(net["load"])
    for load in values(net["load"])
        load_index = load["index"]
        load["pd"] = float(new_load[load_index][1])
        load["qd"] = float(new_load[load_index + num_loads][1])
	end
end
