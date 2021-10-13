function test_sampler_cube(sampler, n_samples; opts=Dict(), add_slice=nothing)
	""" Creates a 3-dimensional unit cube and uses the given sampler
		to sample from it the specified number of times. Then plots the 
		sampled distribution
	"""
	A = Array{Float64}(undef, 0, 3)
	b = Array{Float64}(undef, 0, 1)
	p0 = [1.0, 0.5, 0.5]
	v0 = [1.0, 0.0, 0.0]
	p1 = [0, 0.5, 0.5]
	v1 = [-1.0, 0.0, 0.0]
	for (p, v) in zip((p0,p1), (v0,v1))
	for i in 0:2
		p_ = circshift(p, i)
		v_ = circshift(v, i)
		A = vcat(A, v_')
		b = vcat(b, v_' * p_)
	end
	end
	
	if !isnothing(add_slice)
		v_ = add_slice[1]
		p_ = add_slice[2]
		A = vcat(A, v_')
		b = vcat(b, v_' * p_)
	end
	
	samples = Array{Float64}(undef, 0, 3)
	
	x0, r = OPFLearn.chebyshev_center(A, b)
	
	k = 0
	while k < n_samples
		sample = sampler(A, b, x0'; opts...)'
		samples = vcat(samples, sample)
		k = k + size(sample, 1)
	end
	return samples
end

"""
using PyPlot
const plt = PyPlot
function plot_samples_series(samples, loads=(1, 2, 3); sampler="", case="")
	
	num_samples = size(samples,1)
	
    fig = plt.figure()
    ax = fig.add_subplot(projection="3d")

    # Plots with colors indicating sample number
    p = ax.scatter(samples[:, loads[1]],
                   samples[:, loads[2]],
                   samples[:, loads[3]],
                   c=collect(1: size(samples,1)), cmap="plasma")
    fig.colorbar(p, label="Sample Number")
    ax.set_xlabel("Load " * string(loads[1]))
    ax.set_ylabel("Load " * string(loads[2]))
    ax.set_zlabel("Load " * string(loads[3]))
    plt.title(case * " load powers, " * string(num_samples) * " samples, " * sampler * " sampler")
    plt.tight_layout()
    plt.show()
end


function run_test_sampler(num_samples, add_slice=[[1.0,1.0,1.0],[0.5,0.5,0.5]])
	opts = Dict((:method=>"achr"))
	samples = test_sampler_cube(sample_polytope_cprnd, num_samples, opts=opts, add_slice=add_slice)
	plot_samples_series(samples, sampler="cprnd", case="Unit Cube")
end
"""


@testset "sampler uniformity check" begin
    @testset "cprnd unit cube" begin
		num_samples = 10000  # 10,000 samples should take approximately 30 seconds
		opts = Dict((:method=>"achr"))
		samples = test_sampler_cube(sample_polytope_cprnd, num_samples, opts=opts, add_slice=nothing)
		@test size(samples, 1) == num_samples
		@test size(samples, 2) == 3
		@test isapprox(maximum(samples[:,1]), 1; atol = 1e-1)
		@test isapprox(maximum(samples[:,2]), 1; atol = 1e-1)
		@test isapprox(maximum(samples[:,3]), 1; atol = 1e-1)
		test_points = ((1.0, 1.0, 1.0),
					   (0.5, 0.5, 0.5),
					   (0.0, 0.0, 0.0),
					   [circshift([1.0, 0.0, 0.0],i) for i in 1:3]...,
					   [circshift([1.0, 1.0, 0.0],i) for i in 1:3]...,
					   [circshift([1.0, 0.5, 0.5],i) for i in 1:3]...,
					   [circshift([0.0, 0.5, 0.5],i) for i in 1:3]...,
					   )
		
		for p in test_points  # Test that at least one point sampled is near a test point
		@test isapprox(minimum([sum((sample .- p).^2) for sample in eachrow(samples)]), 0; atol = 5e-2)
		end
    end

	
    @testset "cprnd unit cube with slice" begin
		num_samples = 10000  # 10,000 samples should take approximately 30 seconds
		opts = Dict((:method=>"achr"))
		normal = [1.0, 1.0, 1.0]
		point = [0.5, 0.5, 0.0]
		slice = [normal, point]
		samples = test_sampler_cube(sample_polytope_cprnd, num_samples, opts=opts, add_slice=slice)
		@test size(samples, 1) == num_samples
		@test size(samples, 2) == 3
		@test isapprox(maximum(samples[:,1]), 1; atol = 1e-1)
		@test isapprox(maximum(samples[:,2]), 1; atol = 1e-1)
		@test isapprox(maximum(samples[:,3]), 1; atol = 1e-1)
		inside_test_points = ((0.0, 0.0, 0.0),
							  (0.5, 0.5, 0.0),
							  (0.25, 0.25, 0.25),
							  [circshift([1.0, 0.0, 0.0],i) for i in 1:3]...,
						      )
		
		outside_test_points = ((1.0, 1.0, 1.0),
							   (0.5, 0.5, 0.5),
							   [circshift([1.0, 1.0, 0.0],i) for i in 1:3]...,
							   )
		for p in inside_test_points  # Test that at least one point sampled is near a test point
		@test isapprox(minimum([sum((sample .- p).^2) for sample in eachrow(samples)]), 0; atol = 5e-2)
		end
		for p in outside_test_points  # Test that there are no points sampled is near a test point
		@test minimum([sum((sample .- p).^2) for sample in eachrow(samples)]) > 1e-2
		end
    end
end
