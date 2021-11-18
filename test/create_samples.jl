@testset "test dataset sample termination" begin
    @testset "5-bus case file, number of samples" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data")
        @test size(results["inputs"]["pd"],1) == K
		@test size(results["inputs"]["pd"],2) == 3
		@test size(results["outputs"]["p_gen"],1) == K
		@test size(results["outputs"]["p_gen"],2) == 5
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 5
    end

    @testset "30-bus case file, number of samples" begin
		net_file = "pglib_opf_case30_ieee.m"
		K = 10
		results = create_samples(net_file, K, net_path="data")
        @test size(results["inputs"]["pd"],1) == K
		@test size(results["inputs"]["pd"],2) == 21
		@test size(results["outputs"]["p_gen"],1) == K
		@test size(results["outputs"]["p_gen"],2) == 6
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 30
    end
end


@testset "test dataset sample variable specification" begin
    @testset "5-bus case file, default variables" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data")
        @test length(results["inputs"]) == length(OPFLearn.DEFAULT_INPUTS)
		@test length(results["outputs"]) == length(OPFLearn.DEFAULT_OUTPUTS)
		@test length(results["duals"]) == length(OPFLearn.DEFAULT_DUALS) + 3  # + k, uas, and variances
    end

    @testset "5-bus case file, specified variables" begin
		input_vars = ["pd", "qd"]
		output_vars = ["p_gen", "vm_gen"]
		dual_vars = ["v_min", "qg_min", "pto_max"]
		
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", input_vars=input_vars, 
							     output_vars=output_vars, dual_vars=dual_vars)
        @test length(results["inputs"]) == length(input_vars)
		@test length(results["outputs"]) == length(output_vars)
		@test length(results["duals"]) == length(dual_vars) + 3  # Duals includes k, uas, and variances
		@test all([x in keys(results["inputs"]) for x in input_vars])
		@test all([x in keys(results["outputs"]) for x in output_vars])
		@test all([x in keys(results["duals"]) for x in dual_vars])
    end
	
    @testset "14-bus case file, specified variables" begin
		input_vars = ["pd"]
		output_vars = ["q_gen"]
		dual_vars = ["v_min", "qg_min", "pto_max"]
		
		net_file = "pglib_opf_case14_ieee.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", input_vars=input_vars, 
								 output_vars=output_vars, dual_vars=dual_vars)
        @test length(results["inputs"]) == length(input_vars)
		@test length(results["outputs"]) == length(output_vars)
		@test length(results["duals"]) == length(dual_vars) + 3  # Duals includes k, uas, and variances
		@test all([x in keys(results["inputs"]) for x in input_vars])
		@test all([x in keys(results["outputs"]) for x in output_vars])
		@test all([x in keys(results["duals"]) for x in dual_vars])
    end
	
	@testset "14-bus case file, empty duals" begin
		input_vars = ["pd", "qd"]
		output_vars = ["p_gen", "vm_gen"]
		dual_vars = []
		
		net_file = "pglib_opf_case14_ieee.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", input_vars=input_vars, 
							     output_vars=output_vars, dual_vars=dual_vars)
        @test length(results["inputs"]) == length(input_vars)
		@test length(results["outputs"]) == length(output_vars)
		@test length(results["duals"]) == length(dual_vars) + 3  # Duals includes k, uas, and variances
		@test all([x in keys(results["inputs"]) for x in input_vars])
		@test all([x in keys(results["outputs"]) for x in output_vars])
		@test all([x in keys(results["duals"]) for x in dual_vars])
    end
end


@testset "test additional dataset results" begin
    @testset "save polytope" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", save_certs=true)
        @test size(results["inputs"]["pd"],1) == K
		@test size(results["inputs"]["pd"],2) == 3
		@test size(results["outputs"]["p_gen"],1) == K
		@test size(results["outputs"]["p_gen"],2) == 5
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 5
		@test haskey(results, "polytope")
	end
	
    @testset "save stats" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", stat_track=1)
        @test size(results["inputs"]["pd"],1) == K
		@test size(results["inputs"]["pd"],2) == 3
		@test size(results["outputs"]["p_gen"],1) == K
		@test size(results["outputs"]["p_gen"],2) == 5
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 5
		@test haskey(results, "stats")
	end
	
    @testset "save infeasible" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", save_infeasible=true)
        @test size(results["inputs"]["pd"],1) == K
		@test size(results["inputs"]["pd"],2) == 3
		@test size(results["outputs"]["p_gen"],1) == K
		@test size(results["outputs"]["p_gen"],2) == 5
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 5
		@test haskey(results, "infeasible_inputs")
	end
	
    @testset "save found max loads" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", save_max_load=true)
        @test size(results["inputs"]["pd"],1) == K
		@test size(results["inputs"]["pd"],2) == 3
		@test size(results["outputs"]["p_gen"],1) == K
		@test size(results["outputs"]["p_gen"],2) == 5
		@test size(results["duals"]["v_max"],1) == K
		@test size(results["duals"]["v_max"],2) == 5
		@test haskey(results, "load_constraints")
	end
	
	@testset "all save options" begin
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path="data", 
							     save_certs=true, stat_track=1, save_infeasible=true)
		@test haskey(results, "inputs")
		@test haskey(results, "outputs")
		@test haskey(results, "duals")
		@test haskey(results, "infeasible_inputs")
		@test haskey(results, "polytope")
		@test haskey(results, "stats")
	end
end
