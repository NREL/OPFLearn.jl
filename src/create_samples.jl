"""
Loads in PowerModels network data given the name of a network case file, 
then starts creating samples
"""
function create_samples(net::String, K=Inf; U=0.0, S=0.0, V=0.0, max_iter=Inf, T=Inf, discard=false, variance=false,
						input_vars=DEFAULT_INPUTS, output_vars=DEFAULT_OUTPUTS, dual_vars=DEFAULT_DUALS,
						sampler=sample_polytope_cprnd, sampler_opts=Dict{Symbol,Any}()::Dict{Symbol}, A=[]::Array, b=[]::Array,
						pd_max=nothing, pd_min=nothing, pf_min=0.7071, pf_lagging=true, save_certs=false, save_max_load=false,
						print_level=0, stat_track=false, save_while=false, save_infeasible=false, save_path="", net_path="",
						model_type=PM.QCLSPowerModel, r_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL), 
						opf_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	net, net_path = load_net(net, net_path, print_level)
	
	return create_samples(net, K; U=U, S=S, V=V, max_iter=max_iter, T=T, discard=discard, variance=variance,
							  input_vars=input_vars, output_vars=output_vars, dual_vars=dual_vars, A=A, b=b,
							  sampler=sampler, sampler_opts=sampler_opts, save_max_load=save_max_load,
							  pd_max=pd_max, pd_min=pd_min, pf_min=pf_min, pf_lagging=pf_lagging, save_certs=save_certs,
							  print_level=print_level, stat_track=stat_track, save_while=save_while, 
							  save_infeasible=save_infeasible, save_path=save_path, net_path=net_path,
							  model_type=model_type, r_solver=r_solver, opf_solver=opf_solver)
end


