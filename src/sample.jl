""" 
Translated to Python and modified based on:
https://www.mathworks.com/matlabcentral/fileexchange/34208-uniform-distribution-over-a-convex-polytope
Copyright (c) 2011-2012 Tim J. Benham, School of Mathematics and Physics, University of Queensland.

CHEBYCENTER Compute Chebyshev center of polytope Ax <= b.
The Chebyshev center of a polytope is the center of the largest
hypersphere enclosed by the polytope.
"""
function chebyshev_center(A, b, opt=Ipopt.Optimizer)
    m, p = size(A)

    an = sqrt.(sum(A.^2, dims=2))

    A_r = zeros((m, p+1))
    A_r[:, 1:p] = A
    A_r[:, p+1] = an

    f = zeros((p+1, 1))
    f[p+1] = -1
	
	model = JuMP.Model(opt)
	JuMP.set_silent(model)
	JuMP.@variable(model, 0 <= x[1:p+1])
	JuMP.@constraint(model, A_r * x .<= b)
	JuMP.@objective(model, Max, x[p+1])  # Was f'*x, but not supported by JuMP?
	#TASK: Postive or negative for objective?
    JuMP.optimize!(model)
	result = JuMP.value.(x)
	
	center = result[1:p]'
    radius = result[p+1]

    return center, radius
end



""" 
# NOT WORKING
Finds the maximum volume inscribed ellipsoids in the given polytope Ax<b
"""
function maximum_volume_inscribed_ellipsoid(A, b, opt=GLPK.Optimizer)
    m, p = size(A)
	
	model = JuMP.Model(opt)
	JuMP.set_silent(model)
	JuMP.@variable(model, 0 <= d[1:p])
	JuMP.@variable(model, 0 <= B[1:p,1:p])
	for i in 1:m
		#JuMP.@constraint(model, norm(B * A[i,:]) + dot(A[i,:], d) .<= b[i])
		JuMP.@constraint(model, [b[i] - dot(A[i,:], d) ; B * A[i,:]] in SecondOrderCone())
	end
	JuMP.@objective(model, Max, logdet(B)) 
    JuMP.optimize!(model)

	center = value.(d)
    return center, radius
end


