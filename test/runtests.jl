using OPFLearn
using Test

# Distributed tests will be performed if a string of an integer > 3, representing the number
# of processors to use is passed to the package test function as follows,
# Pkg.test("OPFLearn"; test_args = ["4"])
if !isempty(ARGS)
	try
		global nproc = parse(Int, ARGS[1])
	catch 
		global nproc = nothing
	end
else
	global nproc = nothing
end

@testset "OPFLearn.jl" begin
	include("sample.jl")
	include("create_samples.jl")
	include("io.jl")
end

if !isnothing(nproc) && nproc > 2
	@testset "Distributed" begin
		include("distributed.jl")
	end
end 