""" 
    create_samples(net, K; <keyword arguments>)
	
Creates an AC OPF dataset for the given PowerModels network dictionary. Generates samples until one of the given stopping criteria is met. 
Takes options to determine how to sample points, what information to save, and what information is printed.

# Examples
```
julia> results = create_samples("case5.m", 100; T=1000, net_path="data")
```

# Arguments
- 'net::Dict': network information stored in a PowerModels.jl format specified dictionary
- 'K::Integer': the maximum number of samples before stopping sampling
- 'U::Float': the minimum % of unique active sets sampled in the previous 1 / U samples to continue sampling
- 'S::Float': the minimum % of saved samples in the previous 1 / L samples to continue sampling
- 'V::Float': the minimum % of feasible samples that increase the variance of the dataset in the previous 1 / L samples to continue sampling
- 'T::Integer': the maximum time for the sampler to run in seconds.
- 'max_iter::Integer': maximum number of iterations for the sampler to run for.
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
function create_samples(net::Dict, K=Inf; U=0.0, S=0.0, V=0.0, max_iter=Inf, T=Inf, discard=false, variance=false,
							input_vars=DEFAULT_INPUTS, output_vars=DEFAULT_OUTPUTS, dual_vars=DEFAULT_DUALS,
							sampler=sample_polytope_cprnd, sampler_opts=Dict{Symbol,Any}()::Dict{Symbol}, A=[]::Array, b=[]::Array,
							pd_max=nothing, pd_min=nothing, pf_min=0.7071, pf_lagging=true, reset_level=0, save_certs=false, save_max_load=false,
							print_level=0, stat_track=false, save_while=false, save_infeasible=false, save_path="", net_path="",
							model_type=PM.QCLSPowerModel, r_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL), 
							opf_solver=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => TOL))
	now_str = Dates.format(Dates.now(), "dd-mm-yyy_HH.MM.SS")  # Get date & time for result file names
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
    
	AC_inputs = results["inputs"]
	AC_outputs = results["outputs"]
	duals = results["duals"]
	
	save_infeasible && (infeasible_AC_inputs = results["infeasible_inputs"])
	save_certs && (store_cert(results, A, b))
	stat_track > 0 && (stats = results["stats"])
	
	# Set up sample processing while loop 
	k = 0  # Count of feasible samples collected
    i = 1  # Count of iterations
	s = 0  # Count of samples since last saved (not discarded) sample
	u = 0  # Count of samples since last unique active set found
	v = 0  # Count of samples since last increase in variance seen
	start_time = time()  # Start time in seconds
	m = size(A, 1)  # Number of polytope planes
    while (k < K) & (u < (1 / U)) & (s < (1 / S)) & (v < 1 / V) & 
		  (i < max_iter) & ((time() - start_time) < T)
        iter_start_time = time()
		
		if print_level > 0
			println("Samples: $(k) / $(K),\t Iter: $(i)")
		elseif i % (max_iter / 10) == 0
			println("Iter: $(i)")
		end
		
		# Set stats to defaults
		iter_stats = Dict(
						  :new_cert	=> false,
						  :new_set 	=> false,
						  :var_inc 	=> false,
						  :added 	=> false,
						  :feasible	=> false,
						  :iter_time => -1.0,
						  :active_set => [],
						  )
		
        # Generate sample of load profile
        m_ = size(A, 1)
        if m < m_  # New infeasibility certificate was added to the polytope			
			center, radius = chebyshev_center(A, b)
			if reset_level > 1
				x = (base_load_feasible * 0.1 + x * 0.9) * 0.9 + center' * 0.1
			elseif reset_level > 0
				x = x * 0.9 + center' * 0.1
			else
				x = center'
			end
			m = m_
		end
		
        # Sample uniformly from the interior of the convex polytope space
		x = sampler(A, b, x, 1; sampler_opts...)
		
        # Set network loads to sampled values
        set_network_load(net, x, scale_load=false)

        # Solve OPF for the load sample
		result, feasible = run_ac_opf(net, print_level=print_level, solver=opf_solver)
		print_level > 0 && println("OPF SUCCESS: " * string(feasible))
		
        if feasible
			s, u, v, k, iter_stats = store_feasible_sample(s, u, v, k, i, K, iter_stats,
										               AC_inputs, AC_outputs, duals, dual_vars,
													   x, result, discard, variance, net_name, 
													   now_str, save_path, save_while, save_order,
													   print_level)
			print_level > 0 && println("Samples: $(k) / $(K),\t Iter: $(i)")
        else
			save_infeasible && store_infeasible_sample(infeasible_AC_inputs, x, result, 
							save_while, net_name, now_str, save_order, dual_vars, save_path)
            px = x[1:Integer(length(x)/2)]
            qx = x[Integer(length(x)/2) + 1:end]
			
            r, pd, qd, solved = find_nearest_feasible(fnfp_model, px, qx, print_level=print_level)
			r = sum((pd .- px).^2 + (qd .- qx).^2)
			
			print_level > 0 && println("R: $(r)")
            if (r > R_TOLERANCE) & solved
                iter_stats[:new_cert] = true
				
				# Solve OPF for the random sample:
                # try to solve the non-convex AC OPF at this solution
                # note that: while this solution is feasible for the relaxation
                # it can be infeasible for the original problem.
                xp_ = pd .- INFEASIBILITY_CERT_SHIFT  	
                xq_ = qd .- INFEASIBILITY_CERT_SHIFT 			

				xp_[xp_ .< 0] .= 0 # Ensure loads do not go negative if shifted
				xq_[xq_ .< 0] .= 0 
				
                x_star = vcat(xp_, xq_)
                x_x_star = (x - x_star)'

                # Add infeasibility certificate
                A = vcat(A, x_x_star)
                b = vcat(b, x_x_star * x_star)
				save_while && save_cert(A, b, net_name*"_"*now_str, dir=save_path)
				save_certs && store_cert(results, A, b)
				
				# Slightly shift FNFP to make it more likely to be feasible
                xp_ = pd .- FNFP_SHIFT  
                xq_ = qd .- FNFP_SHIFT
				
				# Removes any negative values introduced by the shift			
				xp_[xp_ .< 0] .= 0 
				xq_[xq_ .< 0] .= 0
				
				x_star = vcat(xp_, xq_)
                x = x_star
                set_network_load(net, x, scale_load=false)

                # Solve OPF for the relaxation feasible sample
				result, feasible = run_ac_opf(net, print_level=print_level, solver=opf_solver)
				print_level > 0 && println("FNFP OPF SUCCESS: " * string(feasible))
				
                if feasible
					s, u, v, k, iter_stats = store_feasible_sample(s, u, v, k, i, K, iter_stats,
												  AC_inputs, AC_outputs, duals, dual_vars,
												  x, result, discard, variance, net_name, 
												  now_str, save_path, save_while, save_order,
												  print_level)
					println("Samples: $(k) / $(K),\t Iter: $(i)")
                else
					save_infeasible && store_infeasible_sample(infeasible_AC_inputs, x, result, 
								    save_while, net_name, now_str, save_order, dual_vars, save_path)
				end
			end
		end
		iter_elapsed_time = time() - iter_start_time
		iter_stats[:iter_time] = iter_elapsed_time
		
		if stat_track > 0
			update_stats!(stats, duals, iter_stats, save_level=stat_track)
			save_while && (save_stats(iter_stats, net_name*"_"*now_str*"_stats", dir=save_path))
		end
		
        i = i + 1
	end
	
	# Need to convert the unique active sets Set to and Array, due to a bug with PyJulia
	results["duals"]["unique_active_sets"] = collect(results["duals"]["unique_active_sets"])
    return results
end


"""
Gathers the network information needed during the dataset creation process, then initializes
objects used to create and process load samples. 
"""
function initialize(net, pf_min, pf_lagging, pd_max, pd_min, 
					input_vars, output_vars, dual_vars,
					save_certs, save_infeasible, save_while, stat_track, save_max_load, 
					A, b, sampler, sampler_opts, 
					net_name, net_path, model_type, r_solver, reset_level, print_level)
	# Get system information for relaxed AC OPF runs
	net_info = gather_net_info(net) 
	num_loads = net_info["num_loads"]
	pg_max = net_info["pg_max"]
	base_load = net_info["base_load"]
	
	# Set pf_min & base_load in relaxed network info dict
	net_r = create_net_r(net, pf_min, pf_lagging, base_load)
	
	# Construct objects for storing feasible point data
    results = initialize_results(input_vars, output_vars, dual_vars, net_info, 
								 save_certs, save_infeasible, stat_track)
	
    # Find the maximum servable load for each load bus in the system
	if !isnothing(pd_min)
		net_r["pd_min"] = pd_min
		if save_max_load
			!haskey(results, "load_constraints") && (results["load_constraints"]=Dict())
			results["load_constraints"]["pd_min"] = pd_min
		end
	end
	pd_max = find_max_loads(pd_max, net_r, net_path, net_name, model_type, r_solver,
							save_max_load, results, save_while, print_level)

	
    # Initialize polytope, Ax <= b, parameter data structures
	A, b = initialize_polytope(num_loads, pd_max, pd_min, pf_min, pf_lagging, pg_max, 
							   A, b, sampler, sampler_opts)
	
	# Create find nearest feasible point model without the objective
	pm = PM.instantiate_model(net_r, model_type, build_opf_var_load)
	fnfp_model = find_nearest_feasible_model(pm, print_level=print_level, solver=r_solver)
	
	# Initialize sampler origin
	x, base_load_feasible = initialize_sample_origin(A, b, base_load, num_loads, fnfp_model, 
													 reset_level, print_level)
	
	return A, b, x, results, fnfp_model, base_load_feasible, net_r
end


"""
Creates A & b matrices defining a polytope, Ax<=b, if A & b are not given. 
If A & b are given, checks their validity.

