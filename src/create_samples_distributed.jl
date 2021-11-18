"""
Loads in PowerModels network data given the name of a network case file, 
then starts creating samples with distributed processing
"""
function dist_create_samples(net::String, K=Inf; U=0.0, S=0.0, V=0.0, max_iter=Inf, T=Inf, discard=false, variance=false,
							input_vars=DEFAULT_INPUTS, output_vars=DEFAULT_OUTPUTS, dual_vars=DEFAULT_DUALS,
							sampler=sample_polytope_cprnd, sampler_opts=Dict{Symbol,Any}()::Dict{Symbol}, A=[]::Array, b=[]::Array,
							pd_max=nothing, pd_min=nothing, pf_min=0.7071, pf_lagging=true, reset_level=0, nproc=nothing, replace_samples=false,
							save_max_load=false, save_certs=false,
							print_level=0, stat_track=false, save_while=false, save_infeasible=false, save_path="", net_path="",
							model_type=PM.QCLSPowerModel, r_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL), 
							opf_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	net, net_path = load_net(net, net_path, print_level)
	
	return dist_create_samples(net, K::Integer; U=U, S=S, V=V, max_iter=max_iter, T=T, discard=discard, variance=variance,
							  input_vars=input_vars, output_vars=output_vars, dual_vars=dual_vars,
							  sampler=sampler, sampler_opts=sampler_opts, A=A, b=b, reset_level=reset_level, 
							  pd_max=pd_max, pd_min=pd_min, pf_min=pf_min, pf_lagging=pf_lagging, nproc=nproc, replace_samples=replace_samples,
							  save_certs=save_certs, save_max_load=save_max_load,
							  print_level=print_level, stat_track=stat_track, save_while=save_while,
							  save_infeasible=save_infeasible, save_path=save_path, net_path=net_path,
							  model_type=model_type, r_solver=r_solver, opf_solver=opf_solver)
end


