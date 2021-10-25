@testset "test distributed dataset creation" begin
    @testset "5-bus case file, number of samples" begin
		# Create worker processes
		#nproc = Sys.CPU_THREADS # The desired number of CPUs to run with
		# Clear any existing worker processes if present
		Distributed.nprocs() > 1 && Distributed.rmprocs(Distributed.workers())
		# Create worker processes
		Distributed.addprocs(nproc - 1; exeflags="--project")

		# Import functions used on all worker processes
		Distributed.@everywhere using OPFLearn
		
		net_file = "pglib_opf_case5_pjm.m"
		K = 100
		results = dist_create_samples(net_file, K, net_path="data")
        @test size(results["inputs"]["pl"],1) == K
		@test size(results["inputs"]["pl"],2) == 3
		@test size(results["outputs"]["pg"],1) == K
		@test size(results["outputs"]["pg"],2) == 5
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 5
    end

    @testset "5-bus case file, specified variables" begin
		# Create worker processes
		#nproc = Sys.CPU_THREADS # The desired number of CPUs to run with
		# Clear any existing worker processes if present
		Distributed.nprocs() > 1 && Distributed.rmprocs(Distributed.workers())
		# Create worker processes
		Distributed.addprocs(nproc - 1; exeflags="--project")

		# Import functions used on all worker processes
		Distributed.@everywhere using OPFLearn
	
		input_vars = ["pl", "ql"]
		output_vars = ["pg", "vm_gen"]
		dual_vars = ["v_min", "qg_min", "p_to_max"]
		
		net_file = "pglib_opf_case5_pjm.m"
		K = 100
		results = dist_create_samples(net_file, K, net_path="data", input_vars=input_vars, 
									  output_vars=output_vars, dual_vars=dual_vars)
        @test length(results["inputs"]) == length(input_vars)
		@test length(results["outputs"]) == length(output_vars)
		@test length(results["duals"]) == length(dual_vars) + 3  # Duals includes k, uas, and variances
		@test all([x in keys(results["inputs"]) for x in input_vars])
		@test all([x in keys(results["outputs"]) for x in output_vars])
		@test all([x in keys(results["duals"]) for x in dual_vars])
    end
	
	@testset "all save options distributed" begin
		# Create worker processes
		#nproc = Sys.CPU_THREADS # The desired number of CPUs to run with
		# Clear any existing worker processes if present
		Distributed.nprocs() > 1 && Distributed.rmprocs(Distributed.workers())
		# Create worker processes
		Distributed.addprocs(nproc - 1; exeflags="--project")

		# Import functions used on all worker processes
		Distributed.@everywhere using OPFLearn
		
		net_file = "pglib_opf_case5_pjm.m"
		K = 100
		results = dist_create_samples(net_file, K, net_path="data", 
									  save_certs=true, stat_track=1, save_infeasible=true)
		@test haskey(results, "inputs")
		@test haskey(results, "outputs")
		@test haskey(results, "duals")
		@test haskey(results, "infeasible_inputs")
		@test haskey(results, "polytope")
		@test haskey(results, "stats")
    end
	
end