The initialized polytope has load constraints: 
constrains the maximum active demand to the given maximum active demand values,
constrains the minimum active demand to the given minimum active demand values,
constrains the minimum reactive demand to zero,
constrains the reactive demand with the given minimum power factor,
constrains the maximum total active load to the sum of generator active power ratings.
"""
function initialize_polytope(num_loads, pd_max, pd_min, pf_min, pf_lagging, pg_max, A=[], b=[], 
							 sampler=sample_polytope_cprnd, sampler_opts=Dict())
	if isempty(A) & isempty(b)
		isnothing(pd_min) && (pd_min=zeros((num_loads, 1)))
		pf_min isa Number && (pf_min = ones(num_loads) .* pf_min)
		d = tan.(acos.(pf_min))
		
		# Max active demand constaint
		max_pd_constr = hcat(I(num_loads), zeros((num_loads, num_loads)))
		# Min active demand constraint
		min_pd_constr = hcat(-I(num_loads), zeros((num_loads, num_loads)))
		# Max reactive demand constraint
		max_qd_constr = hcat(-I(num_loads).*d, I(num_loads))
		# Min reactive demand constraint
		if pf_lagging
			min_qd_constr = hcat(zeros((num_loads, num_loads)), -I(num_loads))
		else
			min_qd_constr = hcat(I(num_loads).*d, -I(num_loads))
		end
		# Total active demand constraint
		tot_pd_constr = hcat(ones((1, num_loads)), zeros((1, num_loads)))
		
		A = vcat(max_pd_constr,
				 min_pd_constr,
				 max_qd_constr,
				 min_qd_constr,
				 tot_pd_constr,
				 )
		b = vcat(pd_max,
				 pd_min,
				 zeros((num_loads, 1)),
				 zeros((num_loads, 1)),
				 [sum(pg_max)],
				 )
	else  # Check if given polytope definition matrices are valid
		@assert size(A,1) == size(b,1) "A & b dimensions do not align. Must align with equation, Ax<=b"
		@assert size(A,2) == (2 * num_loads) "A must be N x (2*num_loads)"
		@assert size(b,2) == 1 "b must be N x 1"
		try  # to gather a sample with the given polytope definition
			center, radius = chebyshev_center(A, b)
			x = center'
			x = sampler(A, b, x, 1; sampler_opts...)
		catch
			@assert false "The sampler could not find a sample from the given polytope, Ax<=b. The given space must be enclosed."
		end
	end 
	return A, b 
end


"Finds a point to initialize the sampler from based on the network, polytope, and origin reset option"
function initialize_sample_origin(A, b, base_load, num_loads, fnfp_model, reset_level, print_level)
	# Initialize load sample, x, to chebyshev center
	center, radius = chebyshev_center(A, b)
    x = center'
	
	# Ensure that the base load is feasible for the relaxation & within the polytope
	if reset_level > 1
		base_pd = base_load[1:num_loads]
		base_qd = base_load[num_loads+1:end]
		r, pd, qd = find_nearest_feasible(fnfp_model, base_pd, base_qd, print_level=print_level)
		base_load_feasible = vcat(pd, qd)
		x = base_load_feasible * 0.9 + center' * 0.1
	else 
		base_load_feasible = center'
	end
	return x, base_load_feasible
end