""" 
Creates an AC OPF dataset for the given PowerModels network dictionary. Generates samples until one of the given stopping criteria is met. 
Takes options to determine how to sample points, what information to save, and what information is printed.

# Arguments
- 'net::Dict': network information stored in a PowerModels.jl format specified dictionary
- 'K::Integer': the maximum number of samples before stopping sampling
- 'U::Float': the minimum % of unique active sets sampled in the previous 1 / U samples to continue sampling
- 'S::Float': the minimum % of saved samples in the previous 1 / L samples to continue sampling
- 'V::Float': the minimum % of feasible samples that increase the variance of the dataset in the previous 1 / L samples to continue sampling
- 'T::Integer': the maximum time for the sampler to run in seconds.
- 'max_iter::Integer': maximum number of iterations for the sampler to run for.
- 'nproc::Integer': the number of processors for the sampler to run with. Defaults to the number reported by Distributed.nprocs().
- 'replace_samples::Bool': whether samples in the samples channel are replaced when a new infeasibility certificate is added. Found to sometimes block progress when turned on.
- 'sampler::Function': the sampling function to use. This function must take arguements A and b, and can take optional arguments.
- 'sampler_opts::Dict': a dictionary of optional arguments to pass to the sampler function.
- 'A::Array': defines the initial sampling space polytope Ax<=b. If not provided, initializes to a default.
- 'b::Array': defines the initial sampling space polytope Ax<=b. If not provided, initializes to a default.
- 'pd_max::Array': the maximum active load values to use when initializing the sampling space and constraining the loads. If nothing, finds the maximum load at each bus with the given relaxed model type.
- 'pd_min::Array': the minimum active load values to use when initializing the sampling space and constraining the loads. If nothing, this is set to 0 for all loads.
- 'pf_min::Array/Float:' the minimum power factor for all loads in the system (Number) or an array of minimum power factors for each load in the system.
- 'pf_lagging::Bool': indicating if load power factors can be only lagging (True), or both lagging or leading (False).
- 'reset_level::Integer': determines how to reset the load point to be inside the polytope before sampling. 2: Reset closer to nominal load & chebyshev center, 1: Reset closer to chebyshev center, 0: Reset at chebyshev center.
- 'save_certs::Bool': specifies whether the sampling space, Ax<=b (A & b matrices) are saved to the results dictionary.
- 'save\\_max_load::Bool': specifies whether the max active load demands used are saved to the results dictionary.
- 'model_type::Type': an abstract PowerModels type indicating the network model to use for the relaxed AC-OPF formulations (Max Load & Nearest Feasible)
- 'r_solver': an optimizer constructor used for solving the relaxed AC-OPF optimization problems.
- 'opf_solver': an optimizer constructor used to find the AC-OPF optimal solution for each sample.
- 'print_level::Integer': from 0 to 3 indicating the level of info to print to console, with 0 indicating minimum printing.
- 'stat_track::Integer': from 0 to 3 indicating the level of stats info saved during each iteration	0: No information saved, 1: Feasibility, New Certificate, Added Sample, Iteration Time, 2: Variance for all input & output variables
- 'save_while::Bool': indicates whether results and stats information is saved to a csv file during processing.
- 'save_infeasible::Bool': indicates if infeasible samples are saved. If true saves infeasible samples in a seperate file from feasible samples.
- 'save_path::String:' a string with the file path to the desired result save location.
- 'net_path::String': a string with the file path to the network file. 
- 'variance::Bool': indicates if dataset variance information is tracked for each unique active set.
- 'discard::Bool': indicates if samples that do not increase the variance within a unique active set are discarded.

See 'OPF-Learn: An Open-Source Framework for Creating Representative AC Optimal Power Flow Datasets'
for more information on how the AC OPF datasets are created. 

Modified from AgenerateACOPFsamples.m written by Ahmed S. Zamzam
"""
function dist_create_samples(net::Dict, K=Inf; U=0.0, S=0.0, V=0.0, max_iter=Inf, T=Inf, nproc=nothing, discard=false, variance=false,
								input_vars=DEFAULT_INPUTS, output_vars=DEFAULT_OUTPUTS, dual_vars=DEFAULT_DUALS,
								sampler=sample_polytope_cprnd, sampler_opts=Dict{Symbol,Any}()::Dict{Symbol}, A=[]::Array, b=[]::Array,
								pd_max=nothing, pd_min=nothing, pf_min=0.7071, pf_lagging=true, reset_level=0, replace_samples=false,
								save_max_load=false, save_certs=false, 
								print_level=0, stat_track=false, save_while=false, save_infeasible=false, save_path="", net_path="",
								model_type=PM.QCLSPowerModel, r_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL),
								opf_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	# Create channels for transfering data between processes
	isnothing(nproc) && (nproc = Distributed.nprocs())
	@assert nproc > 3 "Not enough processors available, nprocs:$(nproc). Need 4+ CPUs for improved runtimes."
	@assert nproc <= Distributed.nprocs() "Number of distributed processors added, $(Distributed.nprocs()), must be greater than specified nproc, $(nproc)"
	pid = Distributed.myid()
	sample_chnl = Distributed.Channel{Any}(4 * nproc) 
	polytope_chnl = Distributed.Channel{Any}(4 * nproc)  
	result_chnl = Distributed.Channel{Any}(4 * nproc) 
	final_chnl = Distributed.Channel{Any}(1)
	sample_ch = Distributed.RemoteChannel(()->sample_chnl, pid)
	polytope_ch = Distributed.RemoteChannel(()->polytope_chnl, pid)
	result_ch = Distributed.RemoteChannel(()->result_chnl, pid)
	final_ch = Distributed.RemoteChannel(()->final_chnl, pid)
	
	num_procs = nproc - 2  #TASK: Determine why the producer gets stuck running on the main proc
	
	net_name = net["name"]
	save_order = vcat(input_vars, output_vars, dual_vars)
    if net_path == ""  # Set net path to save path if not specified for saving network max loads
		net_path = save_path
	end
	
	# Gather network information used during processing
	A, b, x, results, fnfp_model, base_load_feasible, net_r = initialize(net, pf_min, pf_lagging, pd_max, pd_min,
																		 input_vars, output_vars, dual_vars,
																		 save_certs, save_infeasible, save_while,
																		 stat_track, save_max_load, A, b,
																		 sampler, sampler_opts, net_name,
																		 net_path, model_type, r_solver,
																		 reset_level, print_level)
	
	(print_level > 0) && println("Starting sampling...")
	procs = Distributed.workers()
	producer = Distributed.remotecall(sample_producer, procs[1], 
						  A, b, sampler, sampler_opts, base_load_feasible, K, U, S, V, max_iter, T, num_procs, 
						  results, discard, variance, reset_level, save_while, save_infeasible, 
						  stat_track, save_certs, net_name, dual_vars, save_order, replace_samples,
						  save_path, sample_ch, polytope_ch, result_ch, final_ch, print_level)
	for proc in procs[2:end]
		a = Distributed.remotecall(sample_processor, proc, net, net_r, r_solver, opf_solver, 
							   sample_ch, final_ch, polytope_ch, result_ch,
							   print_level, model_type)
	end

	results = Distributed.fetch(producer)
	# Need to convert the unique active sets Set to and Array, due to a bug with PyJulia
	results["duals"]["unique_active_sets"] = collect(results["duals"]["unique_active_sets"])
	return results
end


"UNUSED"
function initialize_distributed(net, num_procs; pd_max=nothing, save_path="",  net_path="", save_while=false, A=[], b=[],
							  line_constraints=false, r_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL),
							  model_type=PM.QCLSPowerModel, reset_level=0, print_level=0)
	net_name = net["name"]
	
    # Get system information for relaxed AC OPF runs
	net_info = gather_net_info(net) 
	num_loads = net_info["num_loads"]
	pg_max = net_info["pg_max"]
	base_load = net_info["base_load"]
	
	# Set pf_min & base_load in relaxed network info dict
	net_r = create_net_r(net, pf_min, pf_lagging, base_load)
	
	# Find the maximum servable load for each load bus in the system
	pd_max = find_max_loads(pd_max, net_r, net_path, net_name, model_type, save_max_load, print_level)
	
    # Initialize polytope, Ax <= b, parameter data structures
	A, b = initialize_polytope(num_loads, pd_max, pg_max, A, b, sampler)
	
	# Create find nearest feasible point model without the objective
	pm = PM.instantiate_model(net_r, model_type, build_opf_var_load)
	fnfp_model = find_nearest_feasible_model(pm, print_level=print_level, solver=r_solver)
	
	# Initialize sampler origin
	x, base_load_feasible = initialize_sample_origin(A, b, base_load, num_loads, fnfp_model, reset_level, print_level)
	
	return net, net_r, net_info, A, b, x
end
