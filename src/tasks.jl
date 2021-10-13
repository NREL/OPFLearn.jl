# Functions used to give workers tasks for distributed processing

# Imports for distributed processors
#using OPFLearn


""" 
Produces samples from the given polytope and stores them in the sample channel.
Adds any new polytope constraints that are put in the polytope channel to the 
polytope defined by Ax < b. When a new constraint is added all samples in the
sample channel are replaced. 

Runs until the given termination criteria are met.
"""
function sample_producer(A, b, sampler, sampler_opts::Dict, base_load_feasible,
					     K, U, S, V, max_iter, T, num_procs, results, 
						 discard, variance, reset_level, 
						 save_while, save_infeasible, stat_track, save_certs,
						 net_name, dual_vars, save_order, replace_samples,
						 save_path, sample_ch, polytope_ch, result_ch, final_ch,
						 print_level)
	now_str = Dates.format(Dates.now(), "mm-dd-yyy_HH.MM.SS")
	
	AC_inputs = results["inputs"]
    AC_outputs = results["outputs"]
    duals = results["duals"]
	
	save_infeasible && (infeasible_AC_inputs = results["infeasible_inputs"])
	save_certs && (store_cert(results, A, b))
	stat_track > 0 && (stats = results["stats"])
	
	# Gather initial chebychev center for sampler
	center, radius = chebyshev_center(A, b)
	x0 = center'
	
	#TEST: Use base_load_feasible in starting point
	x0 = base_load_feasible * 0.9 + center' * 0.1
	
	# Initialize load sample, x, containing [PG; QG]
    new_samples = sampler(A, b, x0, 4*num_procs; sampler_opts...)
	for sample in eachcol(new_samples)
		put!(sample_ch, sample)
	end
	
	k = 0  # Count of feasible samples collected
    i = 0  # Count of samples generated
	u = 0  # Count of feasible samples since last unique active set found
	v = 0  # Count of feasible samples since last increase in variance seen
	s = 0  # Count of feasible samples since last saved (not discarded) sample
	(print_level > 0) && println("Starting sample production...")
	start_time = time()
	while (k < K) & (u < (1 / U)) & (s < (1 / S)) & (v < 1 / V)	 & 
		  (i < max_iter) & ((time() - start_time) < T)
		n_certs = length(b)
		while isready(polytope_ch)
			println("ADDING SLICE")
			x_star, x = take!(polytope_ch)
			
			A, b = add_infeasibility_certificate(A, b, x_star, x)
			save_certs && (store_cert(results, A, b))
			if save_while
				save_cert(A, b, net_name*"_"*now_str, dir=save_path)
			end
			
			x0 = x_star  #TASK: Should work since x_star always r-AC-OPF feasible
		end
		
		if length(b) > n_certs
			# Fully replace values in sample_chnl
			center, radius = chebyshev_center(A, b)
			if reset_level > 1
				x0 = (base_load_feasible * 0.1 + x0 * 0.9) * 0.9 + center' * 0.1
			elseif reset_level > 0
				x0 = x0 * 0.9 + center' * 0.1
			else
				x0 = center'
			end
			
			# Replace values in sample queue
			#TEST: Sometimes this seems to block and make the process halt
			if replace_samples
				num_new_samples = 0
				while isready(sample_ch)
					take!(sample_ch)  #TASK: Figure out if this can be blocking
					num_new_samples += 1  # and can get stuck waiting on a sample when there are none
				end
				
				new_samples = sampler(A, b, x0, num_new_samples; sampler_opts...)
				for sample in eachcol(new_samples)
					put!(sample_ch, sample)
				end
			end
		end
		
		# Only takes a sample once per iteration which can have two results
		#TEST: Will it still work with while instead of if? Would likely improve speeds as procs could be waiting on samples?
		# What happens if results are being returned faster than this loop? Put a limit on it? 10 iters per while?
		num_new_samples = 0
		while isready(result_ch) & ((k < K) & (u < (1 / U)) & (s < (1 / S)) & (v < 1 / V))	 & 
								   (i < max_iter) & ((time() - start_time) < T)
			# Get sample result from result channel
			x, result, feasible, new_cert, iter_elapsed_time = take!(result_ch)
			
			# Set stats to defaults
			iter_stats = Dict(:new_cert => new_cert,
							  :new_set => false,
							  :var_inc => false,
							  :added => false,
							  :feasible => false,
							  :iter_time => iter_elapsed_time,
							  :active_set => []
							  )
			
			#TASK: Determine if there is a way to continue sampling off of old load
			# Can only tell if the result is feasible 
			#if feasible 
			#	x0 = x #TASK: Set this up to be when SOC feasible or ACOPF feasible
			#end
			
			num_new_samples += 1
			i += 1  # Increment iterations
			
			if feasible
				s, u, v, k, iter_stats = store_feasible_sample(s, u, v, k, i, K, iter_stats,
											  AC_inputs, AC_outputs, duals, dual_vars,
											  x, result, discard, variance, net_name, 
											  now_str, save_path, save_while, save_order,
											  print_level)
				
			elseif !isnothing(result)  # Infeasible
				save_infeasible && store_infeasible_sample(infeasible_AC_inputs, x, result, 
								save_while, net_name, now_str, save_order, dual_vars, save_path)
			end
			
			print_level > 0 && println("Samples: $(k) / $(K),\t Iter: $(i)")
			
			if stat_track > 0
				update_stats!(stats, duals, iter_stats, save_level=stat_track)
				save_while && (save_stats(iter_stats, net_name*"_"*now_str*"_stats", dir=save_path))
			end
		end
		
		if num_new_samples > 0
			new_samples = sampler(A, b, x0, num_new_samples; sampler_opts...)
			for sample in eachcol(new_samples)
				put!(sample_ch, sample)
			end
			x0 = new_samples[:, end]  # Set sampler origin to last sampled sample
		end
	end
	# Put results objects into the final channel pipeline to get returned
	put!(final_ch, "DONE FLAG")
	
	return results
