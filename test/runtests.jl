using OPFLearn
using Test

@testset "OPFLearn.jl" begin
	include("sample.jl")
	include("create_samples.jl")
	include("io.jl")
end