""" 
Translated to Julia and modified based on:
https://www.mathworks.com/matlabcentral/fileexchange/34208-uniform-distribution-over-a-convex-polytope
Copyright (c) 2011-2012 Tim J. Benham, School of Mathematics and Physics, University of Queensland.

CPRND Draw from the uniform distribution over a convex polytope.
	X = cprnd(N,A,b) Returns an N-by-P matrix of random vectors drawn
	from the uniform distribution over the interior of the polytope
	defined by Ax <= b. A is a M-by-P matrix of constraint equation
	coefficients. b is a M-by-1 vector of constraint equation
	constants

...
- 'method::String': 'gibbs': Gibbs sampler, 'hitandrun': Hit and Run, 'achr': Adaptive Centering Hit-and-Run
- 'iso::Integer': Isotropic Transformation (0: no xfrm, 1: Xfrm during runup, 2: Xfrm throughout sampling
- 'runup::Integer': # of initial iterations of the algorithm in the untransformed space for gibbs or hitandrun
- 'discard::Integer': # of initial samples (post run_up) to discard. Randomly selects n_samples from the 
		discard + n_samples samples.
...
"""
function sample_polytope_cprnd(A, b, x0, n_samples=1; seed=nothing, method="achr", runup=nothing, iso=nothing, discard=nothing)
    m, p = size(A)

    # Setting up default options
    if isnothing(iso)
        if method != "achr"
            iso = 2
        else
            iso = 0
		end
	end
	
    if isnothing(runup)
		if method == "achr"
			runup = 10 * (p+1)
		elseif iso != 0
			runup = 10 * p * (p + 1)
		else
			runup = 0
		end
	end
	
    if isnothing(discard)
        if method == "achr"
            discard = 1 * (p + 1)
        else
            discard = runup
		end
	end
	
    # Initializations
    rng = Random.MersenneTwister(seed)

    rnd_unit_vector(rng, p) = normalize(randn(rng, (p,1)))

    X = zeros((p, n_samples + runup + discard))

    n = 0  # Number of samples generated
    x = x0

    # Containers for mean, covariance, and isotropic transform tracking
    M_inc = zeros((p, 1))  # Incremental mean
    S_inc = zeros((p, p))  # Incremental sum of products

    S = I(p)
    T = I(p)
    W = A

    while n < (n_samples + runup + discard)
        y = x
		
        if iso > 0
            if n == runup | (iso == 2 & n > runup)
                T = cholesky(S).L
				W = A * T
			end
            y = T \ y
		end
		
        if method == "gibbs"
            for i in 1:p
                e = circshift(Matrix(I, p, 1), i - 1)
                z = W * e  # Selects row i?
                c = (b - W * y) ./ z
                t_min = maximum(c[z .< 0])
                t_max = minimum(c[z .> 0])

                y = y + (t_min + (t_max - t_min) * Random.rand(rng)) * e
			end
        elseif method == "hitandrun"
			u = rnd_unit_vector(rng, p)
            z = W * u
            c = (b - W * y) ./ z
            t_min = maximum(c[z .< 0])
            t_max = minimum(c[z .> 0])

            y = y + (t_min + (t_max - t_min) * Random.rand(rng)) * u
        else  # achr
            if n < runup
                u = rnd_unit_vector(rng, p)
            else
                v = X[:, rand(rng, 1:n)]
                u = normalize(v - M_inc)
			end

            z = A * u
            c = (b - W * y) ./ z
            t_min = maximum(c[z .< 0])
            t_max = minimum(c[z .> 0])

            y = y + (t_min + (t_max - t_min) .* Random.rand(rng)) .* u
		end
		
        if iso > 0
            x = T * y
        else
            x = y
		end
        X[:, n+1] = x
        n = n + 1

	
        delta_0 = x - M_inc  # Delta between new point & old mean
        M_inc = M_inc + delta_0 / n  # Sample mean
        delta_1 = x - M_inc  # Delta between new point & new mean
	
		
        if iso > 0
			if n > 1
				# Time Bottleneck here for iso
				S_inc = S_inc + (n - 1) / (n * n) * delta_0 * delta_0' + delta_1 * delta_1'
				
				S_0 = S
				S = S_inc / (n - 1)
			else
				S = Matrix(I,p,p)
			end
			S = (S + S') / 2  # Make array Hermitian Symmetric since computational error is likely
		end
	end
    X = X[:, runup + 1: n_samples + discard + runup]
	
	#TEST: Make discard pick random values from after runup to n_samples
	keep = sample(rng, 1:(n_samples + discard), n_samples, replace=false)
	X = X[:, keep]
    return X
end


"Used to call sample_uniform from create_samples"
function sample_uniform(A, b, x0, n_samples=1; nominal_load=nothing, dist_perc=0.2)
	isnothing(nominal_load) && error("nominal_load must not be nothing. Include nominal load in the 
									  sampler_opts dictionary with the key ':nominal_load'")
	samples = sample_uniform(nominal_load, dist_perc=dist_perc)
	for _ in 1:n_samples
		s = sample_uniform(nominal_load, dist_perc=dist_perc)
		samples = vcat(samples, s)
	end
	return samples
end

""" 
Samples from a uniform distribution of the given percentage 
around the given base load, x_0 = (pd\\_0 + qd\\_0). Power factors
are held constant.

x_il = U[0.8 x_i0, 1.2 x_i0] for all i in load buses
"""
function sample_uniform(nominal_load; dist_perc=0.2)
	@assert length(nominal_load) % 2 == 0 "Nominal load profile must contain an even number of load values (active and reactive load pairs). Currently contains $(length(nominal_load))."
	num_loads = Int(length(nominal_load) / 2)
	sampled_dist = (1 .+ dist_perc .* (rand(num_loads) .* 2 .- 1))
	
	new_load = nominal_load .* [sampled_dist ; sampled_dist]
	return new_load 
end


"Used to call sample_uniform_w_pf from create_samples"
function sample_uniform_w_pf(A, b, x0, n_samples=1; nominal_load=nothing, dist_perc=0.2, pf_range=(0.8,1.0))
	isnothing(nominal_load) && error("nominal_load must not be nothing. Include nominal load in the 
									  sampler_opts dictionary with the key ':nominal_load'")
	
	samples = sample_uniform_w_pf(nominal_load, dist_perc=dist_perc, pf_range=pf_range)
	for _ in 1:n_samples
		s = sample_uniform_w_pf(nominal_load, dist_perc=dist_perc, pf_range=pf_range)
		samples = vcat(samples, s)
	end
	return samples
	return 
end


"""
Samples from a uniform distribution of the given percentage 
around the given base load real power, pd_0. Then sample a 
power factor from the given pf_range to determine the reactive
load of the sample. By default the pf_range refers to lagging 
power factors. If a value larger than 1.0 is given in the range,
it will be converted to a leading power factor of pf = (1.0 - x).

- p\\_il = U[(1-dist) * p_i0, (1+dist) * p\\_i0] for all i in load buses
- d\\_il = U[pf\\_range] for all i in load buses
- q\\_il = tan(d\\_il) * p\\_il
"""
function sample_uniform_w_pf(nominal_load; dist_perc=0.2, pf_range=(0.8,1.0))
	@assert length(nominal_load) % 2 == 0 "Nominal load profile must contain an even number of load values (active and reactive load pairs). Currently contains $(length(nominal_load))."
	num_loads = Int(length(nominal_load) / 2)
	sampled_pl = nominal_load[1:num_loads] .* (1 .+ dist_perc .* (rand(num_loads) .* 2 .- 1))
	sampled_pf = (pf_range[2] - pf_range[1]) .* rand(num_loads) .+ pf_range[1]
	if sampled_pf > 1.0
		sampled_pf = 1.0 - sampled_pf
	end
	sampled_ql = sampled_pl .* tan.(acos.(sampled_pf))
	
	new_load = [sampled_pl; sampled_ql]
	return new_load 
end


"Return the unit vector of vector, v"
function normalize(v)
    norm_ = norm(v)
    if norm_ == 0
        norm_ = eps()
	end
    return v / norm_
end