end


""" 
Adds a new constraint to a polytope defined by Ax < b.
The constraint is constructed from a point, p1, and a 
normal vector, p2 - p1.
"""
function add_infeasibility_certificate(A, b, p1, p2)
	normal = (p2 - p1)'
	
	# Add infeasibility certificate
	A = vcat(A, normal)
	b = vcat(b, normal * p1)
	return A, b
end


""" 
Tests feasibility of generated samples from the sample channel and if 
infeasible finds the nearest feasible point. Adds this nearest feasible 
point and original sample to the polytope channel to add a infeasibility 
certificate in the polytope sample space. Runs until a value is added to 
the done_ch.
"""
function sample_processor(net, net_r, r_solver, opf_solver,
						  sample_ch, done_ch, poly_ch, result_ch,
						  print_level=0, model_type=PM.QCLSPowerModel)
	
	(print_level > 0) && println("Create FNFP Model...")
	pm = PowerModels.instantiate_model(net_r, model_type, build_opf_var_load)
	fnfp_model = find_nearest_feasible_model(pm, print_level=print_level, solver=r_solver)
	
	(print_level > 0) && println("Starting sample processing...")
    i = 1  # Count of iterations
    while !isready(done_ch)  #TASK: Determine the best way to terminate this loop
        iter_start_time = time()
		println("Iter: $(i)") #TEST: Printing samples every iteration
				
		# Gather sample from sample channel
		x = take!(sample_ch)
		
        # Set network loads to sampled values
        set_network_load(net, x, scale_load=false)
		
        # Solve OPF for the load sample
        result, feasible = run_ac_opf(net, solver=opf_solver)
        println("OPF SUCCESS: " * string(feasible))
		
		new_cert = false  # Default for iteration stat tracking
		
		if !feasible
			println("FINDING NEAREST FEASIBLE")
            px = x[1:Integer(length(x)/2)]
            qx = x[Integer(length(x)/2) + 1:end]
			
            r, pd, qd, solved = find_nearest_feasible(fnfp_model, px, qx, print_level=print_level)
			
			r = sum((pd .- px).^2 + (qd .- qx).^2)
			println("R:", r)
			
            if (r > R_TOLERANCE) & solved
				new_cert = true  # For iteration stat tracking
                # Solve OPF for the random sample:
                # try to solve the non-convex AC OPF at this solution
                # note that: while this solution is feasible for the relaxation
                # it can be infeasible for the original problem.

                # Get infeasibility certificate
                xp_ = pd .- INFEASIBILITY_CERT_SHIFT  	
                xq_ = qd .- INFEASIBILITY_CERT_SHIFT 	
				xp_[xp_ .< 0] .= 0 # Was used when substracting 1e-2 here
				xq_[xq_ .< 0] .= 0 # Ensure loads do not go negative when shifted
				
                x_star = vcat(xp_, xq_)
				
				# Puts new infeasibility certificate points to be added to the polytope
				put!(poly_ch, (x_star, x))
				
				xp_ = pd .- FNFP_SHIFT  
                xq_ = qd .- FNFP_SHIFT		
				xp_[xp_ .< 0] .= 0 
				xq_[xq_ .< 0] .= 0
                x = vcat(xp_, xq_)

                set_network_load(net, x, scale_load=false)

                # Solve OPF for the relaxation feasible sample
                result, feasible = run_ac_opf(net, solver=opf_solver)
                println("FNFP OPF SUCCESS: " * string(feasible))	
			end
		end
		# Puts OPF results to the results channel to be processed by main thread
		iter_elapsed_time = time() - iter_start_time
		
		put!(result_ch, (x, result, feasible, new_cert, iter_elapsed_time))
        i = i + 1
	end
end
